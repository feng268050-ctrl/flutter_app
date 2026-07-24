import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Unified Common Settings → Misc preferences (`/var/lib/hmi/misc-settings.json`).
final class MiscSettingsStore extends ChangeNotifier {
  MiscSettingsStore({
    String? preferencePath,
    String? legacyBootSelfCheckPath,
  })  : preferencePath =
            preferencePath ?? '${OsPaths.varHmi}/misc-settings.json',
        legacyBootSelfCheckPath =
            legacyBootSelfCheckPath ?? '${OsPaths.varHmi}/boot-self-check';

  static const keyShowStartupSelfCheck = 'showStartupSelfCheck';
  static const keyShowSystemStatusOverlay = 'showSystemStatusOverlay';
  static const keyShowGroundLockAlarm = 'showGroundLockAlarm';
  static const keyHideEngineerModeEntryTip = 'hideEngineerModeEntryTip';

  static const defaultShowStartupSelfCheck = true;
  static const defaultShowSystemStatusOverlay = false;
  static const defaultShowGroundLockAlarm = false;
  static const defaultHideEngineerModeEntryTip = false;

  final String preferencePath;
  final String legacyBootSelfCheckPath;

  bool _showStartupSelfCheck = defaultShowStartupSelfCheck;
  bool _showSystemStatusOverlay = defaultShowSystemStatusOverlay;
  bool _showGroundLockAlarm = defaultShowGroundLockAlarm;
  bool _hideEngineerModeEntryTip = defaultHideEngineerModeEntryTip;
  bool _warmed = false;

  bool get showStartupSelfCheck => _showStartupSelfCheck;
  bool get showSystemStatusOverlay => _showSystemStatusOverlay;
  bool get showGroundLockAlarm => _showGroundLockAlarm;
  bool get hideEngineerModeEntryTip => _hideEngineerModeEntryTip;

  /// Synchronous warm-read for bootstrap.
  void warmRead() {
    if (_warmed) {
      return;
    }
    try {
      final f = File(preferencePath);
      if (f.existsSync()) {
        final migrated = _applyJson(f.readAsStringSync());
        if (migrated) {
          _writeSync();
        }
      } else {
        _applyDefaults();
        // Only persist when migrating a legacy value; otherwise keep defaults
        // in memory until the operator changes a Misc switch.
        if (_importLegacyBootSelfCheckSync()) {
          _writeSync();
        }
      }
    } catch (e) {
      debugPrint('misc-settings: warmRead failed: $e');
      _applyDefaults();
    }
    _warmed = true;
  }

  Future<void> read() async {
    if (_warmed) {
      return;
    }
    try {
      final f = File(preferencePath);
      if (await f.exists()) {
        final migrated = _applyJson(await f.readAsString());
        if (migrated) {
          await _writeUnlocked();
        }
      } else {
        _applyDefaults();
        if (await _importLegacyBootSelfCheck()) {
          await _writeUnlocked();
        }
      }
    } catch (e) {
      debugPrint('misc-settings: read failed: $e');
      _applyDefaults();
    }
    _warmed = true;
  }

  Future<void> setShowStartupSelfCheck(bool value) async {
    warmRead();
    if (_showStartupSelfCheck == value) {
      return;
    }
    _showStartupSelfCheck = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setShowSystemStatusOverlay(bool value) async {
    warmRead();
    if (_showSystemStatusOverlay == value) {
      return;
    }
    _showSystemStatusOverlay = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setShowGroundLockAlarm(bool value) async {
    warmRead();
    if (_showGroundLockAlarm == value) {
      return;
    }
    _showGroundLockAlarm = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setHideEngineerModeEntryTip(bool value) async {
    warmRead();
    if (_hideEngineerModeEntryTip == value) {
      return;
    }
    _hideEngineerModeEntryTip = value;
    await _writeUnlocked();
    notifyListeners();
  }

  void _applyDefaults() {
    _showStartupSelfCheck = defaultShowStartupSelfCheck;
    _showSystemStatusOverlay = defaultShowSystemStatusOverlay;
    _showGroundLockAlarm = defaultShowGroundLockAlarm;
    _hideEngineerModeEntryTip = defaultHideEngineerModeEntryTip;
  }

  /// Returns true when legacy boot-self-check was imported (caller should persist).
  bool _applyJson(String raw) {
    _applyDefaults();
    var migrated = false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return false;
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map.containsKey(keyShowStartupSelfCheck)) {
        _showStartupSelfCheck =
            _asBool(map[keyShowStartupSelfCheck], defaultShowStartupSelfCheck);
      } else if (_importLegacyBootSelfCheckSync()) {
        migrated = true;
      }
      if (map.containsKey(keyShowSystemStatusOverlay)) {
        _showSystemStatusOverlay = _asBool(
          map[keyShowSystemStatusOverlay],
          defaultShowSystemStatusOverlay,
        );
      }
      if (map.containsKey(keyShowGroundLockAlarm)) {
        _showGroundLockAlarm =
            _asBool(map[keyShowGroundLockAlarm], defaultShowGroundLockAlarm);
      }
      if (map.containsKey(keyHideEngineerModeEntryTip)) {
        _hideEngineerModeEntryTip = _asBool(
          map[keyHideEngineerModeEntryTip],
          defaultHideEngineerModeEntryTip,
        );
      }
    } catch (e) {
      debugPrint('misc-settings: corrupt JSON, using defaults: $e');
      _applyDefaults();
      return false;
    }
    return migrated;
  }

  /// Returns true when a legacy file was present and applied.
  bool _importLegacyBootSelfCheckSync() {
    try {
      final legacy = File(legacyBootSelfCheckPath);
      if (!legacy.existsSync()) {
        return false;
      }
      final raw = legacy.readAsStringSync().trim();
      _showStartupSelfCheck = _parseLegacyEnabled(raw);
      return true;
    } catch (e) {
      debugPrint('misc-settings: legacy boot-self-check import failed: $e');
      return false;
    }
  }

  Future<bool> _importLegacyBootSelfCheck() async {
    try {
      final legacy = File(legacyBootSelfCheckPath);
      if (!await legacy.exists()) {
        return false;
      }
      final raw = (await legacy.readAsString()).trim();
      _showStartupSelfCheck = _parseLegacyEnabled(raw);
      return true;
    } catch (e) {
      debugPrint('misc-settings: legacy boot-self-check import failed: $e');
      return false;
    }
  }

  Map<String, dynamic> _toJson() => {
        keyShowStartupSelfCheck: _showStartupSelfCheck,
        keyShowSystemStatusOverlay: _showSystemStatusOverlay,
        keyShowGroundLockAlarm: _showGroundLockAlarm,
        keyHideEngineerModeEntryTip: _hideEngineerModeEntryTip,
      };

  Future<void> _writeUnlocked() async {
    try {
      final f = File(preferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(_toJson())}\n',
      );
    } catch (e) {
      debugPrint('misc-settings: write failed: $e');
    }
  }

  void _writeSync() {
    try {
      final f = File(preferencePath);
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(_toJson())}\n',
      );
    } catch (e) {
      debugPrint('misc-settings: writeSync failed: $e');
    }
  }

  static bool _asBool(Object? value, bool fallback) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return _parseLegacyEnabled(value);
    }
    return fallback;
  }

  static bool _parseLegacyEnabled(String raw) {
    final v = raw.toLowerCase();
    if (v == '0' || v == 'false' || v == 'off') {
      return false;
    }
    if (v == '1' || v == 'true' || v == 'on') {
      return true;
    }
    return defaultShowStartupSelfCheck;
  }
}
