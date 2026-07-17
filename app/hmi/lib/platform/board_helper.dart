import 'dart:io';

import 'package:flutter/foundation.dart';

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
