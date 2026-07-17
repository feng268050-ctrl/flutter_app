import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/board_helper.dart';
import 'package:lws_hmi/platform/display/display_orientation.dart';

/// Linux orientation: `change-orientation` then optional `systemctl restart hmi`.
class LinuxFlutterPiOrientation implements DisplayOrientationController {
  LinuxFlutterPiOrientation({
    this.preferencePath = DisplayOrientationMapping.preferencePath,
    this.changeOrientationCommand = const <String>['change-orientation'],
    this.restartCommand = const <String>['systemctl', 'restart', 'hmi'],
    BoardHelperRunner? runHelper,
  }) : runHelper = runHelper ?? defaultBoardHelperRunner;

  final String preferencePath;
  final List<String> changeOrientationCommand;
  final List<String> restartCommand;
  final BoardHelperRunner runHelper;

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
    debugPrint(
      'orientation: persisted $token → -o '
      '${DisplayOrientationMapping.toFlutterPiFlag(mode)}',
    );

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
