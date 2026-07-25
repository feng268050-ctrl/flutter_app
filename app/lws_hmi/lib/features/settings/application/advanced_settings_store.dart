import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Cached numeric thresholds (lws-ui DefaultValueUtils defaults).
final class AdvancedSettingsThresholdValues {
  const AdvancedSettingsThresholdValues({
    this.zeroPointCorrection = defaultZeroPointCorrection,
    this.properSwingWidth = defaultProperSwingWidth,
    this.laserStartPower = defaultLaserStartPower,
    this.laserEndPower = defaultLaserEndPower,
    this.blowPressureThreshold = defaultBlowPressureThreshold,
    this.motorTempAlarm = defaultMotorTempAlarm,
    this.driverTempAlarm = defaultDriverTempAlarm,
    this.protectiveLensTempAlarm = defaultProtectiveLensTempAlarm,
    this.collimatingLensTempAlarm = defaultCollimatingLensTempAlarm,
    this.tempAlarmRecoveryInterval = defaultTempAlarmRecoveryInterval,
  });

  static const defaultZeroPointCorrection = 0.0;
  static const defaultProperSwingWidth = 0.0;
  static const defaultLaserStartPower = 10.0;
  static const defaultLaserEndPower = 10.0;
  static const defaultBlowPressureThreshold = 0.0;
  static const defaultMotorTempAlarm = 70.0;
  static const defaultDriverTempAlarm = 70.0;
  static const defaultProtectiveLensTempAlarm = 70.0;
  static const defaultCollimatingLensTempAlarm = 65.0;
  static const defaultTempAlarmRecoveryInterval = 5.0;

  final double zeroPointCorrection;
  final double properSwingWidth;
  final double laserStartPower;
  final double laserEndPower;
  final double blowPressureThreshold;
  final double motorTempAlarm;
  final double driverTempAlarm;
  final double protectiveLensTempAlarm;
  final double collimatingLensTempAlarm;
  final double tempAlarmRecoveryInterval;

  AdvancedSettingsThresholdValues copyWith({
    double? zeroPointCorrection,
    double? properSwingWidth,
    double? laserStartPower,
    double? laserEndPower,
    double? blowPressureThreshold,
    double? motorTempAlarm,
    double? driverTempAlarm,
    double? protectiveLensTempAlarm,
    double? collimatingLensTempAlarm,
    double? tempAlarmRecoveryInterval,
  }) {
    return AdvancedSettingsThresholdValues(
      zeroPointCorrection: zeroPointCorrection ?? this.zeroPointCorrection,
      properSwingWidth: properSwingWidth ?? this.properSwingWidth,
      laserStartPower: laserStartPower ?? this.laserStartPower,
      laserEndPower: laserEndPower ?? this.laserEndPower,
      blowPressureThreshold:
          blowPressureThreshold ?? this.blowPressureThreshold,
      motorTempAlarm: motorTempAlarm ?? this.motorTempAlarm,
      driverTempAlarm: driverTempAlarm ?? this.driverTempAlarm,
      protectiveLensTempAlarm:
          protectiveLensTempAlarm ?? this.protectiveLensTempAlarm,
      collimatingLensTempAlarm:
          collimatingLensTempAlarm ?? this.collimatingLensTempAlarm,
      tempAlarmRecoveryInterval:
          tempAlarmRecoveryInterval ?? this.tempAlarmRecoveryInterval,
    );
  }
}

/// App-owned Advanced Settings (`/var/lib/hmi/advanced-settings.json`).
///
/// AI + dangerous booleans + optional numeric threshold cache (not Misc JSON).
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

  static const keyZeroPointCorrection = 'zeroPointCorrection';
  static const keyProperSwingWidth = 'properSwingWidth';
  static const keyLaserStartPower = 'laserStartPower';
  static const keyLaserEndPower = 'laserEndPower';
  static const keyBlowPressureThreshold = 'blowPressureThreshold';
  static const keyMotorTempAlarm = 'motorTemperatureAlarmThreshold';
  static const keyDriverTempAlarm = 'driverTemperatureAlarmThreshold';
  static const keyProtectiveLensTempAlarm =
      'protectiveLensTemperatureAlarmThreshold';
  static const keyCollimatingLensTempAlarm =
      'collimatingLensTemperatureAlarmThreshold';
  static const keyTempAlarmRecoveryInterval =
      'temperatureAlarmRecoveryInterval';

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
  AdvancedSettingsThresholdValues _thresholds =
      const AdvancedSettingsThresholdValues();
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
  AdvancedSettingsThresholdValues get thresholds => _thresholds;

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

  Future<void> setThresholds(AdvancedSettingsThresholdValues value) async {
    warmRead();
    _thresholds = value;
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
    _thresholds = const AdvancedSettingsThresholdValues();
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
      _thresholds = AdvancedSettingsThresholdValues(
        zeroPointCorrection: _asDouble(
          map[keyZeroPointCorrection],
          AdvancedSettingsThresholdValues.defaultZeroPointCorrection,
        ),
        properSwingWidth: _asDouble(
          map[keyProperSwingWidth],
          AdvancedSettingsThresholdValues.defaultProperSwingWidth,
        ),
        laserStartPower: _asDouble(
          map[keyLaserStartPower],
          AdvancedSettingsThresholdValues.defaultLaserStartPower,
        ),
        laserEndPower: _asDouble(
          map[keyLaserEndPower],
          AdvancedSettingsThresholdValues.defaultLaserEndPower,
        ),
        blowPressureThreshold: _asDouble(
          map[keyBlowPressureThreshold],
          AdvancedSettingsThresholdValues.defaultBlowPressureThreshold,
        ),
        motorTempAlarm: _asDouble(
          map[keyMotorTempAlarm],
          AdvancedSettingsThresholdValues.defaultMotorTempAlarm,
        ),
        driverTempAlarm: _asDouble(
          map[keyDriverTempAlarm],
          AdvancedSettingsThresholdValues.defaultDriverTempAlarm,
        ),
        protectiveLensTempAlarm: _asDouble(
          map[keyProtectiveLensTempAlarm],
          AdvancedSettingsThresholdValues.defaultProtectiveLensTempAlarm,
        ),
        collimatingLensTempAlarm: _asDouble(
          map[keyCollimatingLensTempAlarm],
          AdvancedSettingsThresholdValues.defaultCollimatingLensTempAlarm,
        ),
        tempAlarmRecoveryInterval: _asDouble(
          map[keyTempAlarmRecoveryInterval],
          AdvancedSettingsThresholdValues.defaultTempAlarmRecoveryInterval,
        ),
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
        keyZeroPointCorrection: _thresholds.zeroPointCorrection,
        keyProperSwingWidth: _thresholds.properSwingWidth,
        keyLaserStartPower: _thresholds.laserStartPower,
        keyLaserEndPower: _thresholds.laserEndPower,
        keyBlowPressureThreshold: _thresholds.blowPressureThreshold,
        keyMotorTempAlarm: _thresholds.motorTempAlarm,
        keyDriverTempAlarm: _thresholds.driverTempAlarm,
        keyProtectiveLensTempAlarm: _thresholds.protectiveLensTempAlarm,
        keyCollimatingLensTempAlarm: _thresholds.collimatingLensTempAlarm,
        keyTempAlarmRecoveryInterval: _thresholds.tempAlarmRecoveryInterval,
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

  static double _asDouble(Object? value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }
}
