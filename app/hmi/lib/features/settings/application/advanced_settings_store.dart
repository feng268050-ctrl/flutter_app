import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// App-owned Advanced Settings (`/var/lib/hmi/advanced-settings.json`).
///
/// AI + dangerous-operation booleans only (not Misc JSON, not Modbus).
final class AdvancedSettingsStore extends ChangeNotifier {
  AdvancedSettingsStore({String? preferencePath})
      : preferencePath =
            preferencePath ?? '${OsPaths.varHmi}/advanced-settings.json';

  static const keyLensContaminationDetectionEnabled =
      'lensContaminationDetectionEnabled';
  static const keyZeroPointOffsetDetectionEnabled =
      'zeroPointOffsetDetectionEnabled';
  static const keyKeepLaserOnWhileAlarmed = 'keepLaserOnWhileAlarmed';
  static const keyAllowWorkAfterCameraAlarm = 'allowWorkAfterCameraAlarm';
  static const keyAllowWorkAfterGasAlarm = 'allowWorkAfterGasAlarm';
  static const keyAllowWorkAfterLensContamination =
      'allowWorkAfterLensContamination';
  static const keyAllowWorkAfterFeederAlarm = 'allowWorkAfterFeederAlarm';

  static const defaultLensContaminationDetectionEnabled = true;
  static const defaultZeroPointOffsetDetectionEnabled = true;
  static const defaultKeepLaserOnWhileAlarmed = false;
  static const defaultAllowWorkAfterCameraAlarm = false;
  static const defaultAllowWorkAfterGasAlarm = false;
  static const defaultAllowWorkAfterLensContamination = false;
  static const defaultAllowWorkAfterFeederAlarm = false;

  final String preferencePath;

  bool _lensContaminationDetectionEnabled =
      defaultLensContaminationDetectionEnabled;
  bool _zeroPointOffsetDetectionEnabled =
      defaultZeroPointOffsetDetectionEnabled;
  bool _keepLaserOnWhileAlarmed = defaultKeepLaserOnWhileAlarmed;
  bool _allowWorkAfterCameraAlarm = defaultAllowWorkAfterCameraAlarm;
  bool _allowWorkAfterGasAlarm = defaultAllowWorkAfterGasAlarm;
  bool _allowWorkAfterLensContamination =
      defaultAllowWorkAfterLensContamination;
  bool _allowWorkAfterFeederAlarm = defaultAllowWorkAfterFeederAlarm;
  bool _warmed = false;

  bool get lensContaminationDetectionEnabled =>
      _lensContaminationDetectionEnabled;
  bool get zeroPointOffsetDetectionEnabled => _zeroPointOffsetDetectionEnabled;
  bool get keepLaserOnWhileAlarmed => _keepLaserOnWhileAlarmed;
  bool get allowWorkAfterCameraAlarm => _allowWorkAfterCameraAlarm;
  bool get allowWorkAfterGasAlarm => _allowWorkAfterGasAlarm;
  bool get allowWorkAfterLensContamination =>
      _allowWorkAfterLensContamination;
  bool get allowWorkAfterFeederAlarm => _allowWorkAfterFeederAlarm;

  /// Synchronous warm-read for bootstrap.
  void warmRead() {
    if (_warmed) {
      return;
    }
    try {
      final f = File(preferencePath);
      if (f.existsSync()) {
        _applyJson(f.readAsStringSync());
      } else {
        _applyDefaults();
      }
    } catch (e) {
      debugPrint('advanced-settings: warmRead failed: $e');
      _applyDefaults();
    }
    _warmed = true;
  }

  Future<void> setLensContaminationDetectionEnabled(bool value) async {
    warmRead();
    if (_lensContaminationDetectionEnabled == value) {
      return;
    }
    _lensContaminationDetectionEnabled = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setZeroPointOffsetDetectionEnabled(bool value) async {
    warmRead();
    if (_zeroPointOffsetDetectionEnabled == value) {
      return;
    }
    _zeroPointOffsetDetectionEnabled = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setKeepLaserOnWhileAlarmed(bool value) async {
    warmRead();
    if (_keepLaserOnWhileAlarmed == value) {
      return;
    }
    _keepLaserOnWhileAlarmed = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setAllowWorkAfterCameraAlarm(bool value) async {
    warmRead();
    if (_allowWorkAfterCameraAlarm == value) {
      return;
    }
    _allowWorkAfterCameraAlarm = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setAllowWorkAfterGasAlarm(bool value) async {
    warmRead();
    if (_allowWorkAfterGasAlarm == value) {
      return;
    }
    _allowWorkAfterGasAlarm = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setAllowWorkAfterLensContamination(bool value) async {
    warmRead();
    if (_allowWorkAfterLensContamination == value) {
      return;
    }
    _allowWorkAfterLensContamination = value;
    await _writeUnlocked();
    notifyListeners();
  }

  Future<void> setAllowWorkAfterFeederAlarm(bool value) async {
    warmRead();
    if (_allowWorkAfterFeederAlarm == value) {
      return;
    }
    _allowWorkAfterFeederAlarm = value;
    await _writeUnlocked();
    notifyListeners();
  }

  void _applyDefaults() {
    _lensContaminationDetectionEnabled =
        defaultLensContaminationDetectionEnabled;
    _zeroPointOffsetDetectionEnabled = defaultZeroPointOffsetDetectionEnabled;
    _keepLaserOnWhileAlarmed = defaultKeepLaserOnWhileAlarmed;
    _allowWorkAfterCameraAlarm = defaultAllowWorkAfterCameraAlarm;
    _allowWorkAfterGasAlarm = defaultAllowWorkAfterGasAlarm;
    _allowWorkAfterLensContamination =
        defaultAllowWorkAfterLensContamination;
    _allowWorkAfterFeederAlarm = defaultAllowWorkAfterFeederAlarm;
  }

  void _applyJson(String raw) {
    _applyDefaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
      _lensContaminationDetectionEnabled = _asBool(
        map[keyLensContaminationDetectionEnabled],
        defaultLensContaminationDetectionEnabled,
      );
      _zeroPointOffsetDetectionEnabled = _asBool(
        map[keyZeroPointOffsetDetectionEnabled],
        defaultZeroPointOffsetDetectionEnabled,
      );
      _keepLaserOnWhileAlarmed = _asBool(
        map[keyKeepLaserOnWhileAlarmed],
        defaultKeepLaserOnWhileAlarmed,
      );
      _allowWorkAfterCameraAlarm = _asBool(
        map[keyAllowWorkAfterCameraAlarm],
        defaultAllowWorkAfterCameraAlarm,
      );
      _allowWorkAfterGasAlarm = _asBool(
        map[keyAllowWorkAfterGasAlarm],
        defaultAllowWorkAfterGasAlarm,
      );
      _allowWorkAfterLensContamination = _asBool(
        map[keyAllowWorkAfterLensContamination],
        defaultAllowWorkAfterLensContamination,
      );
      _allowWorkAfterFeederAlarm = _asBool(
        map[keyAllowWorkAfterFeederAlarm],
        defaultAllowWorkAfterFeederAlarm,
      );
    } catch (e) {
      debugPrint('advanced-settings: corrupt JSON, using defaults: $e');
      _applyDefaults();
    }
  }

  Map<String, dynamic> _toJson() => {
        keyLensContaminationDetectionEnabled:
            _lensContaminationDetectionEnabled,
        keyZeroPointOffsetDetectionEnabled: _zeroPointOffsetDetectionEnabled,
        keyKeepLaserOnWhileAlarmed: _keepLaserOnWhileAlarmed,
        keyAllowWorkAfterCameraAlarm: _allowWorkAfterCameraAlarm,
        keyAllowWorkAfterGasAlarm: _allowWorkAfterGasAlarm,
        keyAllowWorkAfterLensContamination: _allowWorkAfterLensContamination,
        keyAllowWorkAfterFeederAlarm: _allowWorkAfterFeederAlarm,
      };

  Future<void> _writeUnlocked() async {
    try {
      final f = File(preferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(_toJson())}\n',
      );
    } catch (e) {
      debugPrint('advanced-settings: write failed: $e');
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
      final v = value.toLowerCase();
      if (v == '0' || v == 'false' || v == 'off') {
        return false;
      }
      if (v == '1' || v == 'true' || v == 'on') {
        return true;
      }
    }
    return fallback;
  }
}
