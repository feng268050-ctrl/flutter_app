import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Board path for the HMI AOT app library.
const kHmiLibAppPath = '/opt/hmi/lib/libapp.so';

enum SwitchToHmiFailure {
  missingBundle,
  commandFailed,
}

final class SwitchToHmiResult {
  const SwitchToHmiResult._({
    required this.ok,
    this.failure,
    this.detail,
  });

  final bool ok;
  final SwitchToHmiFailure? failure;
  final String? detail;

  static const SwitchToHmiResult success = SwitchToHmiResult._(ok: true);

  factory SwitchToHmiResult.fail(
    SwitchToHmiFailure failure, {
    String? detail,
  }) {
    return SwitchToHmiResult._(
      ok: false,
      failure: failure,
      detail: detail,
    );
  }
}

/// Invokes `switch-to-hmi` (starts `hmi.service`; Conflicts stops OS Settings).
Future<SwitchToHmiResult> switchToHmi({bool checkBundle = true}) async {
  if (checkBundle && Platform.isLinux) {
    try {
      if (!await File(kHmiLibAppPath).exists()) {
        return SwitchToHmiResult.fail(
          SwitchToHmiFailure.missingBundle,
          detail: kHmiLibAppPath,
        );
      }
    } catch (e, st) {
      debugPrint('hmi bundle check failed: $e\n$st');
      return SwitchToHmiResult.fail(
        SwitchToHmiFailure.missingBundle,
        detail: e.toString(),
      );
    }
  }

  final helper = await _runSwitchCommand('switch-to-hmi', const <String>[]);
  if (helper != null) {
    return helper;
  }

  final viaSystemctl = await _runSwitchCommand(
    'systemctl',
    const <String>['start', 'hmi'],
  );
  if (viaSystemctl != null) {
    return viaSystemctl;
  }

  return SwitchToHmiResult.fail(
    SwitchToHmiFailure.commandFailed,
    detail: 'switch-to-hmi and systemctl unavailable',
  );
}

Future<SwitchToHmiResult?> _runSwitchCommand(
  String executable,
  List<String> arguments,
) async {
  try {
    final result = await Process.run(executable, arguments);
    if (result.exitCode == 0) {
      return SwitchToHmiResult.success;
    }
    final stderr = (result.stderr is String)
        ? (result.stderr as String).trim()
        : result.stderr.toString().trim();
    final stdout = (result.stdout is String)
        ? (result.stdout as String).trim()
        : result.stdout.toString().trim();
    final detail = stderr.isNotEmpty
        ? stderr
        : (stdout.isNotEmpty ? stdout : 'exit ${result.exitCode}');
    debugPrint('$executable failed: $detail');
    return SwitchToHmiResult.fail(
      SwitchToHmiFailure.commandFailed,
      detail: detail,
    );
  } on ProcessException catch (e, st) {
    if (_isExecutableNotFound(e)) {
      debugPrint('$executable not found: $e');
      return null;
    }
    debugPrint('$executable ProcessException: $e\n$st');
    return SwitchToHmiResult.fail(
      SwitchToHmiFailure.commandFailed,
      detail: e.message,
    );
  } catch (e, st) {
    debugPrint('$executable failed: $e\n$st');
    return SwitchToHmiResult.fail(
      SwitchToHmiFailure.commandFailed,
      detail: e.toString(),
    );
  }
}

bool _isExecutableNotFound(ProcessException e) {
  final msg = e.message.toLowerCase();
  return msg.contains('no such file') ||
      msg.contains('not found') ||
      e.errorCode == 2;
}

void showSwitchToHmiFailureSnackBar(BuildContext context, SwitchToHmiResult r) {
  if (r.ok) return;
  final msg = switch (r.failure) {
    SwitchToHmiFailure.missingBundle => 'HMI app not installed',
    SwitchToHmiFailure.commandFailed =>
      r.detail ?? 'Failed to switch to HMI',
    null => 'Failed to switch to HMI',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> exitToHmi(BuildContext context) async {
  final result = await switchToHmi();
  if (!context.mounted) return;
  if (!result.ok) {
    showSwitchToHmiFailureSnackBar(context, result);
  }
}
