import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/backlight/backlight_controller.dart';
import 'package:lws_hmi/platform/percent.dart';

/// Linux backlight via `/sys/class/backlight/*/brightness`.
///
/// Prefer the panel node named `backlight` (MainServer / pwm4). Avoid picking
/// broken LED PWM backlight clones (`led-*-pwm`) that share pins with uart7.
class LinuxSysfsBacklight implements BacklightController {
  LinuxSysfsBacklight({
    this.classDir = '/sys/class/backlight',
    this.preferredNames = const <String>['backlight', 'backlight1', 'backlight2'],
  });

  final String classDir;

  /// Preferred sysfs directory basenames (tried in order).
  final List<String> preferredNames;

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
    debugPrint('backlight: using $_brightnessPath max=$_max');
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

  @override
  Future<void> setBrightnessPercent(int percent) async {
    if (!await ensureDevice()) {
      debugPrint('backlight: set skipped (no device)');
      return;
    }
    final value = percentToDevice(percent, _max);
    try {
      await File(_brightnessPath!).writeAsString('$value\n', flush: true);
      debugPrint('backlight: set $value / $_max (${clampPercent(percent)}%)');
    } catch (e) {
      debugPrint('backlight: set failed: $e');
    }
  }

  @override
  Future<void> dispose() async {}
}
