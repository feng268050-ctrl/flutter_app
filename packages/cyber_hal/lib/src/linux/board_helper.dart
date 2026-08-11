import 'dart:io';

import 'package:flutter/foundation.dart';

/// Restarts whichever Flutter seat owns the display (`hmi.service` or
/// `os-settings.service`). Implemented by rootfs
/// `/usr/libexec/hmi/restart-flutter-seat.sh`.
const kRestartFlutterSeatPath = '/usr/libexec/hmi/restart-flutter-seat.sh';

/// argv for [Process.start] / board HAL `restartCommand` defaults.
const kRestartFlutterSeatCommand = <String>[kRestartFlutterSeatPath];

/// Runs a board helper (`change-backlight`, `change-volume`, …); injectable for tests.
typedef BoardHelperRunner = Future<int> Function(
  String executable,
  List<String> arguments,
);

Future<int> defaultBoardHelperRunner(
  String executable,
  List<String> arguments,
) async {
  try {
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      debugPrint(
        'board-helper: $executable ${arguments.join(' ')} '
        'exit=${result.exitCode} stderr=${result.stderr}',
      );
    }
    return result.exitCode;
  } catch (e) {
    debugPrint('board-helper: $executable failed: $e');
    return 127;
  }
}

/// Like [defaultBoardHelperRunner] but feeds [stdin] to the process.
Future<int> defaultBoardHelperRunnerWithStdin(
  String executable,
  List<String> arguments,
  String stdin,
) async {
  try {
    final process = await Process.start(executable, arguments);
    process.stdin.write(stdin);
    await process.stdin.close();
    final code = await process.exitCode;
    if (code != 0) {
      debugPrint('board-helper: $executable exit=$code');
    }
    return code;
  } catch (e) {
    debugPrint('board-helper: $executable failed: $e');
    return 127;
  }
}

/// Default keyboard / display apply restart — active Flutter seat, not HMI-only.
Future<int> defaultFlutterSeatRestartRunner() async {
  return defaultBoardHelperRunner(kRestartFlutterSeatPath, const []);
}

/// Back-compat alias for [defaultFlutterSeatRestartRunner].
Future<int> defaultHmiRestartRunner() => defaultFlutterSeatRestartRunner();
