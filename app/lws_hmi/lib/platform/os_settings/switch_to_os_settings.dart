import 'dart:io';

import 'package:flutter/foundation.dart';

/// Why [switchToOsSettings] failed (HMI stays on seat).
enum SwitchToOsSettingsFailure {
  /// `/opt/os_settings/lib/libapp.so` missing.
  missingBundle,

  /// `switch-to-os-settings` / `systemctl start os-settings` failed.
  commandFailed,
}

/// Outcome of requesting the OS Settings Flutter seat.
final class SwitchToOsSettingsResult {
  const SwitchToOsSettingsResult._({
    required this.ok,
    this.failure,
    this.detail,
  });

  final bool ok;
  final SwitchToOsSettingsFailure? failure;

  /// Optional stderr / exception text for logs.
  final String? detail;

  static const SwitchToOsSettingsResult success =
      SwitchToOsSettingsResult._(ok: true);

  factory SwitchToOsSettingsResult.fail(
    SwitchToOsSettingsFailure failure, {
    String? detail,
  }) {
    return SwitchToOsSettingsResult._(
      ok: false,
      failure: failure,
      detail: detail,
    );
  }
}

/// Board path for the OS Settings AOT app library.
const kOsSettingsLibAppPath = '/opt/os_settings/lib/libapp.so';

/// Invokes `switch-to-os-settings` (starts `os-settings.service`; Conflicts
/// stops HMI). On missing bundle or command failure, returns a failure result
/// so the caller can Toast and remain on the HMI seat.
///
/// Prefer the `/usr/bin` helper; fall back to `systemctl start os-settings`
/// when the helper binary is absent (e.g. incomplete overlay).
Future<SwitchToOsSettingsResult> switchToOsSettings({
  bool checkBundle = true,
}) async {
  if (checkBundle) {
    try {
      if (!await File(kOsSettingsLibAppPath).exists()) {
        return SwitchToOsSettingsResult.fail(
          SwitchToOsSettingsFailure.missingBundle,
          detail: kOsSettingsLibAppPath,
        );
      }
    } catch (e, st) {
      debugPrint('os-settings bundle check failed: $e\n$st');
      return SwitchToOsSettingsResult.fail(
        SwitchToOsSettingsFailure.missingBundle,
        detail: e.toString(),
      );
    }
  }

  final helper = await _runSwitchCommand(
    'switch-to-os-settings',
    const <String>[],
  );
  if (helper != null) {
    return helper;
  }

  // Helper missing (ProcessException) — try systemctl directly.
  final viaSystemctl = await _runSwitchCommand(
    'systemctl',
    const <String>['start', 'os-settings'],
  );
  if (viaSystemctl != null) {
    return viaSystemctl;
  }

  return SwitchToOsSettingsResult.fail(
    SwitchToOsSettingsFailure.commandFailed,
    detail: 'switch-to-os-settings and systemctl unavailable',
  );
}

/// Returns a result when the process ran (or a non-missing-binary failure).
/// Returns `null` only when the executable was not found.
Future<SwitchToOsSettingsResult?> _runSwitchCommand(
  String executable,
  List<String> arguments,
) async {
  try {
    final result = await Process.run(executable, arguments);
    if (result.exitCode == 0) {
      return SwitchToOsSettingsResult.success;
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
    return SwitchToOsSettingsResult.fail(
      SwitchToOsSettingsFailure.commandFailed,
      detail: detail,
    );
  } on ProcessException catch (e, st) {
    // Missing binary → try fallback; other spawn errors → fail.
    if (_isExecutableNotFound(e)) {
      debugPrint('$executable not found: $e');
      return null;
    }
    debugPrint('$executable ProcessException: $e\n$st');
    return SwitchToOsSettingsResult.fail(
      SwitchToOsSettingsFailure.commandFailed,
      detail: e.message,
    );
  } catch (e, st) {
    debugPrint('$executable failed: $e\n$st');
    return SwitchToOsSettingsResult.fail(
      SwitchToOsSettingsFailure.commandFailed,
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
