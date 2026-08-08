import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Unified Common Settings → Misc preferences (`/var/lib/hmi/misc-settings.json`).
final class MiscSettingsStore extends ChangeNotifier {
  MiscSettingsStore({
    String? preferencePath,
    String? legacyBootSelfCheckPath,
    String? legacyAutoCheckOtaPath,
  })  : preferencePath =
            preferencePath ?? '${OsPaths.varHmi}/misc-settings.json',
        legacyBootSelfCheckPath =
            legacyBootSelfCheckPath ?? '${OsPaths.varHmi}/boot-self-check',
        legacyAutoCheckOtaPath = legacyAutoCheckOtaPath ??
            '${OsPaths.varHmi}/auto-check-ota.json';

  static const keyShowStartupSelfCheck = 'showStartupSelfCheck';
  static const keyShowSystemStatusOverlay = 'showSystemStatusOverlay';
  static const keyShowGroundLockAlarm = 'showGroundLockAlarm';
  static const keyAutoCheckOtaUpdate = 'autoCheckOtaUpdate';

  /// Obsolete per-channel keys (migrated into [keyAutoCheckOtaUpdate]).
  static const _legacyKeyAutoCheckControlBoardUpdate =
      'autoCheckControlBoardUpdate';
  static const _legacyKeyAutoCheckCameraProgramUpdate =
      'autoCheckCameraProgramUpdate';

  static const defaultShowStartupSelfCheck = true;
  static const defaultShowSystemStatusOverlay = false;
  static const defaultShowGroundLockAlarm = false;
  static const defaultAutoCheckOtaUpdate = false;

  final String preferencePath;
  final String legacyBootSelfCheckPath;
  final String legacyAutoCheckOtaPath;

  bool _showStartupSelfCheck = defaultShowStartupSelfCheck;
  bool _showSystemStatusOverlay = defaultShowSystemStatusOverlay;
  bool _showGroundLockAlarm = defaultShowGroundLockAlarm;
  bool _autoCheckOtaUpdate = defaultAutoCheckOtaUpdate;
  bool _warmed = false;

  bool get showStartupSelfCheck => _showStartupSelfCheck;
  bool get showSystemStatusOverlay => _showSystemStatusOverlay;
  bool get showGroundLockAlarm => _showGroundLockAlarm;

  /// Master switch: Home tips + Settings upgrade-page auto-check for system OTA,
  /// control-board, and camera program firmware.
  bool get autoCheckOtaUpdate => _autoCheckOtaUpdate;

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
        var migrated = false;
        if (_importLegacyBootSelfCheckSync()) {
          migrated = true;
        }
        if (_importLegacyAutoCheckOtaSync()) {
          migrated = true;
        }
        if (migrated) {
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
        var migrated = false;
        if (await _importLegacyBootSelfCheck()) {
          migrated = true;
        }
        if (await _importLegacyAutoCheckOta()) {
          migrated = true;
        }
        if (migrated) {
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

  Future<void> setAutoCheckOtaUpdate(bool value) async {
    warmRead();
    if (_autoCheckOtaUpdate == value) {
      return;
    }
    _autoCheckOtaUpdate = value;
    await _writeUnlocked();
    notifyListeners();
  }

  void _applyDefaults() {
    _showStartupSelfCheck = defaultShowStartupSelfCheck;
    _showSystemStatusOverlay = defaultShowSystemStatusOverlay;
    _showGroundLockAlarm = defaultShowGroundLockAlarm;
    _autoCheckOtaUpdate = defaultAutoCheckOtaUpdate;
  }

  /// Returns true when a legacy value was imported (caller should persist).
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
      // LED overlay is emulator-auto now; drop obsolete preference key.
      if (map.containsKey('showGpioLedOverlay')) {
        migrated = true;
      }
      if (map.containsKey(keyShowGroundLockAlarm)) {
        _showGroundLockAlarm =
            _asBool(map[keyShowGroundLockAlarm], defaultShowGroundLockAlarm);
      }
      if (map.containsKey(keyAutoCheckOtaUpdate)) {
        _autoCheckOtaUpdate =
            _asBool(map[keyAutoCheckOtaUpdate], defaultAutoCheckOtaUpdate);
      } else if (_importLegacyAutoCheckOtaSync()) {
        migrated = true;
      }
      // Fold obsolete per-channel auto-check flags into the master switch.
      final hadPerChannel = map.containsKey(_legacyKeyAutoCheckControlBoardUpdate) ||
          map.containsKey(_legacyKeyAutoCheckCameraProgramUpdate);
      if (hadPerChannel) {
        migrated = true;
        final cb = _asBool(
          map[_legacyKeyAutoCheckControlBoardUpdate],
          false,
        );
        final cam = _asBool(
          map[_legacyKeyAutoCheckCameraProgramUpdate],
          false,
        );
        if (cb || cam) {
          _autoCheckOtaUpdate = true;
        }
      }
      // Drop obsolete hideEngineerModeEntryTip if present (session-only now).
      if (map.containsKey('hideEngineerModeEntryTip')) {
        migrated = true;
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

  /// Returns true when a legacy auto-check-ota.json was present and applied.
  bool _importLegacyAutoCheckOtaSync() {
    try {
      final legacy = File(legacyAutoCheckOtaPath);
      if (!legacy.existsSync()) {
        return false;
      }
      final decoded = jsonDecode(legacy.readAsStringSync());
      if (decoded is Map && decoded.containsKey('enabled')) {
        _autoCheckOtaUpdate =
            _asBool(decoded['enabled'], defaultAutoCheckOtaUpdate);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('misc-settings: legacy auto-check-ota import failed: $e');
      return false;
    }
  }

  Future<bool> _importLegacyAutoCheckOta() async {
    try {
      final legacy = File(legacyAutoCheckOtaPath);
      if (!await legacy.exists()) {
        return false;
      }
      final decoded = jsonDecode(await legacy.readAsString());
      if (decoded is Map && decoded.containsKey('enabled')) {
        _autoCheckOtaUpdate =
            _asBool(decoded['enabled'], defaultAutoCheckOtaUpdate);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('misc-settings: legacy auto-check-ota import failed: $e');
      return false;
    }
  }

  Map<String, dynamic> _toJson() => {
        keyShowStartupSelfCheck: _showStartupSelfCheck,
        keyShowSystemStatusOverlay: _showSystemStatusOverlay,
        keyShowGroundLockAlarm: _showGroundLockAlarm,
        keyAutoCheckOtaUpdate: _autoCheckOtaUpdate,
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
      final t = value.trim().toLowerCase();
      if (t == '1' || t == 'true' || t == 'yes' || t == 'on') {
        return true;
      }
      if (t == '0' || t == 'false' || t == 'no' || t == 'off') {
        return false;
      }
    }
    return fallback;
  }

  static bool _parseLegacyEnabled(String raw) {
    final t = raw.trim().toLowerCase();
    if (t == '0' || t == 'false' || t == 'no' || t == 'off') {
      return false;
    }
    if (t == '1' || t == 'true' || t == 'yes' || t == 'on') {
      return true;
    }
    return defaultShowStartupSelfCheck;
  }
}
