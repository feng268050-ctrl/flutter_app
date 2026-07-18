import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cyber_hal/output/backlight.dart';
import 'package:cyber_hal/src/linux/board_helper.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/linux/percent.dart';

/// Linux backlight via `change-backlight` (sysfs + persist).
///
/// Prefer the panel node named `backlight` (MainServer / pwm4) for get().
/// Avoid picking broken LED PWM backlight clones (`led-*-pwm`).
class LinuxSysfsBacklight implements Backlight {
  LinuxSysfsBacklight({
    this.classDir = '/sys/class/backlight',
    this.preferredNames = const <String>['backlight', 'backlight1', 'backlight2'],
    this.preferencePath = '/var/lib/hmi/backlight-brightness',
    this.changeBacklightCommand = const <String>[],
    BoardHelperRunner? runHelper,
  }) : runHelper = runHelper ?? defaultBoardHelperRunner;

  final String classDir;

  /// Preferred sysfs directory basenames (tried in order).
  final List<String> preferredNames;

  /// Persisted brightness percent path (read for apply/get fallback).
  final String preferencePath;

  /// Verb-noun helper that applies sysfs and persists [preferencePath].
  final List<String> changeBacklightCommand;

  final BoardHelperRunner runHelper;

  String? _brightnessPath;
  int _max = 255;

  /// Discovered sysfs brightness path (null until [ensureDevice]).
  String? get brightnessPath => _brightnessPath;

  int get maxBrightness => _max;

  Future<bool> ensureDevice() async {
    if (_brightnessPath != null) {
      return true;
    }

    final root = Directory(classDir);
    if (!await root.exists()) {
      debugPrint('backlight: missing $classDir');
      return false;
    }

    for (final name in preferredNames) {
      if (await _tryAccept(Directory('${root.path}/$name'))) {
        return true;
      }
    }

    await for (final entity in root.list()) {
      if (entity is! Directory) {
        continue;
      }
      final base = entity.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last;
      if (base.startsWith('led-') || base.startsWith('led_')) {
        continue;
      }
      if (await _tryAccept(entity)) {
        return true;
      }
    }

    debugPrint('backlight: no usable device under $classDir');
    return false;
  }

  Future<bool> _tryAccept(Directory deviceDir) async {
    if (!await deviceDir.exists()) {
      return false;
    }
    final brightness = File('${deviceDir.path}/brightness');
    final maxFile = File('${deviceDir.path}/max_brightness');
    if (!await brightness.exists()) {
      return false;
    }
    if (await maxFile.exists()) {
      final raw = (await maxFile.readAsString()).trim();
      _max = int.tryParse(raw) ?? 255;
    } else {
      _max = 255;
    }
    if (_max <= 0) {
      return false;
    }
    _brightnessPath = brightness.path;
    lwsTrace('backlight: using $_brightnessPath max=$_max');
    return true;
  }

  @override
  Future<int> getBrightnessPercent() async {
    if (!await ensureDevice()) {
      return 0;
    }
    try {
      final raw = (await File(_brightnessPath!).readAsString()).trim();
      final value = int.tryParse(raw) ?? 0;
      return deviceToPercent(value, _max);
    } catch (e) {
      debugPrint('backlight: get failed: $e');
      return 0;
    }
  }

  /// Re-apply preference via [changeBacklightCommand].
  Future<void> applyPersistedPreference() async {
    try {
      final f = File(preferencePath);
      if (!await f.exists()) {
        return;
      }
      final raw = (await f.readAsString()).trim();
      final pct = int.tryParse(raw);
      if (pct == null) {
        return;
      }
      await setBrightnessPercent(pct);
    } catch (e) {
      debugPrint('backlight: apply persisted failed: $e');
    }
  }

  @override
  Future<void> setBrightnessPercent(int percent) async {
    final clamped = clampPercent(percent);
    if (changeBacklightCommand.isNotEmpty) {
      final exe = changeBacklightCommand.first;
      final args = <String>[
        ...changeBacklightCommand.sublist(1),
        '$clamped',
      ];
      final code = await runHelper(exe, args);
      if (code != 0) {
        debugPrint('backlight: change-backlight exit $code');
        return;
      }
      lwsTrace('backlight: set via helper $clamped%');
      return;
    }
    // Default: write sysfs + preference (no board helper).
    if (!await ensureDevice()) {
      debugPrint('backlight: set skipped (no device)');
      return;
    }
    final val = (clamped * _max / 100).round().clamp(0, _max);
    await File(_brightnessPath!).writeAsString('$val\n', flush: true);
    final pref = File(preferencePath);
    await pref.parent.create(recursive: true);
    await pref.writeAsString('$clamped\n', flush: true);
    lwsTrace('backlight: set $clamped% → $_brightnessPath ($val/$_max)');
  }

  @override
  Future<void> dispose() async {}
}
