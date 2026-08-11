import 'package:cyber_hal/output/display/wallpaper.dart';
import 'package:flutter/foundation.dart';

/// In-memory Wallpaper for host tests / sim.
final class StubWallpaper implements Wallpaper {
  StubWallpaper({
    String initialPath = '',
    List<WallpaperPreset>? presets,
  })  : _activePath = initialPath,
        _presets = presets ??
            const [
              WallpaperPreset(
                id: 'home_back',
                path: '/usr/share/hal/wallpapers/home_back.png',
                label: 'Default',
              ),
            ];

  String _activePath;
  String _activeId = '';
  final List<WallpaperPreset> _presets;
  String? lastSetPresetId;
  int setCount = 0;
  final ValueNotifier<String> _pathTick = ValueNotifier<String>('');

  @override
  Listenable get listenable => _pathTick;

  @override
  String get activePath => _activePath;

  @override
  String get activePresetId =>
      _activeId.isNotEmpty ? _activeId : (_presets.isEmpty ? '' : _presets.first.id);

  @override
  String warmRead() => _activePath.isEmpty && _presets.isNotEmpty
      ? _presets.first.path
      : _activePath;

  @override
  Future<String> getActivePath() async => warmRead();

  @override
  Future<List<WallpaperPreset>> listPresets() async =>
      List<WallpaperPreset>.from(_presets);

  @override
  Future<void> setPreset(String presetId, {bool apply = true}) async {
    setCount++;
    lastSetPresetId = presetId;
    for (final p in _presets) {
      if (p.id == presetId) {
        _activePath = '/var/lib/hal/wallpaper.png';
        _activeId = presetId;
        _pathTick.value = _activePath;
        return;
      }
    }
    throw StateError('wallpaper preset not found: $presetId');
  }

  @override
  Future<void> dispose() async {
    _pathTick.dispose();
  }
}
