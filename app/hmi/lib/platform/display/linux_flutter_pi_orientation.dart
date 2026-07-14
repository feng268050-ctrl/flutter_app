import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/display/display_orientation.dart';

/// Linux orientation: persist preference, then `systemctl restart hmi`.
class LinuxFlutterPiOrientation implements DisplayOrientationController {
  LinuxFlutterPiOrientation({
    this.preferencePath = DisplayOrientationMapping.preferencePath,
    this.restartCommand = const <String>['systemctl', 'restart', 'hmi'],
  });

  final String preferencePath;
  final List<String> restartCommand;

  @override
  Future<DisplayOrientationMode> getPreferred() async {
    try {
      final file = File(preferencePath);
      if (!await file.exists()) {
        return DisplayOrientationMode.landscape;
      }
      return DisplayOrientationMapping.fromPreferenceToken(
        await file.readAsString(),
      );
    } catch (e) {
      debugPrint('orientation: get failed: $e');
      return DisplayOrientationMode.landscape;
    }
  }

  @override
  Future<void> setPreferred(DisplayOrientationMode mode) async {
    final token = DisplayOrientationMapping.toPreferenceToken(mode);
    try {
      final file = File(preferencePath);
      await file.parent.create(recursive: true);
      await file.writeAsString('$token\n', flush: true);
      debugPrint(
        'orientation: persisted $token → -o '
        '${DisplayOrientationMapping.toFlutterPiFlag(mode)}',
      );
    } catch (e) {
      debugPrint('orientation: persist failed: $e');
      return;
    }

    if (restartCommand.isEmpty) {
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

  @override
  Future<void> dispose() async {}
}
