import 'dart:io';

import 'package:cyber_hal/output/display/wallpaper.dart';
import 'package:cyber_hal/src/linux/board_helper.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:flutter/foundation.dart';

/// Linux Wallpaper: presets in rootfs, active copy + `display.conf` key.
final class LinuxWallpaper implements Wallpaper {
  LinuxWallpaper({
    this.preferencePath = OutputPrefs.displayConf,
    this.presetsDirectory = OutputPrefs.wallpaperPresetsDir,
    this.activePathDefault = OutputPrefs.wallpaperActivePath,
    this.applyWallpaperCommand = const <String>['apply-wallpaper'],
    this.restartCommand = kRestartFlutterSeatCommand,
    BoardHelperRunner? runHelper,
  }) : runHelper = runHelper ?? defaultBoardHelperRunner;

  final String preferencePath;
  final String presetsDirectory;
  final String activePathDefault;
  final List<String> applyWallpaperCommand;
  final List<String> restartCommand;
  final BoardHelperRunner runHelper;

  String _activePath = '';
  String _activeId = '';
  bool _warmed = false;
  final ValueNotifier<String> _pathTick = ValueNotifier<String>('');

  @override
  Listenable get listenable => _pathTick;

  @override
  String get activePath => _activePath;

  /// Last selected preset id (from conf `wallpaper_id`), when known.
  @override
  String get activePresetId => _activeId;

  void _commitActive({required String path, required String id}) {
    final changed = path != _activePath || id != _activeId;
    _activePath = path;
    _activeId = id;
    if (changed) {
      _pathTick.value = path;
    }
  }

  @override
  String warmRead() {
    if (_warmed) {
      return _activePath;
    }
    try {
      final map = readKeyValueConfFileSync(preferencePath);
      _commitActive(
        path: _resolvePath((map[OutputPrefs.keyWallpaper] ?? '').trim()),
        id: (map[OutputPrefs.keyWallpaperId] ?? '').trim(),
      );
    } catch (e) {
      debugPrint('wallpaper: warmRead failed: $e');
      _commitActive(path: _resolvePath(''), id: '');
    }
    _warmed = true;
    return _activePath;
  }

  @override
  Future<String> getActivePath() async {
    if (_warmed) {
      return _activePath;
    }
    try {
      final map = await readKeyValueConfFile(preferencePath);
      _commitActive(
        path: _resolvePath((map[OutputPrefs.keyWallpaper] ?? '').trim()),
        id: (map[OutputPrefs.keyWallpaperId] ?? '').trim(),
      );
    } catch (e) {
      debugPrint('wallpaper: read failed: $e');
      _commitActive(path: _resolvePath(''), id: '');
    }
    _warmed = true;
    return _activePath;
  }

  @override
  Future<List<WallpaperPreset>> listPresets() async {
    final dir = Directory(presetsDirectory);
    if (!await dir.exists()) {
      return const <WallpaperPreset>[];
    }
    final out = <WallpaperPreset>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isEmpty
          ? entity.path.split(Platform.pathSeparator).last
          : entity.uri.pathSegments.last;
      final lower = name.toLowerCase();
      if (!(lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp'))) {
        continue;
      }
      final id = name.contains('.')
          ? name.substring(0, name.lastIndexOf('.'))
          : name;
      if (id.isEmpty) continue;
      out.add(
        WallpaperPreset(
          id: id,
          path: entity.path,
          label: _labelForId(id),
        ),
      );
    }
    out.sort((a, b) => a.id.compareTo(b.id));
    return out;
  }

  @override
  Future<void> setPreset(String presetId, {bool apply = true}) async {
    final id = presetId.trim();
    if (id.isEmpty) {
      throw ArgumentError('wallpaper preset id is empty');
    }

    if (applyWallpaperCommand.isNotEmpty) {
      final exe = applyWallpaperCommand.first;
      final args = <String>[
        ...applyWallpaperCommand.sublist(1),
        id,
      ];
      final code = await runHelper(exe, args);
      if (code != 0) {
        debugPrint('wallpaper: apply-wallpaper exit $code');
        // Fall through to in-process copy for host/dev without helper.
        await _installPresetInProcess(id);
      } else {
        try {
          final map = await readKeyValueConfFile(preferencePath);
          _commitActive(
            path: _resolvePath((map[OutputPrefs.keyWallpaper] ?? '').trim()),
            id: (map[OutputPrefs.keyWallpaperId] ?? id).trim(),
          );
        } catch (_) {
          _commitActive(path: _resolvePath(activePathDefault), id: id);
        }
        _warmed = true;
      }
    } else {
      await _installPresetInProcess(id);
    }

    if (!apply || restartCommand.isEmpty) {
      return;
    }
    try {
      debugPrint('wallpaper: applying via ${restartCommand.join(' ')}');
      await Process.start(
        restartCommand.first,
        restartCommand.sublist(1),
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      debugPrint('wallpaper: restart failed: $e');
    }
  }

  Future<void> _installPresetInProcess(String presetId) async {
    final presets = await listPresets();
    WallpaperPreset? match;
    for (final p in presets) {
      if (p.id == presetId) {
        match = p;
        break;
      }
    }
    if (match == null) {
      throw StateError('wallpaper preset not found: $presetId');
    }
    final src = File(match.path);
    if (!await src.exists()) {
      throw StateError('wallpaper preset missing: ${match.path}');
    }
    final dest = File(activePathDefault);
    await dest.parent.create(recursive: true);
    await src.copy(dest.path);
    await upsertKeyValueConfFile(preferencePath, {
      OutputPrefs.keyWallpaper: dest.path,
      OutputPrefs.keyWallpaperId: presetId,
    });
    _commitActive(path: dest.path, id: presetId);
    _warmed = true;
  }

  /// Prefer conf path if the file exists; else default active; else first preset.
  String _resolvePath(String stored) {
    if (stored.isNotEmpty && File(stored).existsSync()) {
      return stored;
    }
    if (File(activePathDefault).existsSync()) {
      return activePathDefault;
    }
    final dir = Directory(presetsDirectory);
    if (dir.existsSync()) {
      final files = dir
          .listSync(followLinks: false)
          .whereType<File>()
          .where((f) {
            final n = f.path.toLowerCase();
            return n.endsWith('.png') ||
                n.endsWith('.jpg') ||
                n.endsWith('.jpeg') ||
                n.endsWith('.webp');
          })
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      if (files.isNotEmpty) {
        return files.first.path;
      }
    }
    return stored;
  }

  static String _labelForId(String id) {
    if (id == 'home_back') {
      return 'Default';
    }
    return id
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Future<void> dispose() async {
    _pathTick.dispose();
  }
}
