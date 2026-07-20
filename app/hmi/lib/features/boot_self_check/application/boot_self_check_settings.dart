import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Persisted “Show Startup Self-Check” preference (lws-ui `BootSelfCheckSettings`).
///
/// File: `/var/lib/hmi/boot-self-check` — `1` / `0` (default **enabled** when absent).
final class BootSelfCheckSettings {
  BootSelfCheckSettings({
    String? preferencePath,
    bool? enabledOverrideForTest,
  })  : preferencePath = preferencePath ?? '${OsPaths.varHmi}/boot-self-check',
        _enabledOverrideForTest = enabledOverrideForTest;

  final String preferencePath;
  final bool? _enabledOverrideForTest;

  bool _enabled = true;
  bool _warmed = false;

  bool get isEnabled => _enabledOverrideForTest ?? _enabled;

  /// Synchronous warm-read for bootstrap.
  bool warmRead() {
    if (_enabledOverrideForTest != null) {
      _enabled = _enabledOverrideForTest;
      _warmed = true;
      return _enabled;
    }
    if (_warmed) {
      return _enabled;
    }
    try {
      final f = File(preferencePath);
      if (f.existsSync()) {
        final raw = f.readAsStringSync().trim();
        _enabled = _parseEnabled(raw);
      } else {
        _enabled = true;
      }
    } catch (e) {
      debugPrint('boot-self-check: warmRead failed: $e');
      _enabled = true;
    }
    _warmed = true;
    return _enabled;
  }

  Future<bool> read() async {
    if (_enabledOverrideForTest != null) {
      _enabled = _enabledOverrideForTest;
      _warmed = true;
      return _enabled;
    }
    if (_warmed) {
      return _enabled;
    }
    try {
      final f = File(preferencePath);
      if (await f.exists()) {
        final raw = (await f.readAsString()).trim();
        _enabled = _parseEnabled(raw);
      } else {
        _enabled = true;
      }
    } catch (e) {
      debugPrint('boot-self-check: read failed: $e');
      _enabled = true;
    }
    _warmed = true;
    return _enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabledOverrideForTest != null) {
      return;
    }
    _enabled = enabled;
    _warmed = true;
    try {
      final f = File(preferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString(enabled ? '1\n' : '0\n');
    } catch (e) {
      debugPrint('boot-self-check: write failed: $e');
    }
  }

  static bool _parseEnabled(String raw) {
    if (raw == '0' || raw.toLowerCase() == 'false' || raw.toLowerCase() == 'off') {
      return false;
    }
    if (raw == '1' || raw.toLowerCase() == 'true' || raw.toLowerCase() == 'on') {
      return true;
    }
    // Empty / unknown → default enabled.
    return true;
  }
}
