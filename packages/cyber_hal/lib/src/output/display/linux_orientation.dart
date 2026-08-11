import 'dart:io';

import 'package:cyber_hal/output/display/orientation.dart';
import 'package:cyber_hal/src/linux/board_helper.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:flutter/foundation.dart';

/// Linux Orientation: warm-read `display.conf`; set via `change-orientation`.
///
/// Stack mapping (flutter-pi `-o` / Weston `transform`) lives in
/// `hmi-launch.sh` — this backend does not branch on [DisplayStack].
final class LinuxOrientation implements Orientation {
  LinuxOrientation({
    this.preferencePath = OutputPrefs.displayConf,
    this.changeOrientationCommand = const <String>['change-orientation'],
    this.restartCommand = kRestartFlutterSeatCommand,
    this.legacyPreferencePaths = const <String>[
      '/var/lib/hal/display-orientation',
      '/var/lib/hmi/display-orientation',
    ],
    BoardHelperRunner? runHelper,
  }) : runHelper = runHelper ?? defaultBoardHelperRunner;

  final String preferencePath;
  final List<String> changeOrientationCommand;
  final List<String> restartCommand;
  final List<String> legacyPreferencePaths;
  final BoardHelperRunner runHelper;

  OrientationMode _mode = OrientationMode.landscape;
  bool _warmed = false;

  @override
  Future<OrientationMode> getPreferred() async {
    await _ensureWarmed();
    return _mode;
  }

  @override
  Future<void> setPreferred(
    OrientationMode mode, {
    bool apply = true,
  }) async {
    final token = mode.wireName;
    if (changeOrientationCommand.isEmpty) {
      debugPrint('orientation: set skipped (no change-orientation command)');
      return;
    }
    final exe = changeOrientationCommand.first;
    final args = <String>[
      ...changeOrientationCommand.sublist(1),
      token,
    ];
    final code = await runHelper(exe, args);
    if (code != 0) {
      debugPrint('orientation: change-orientation exit $code');
      return;
    }
    _mode = mode;
    _warmed = true;
    debugPrint('orientation: persisted $token');

    if (!apply || restartCommand.isEmpty) {
      return;
    }
    try {
      debugPrint('orientation: applying via ${restartCommand.join(' ')}');
      await Process.start(
        restartCommand.first,
        restartCommand.sublist(1),
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      debugPrint('orientation: restart failed: $e');
    }
  }

  Future<void> _ensureWarmed() async {
    if (_warmed) {
      return;
    }
    try {
      final map = await readKeyValueConfFile(preferencePath);
      final raw = map[OutputPrefs.keyOrientation];
      if (raw != null && raw.trim().isNotEmpty) {
        _mode = OrientationMode.parse(raw);
        _warmed = true;
        return;
      }
      await _importLegacy();
    } catch (e) {
      debugPrint('orientation: read failed: $e');
    }
    _warmed = true;
  }

  /// One-shot: fold standalone `display-orientation` into [preferencePath].
  Future<void> _importLegacy() async {
    for (final path in legacyPreferencePaths) {
      try {
        final f = File(path);
        if (!await f.exists()) {
          continue;
        }
        final raw = (await f.readAsString()).trim();
        if (raw.isEmpty) {
          continue;
        }
        final mode = OrientationMode.parse(raw);
        await upsertKeyValueConfFile(preferencePath, {
          OutputPrefs.keyOrientation: mode.wireName,
        });
        try {
          await f.delete();
        } catch (e) {
          debugPrint('orientation: legacy delete $path failed: $e');
        }
        _mode = mode;
        debugPrint(
          'orientation: migrated legacy $path → $preferencePath',
        );
        return;
      } catch (e) {
        debugPrint('orientation: legacy import $path failed: $e');
      }
    }
  }

  @override
  Future<void> dispose() async {}
}
