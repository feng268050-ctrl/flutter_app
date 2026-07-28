import 'dart:async';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';
import 'package:lws_hmi/gpio/laser_enable_led_holder.dart';
import 'package:lws_hmi/gpio/rgb_led_decision.dart';

/// Applies one LED mode (default: [GpioLedController.setMode]).
typedef RgbLedModeApplier = Future<void> Function(
  LedColor color,
  IndicatorMode mode,
);

/// Production RGB LED driver (lws-ui `GpioLedHandler` + `RgbLedDecision`).
///
/// Pauses while [beginManualOverride] is active (LED Settings test page).
final class RgbLedPolicyDriver {
  RgbLedPolicyDriver({
    required this.services,
    required this.warnAlarm,
    required this.dangerous,
    LaserEnableLedHolder? ledWorkState,
    RgbLedModeApplier? applyMode,
  })  : _ledWorkState = ledWorkState ?? LaserEnableLedHolder.instance,
        _applyMode = applyMode;

  final AppServices services;
  final WarnAlarmController warnAlarm;
  final DangerousOperationsSettings dangerous;
  final LaserEnableLedHolder _ledWorkState;
  final RgbLedModeApplier? _applyMode;

  static const laserCommAttr = 'alarm.laser_comm';
  static const safetyGroundLockAttr = 'machine.safety_ground_lock';
  static const cncConnectedAttr = 'machine.cnc_connected';

  /// Device bits for red/green interlocks (not Laser Enable / process type —
  /// those come from [LaserEnableLedHolder], matching lws-ui).
  static const watchIds = <String>[
    DeviceControlIds.laserOn,
    DeviceControlIds.keySwitchOn,
    laserCommAttr,
    safetyGroundLockAttr,
    cncConnectedAttr,
  ];

  static const _startAttempts = 3;
  static const _startRetryDelay = Duration(milliseconds: 200);

  StreamSubscription<List<ModbusAttributeChange>>? _sub;
  VoidCallback? _monitorListener;
  VoidCallback? _dangerousListener;
  VoidCallback? _workStateListener;
  bool _started = false;
  bool _manualOverride = false;
  bool _applying = false;
  bool _pendingRefresh = false;

  /// True after a successful status sample (lws-ui non-null DeviceStatus).
  bool _primed = false;
  bool _laserOn = false;
  bool _laserCommAlarm = false;
  bool _keySwitchOn = false;
  bool _safetyGroundLock = false;
  bool _cncConnected = false;

  bool get manualOverride => _manualOverride;

  @visibleForTesting
  bool get primed => _primed;

  @visibleForTesting
  bool get pendingRefresh => _pendingRefresh;

  /// LED Settings page: operator owns GPIO until [endManualOverride].
  void beginManualOverride() {
    _manualOverride = true;
  }

  void endManualOverride() {
    if (!_manualOverride) {
      return;
    }
    _manualOverride = false;
    unawaited(refresh());
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _monitorListener = () => unawaited(refresh());
    warnAlarm.monitor.addListener(_monitorListener!);
    _dangerousListener = () => unawaited(refresh());
    dangerous.addListener(_dangerousListener!);
    _workStateListener = () => unawaited(refresh());
    _ledWorkState.addListener(_workStateListener!);

    Object? lastError;
    for (var attempt = 1; attempt <= _startAttempts; attempt++) {
      try {
        await services.ensureModbusLive();
        await services.leds.ensureWatching();
        // Boot may leave GPIO HIGH; force Off before policy owns the lines.
        await services.leds.resetAllOff();
        if (_sub == null) {
          final stream = await services.modbus.watchAttributes(ids: watchIds);
          _sub = stream.listen(_onChanges);
        }
        await _prime();
        await refresh();
        return;
      } catch (e) {
        lastError = e;
        debugPrint('rgb-led-policy: start attempt $attempt failed: $e');
        if (attempt < _startAttempts) {
          await Future<void>.delayed(_startRetryDelay);
        }
      }
    }
    debugPrint('rgb-led-policy: start gave up after $_startAttempts: $lastError');
  }

  Future<void> stop() async {
    _started = false;
    _pendingRefresh = false;
    await _sub?.cancel();
    _sub = null;
    if (_monitorListener != null) {
      warnAlarm.monitor.removeListener(_monitorListener!);
      _monitorListener = null;
    }
    if (_dangerousListener != null) {
      dangerous.removeListener(_dangerousListener!);
      _dangerousListener = null;
    }
    if (_workStateListener != null) {
      _ledWorkState.removeListener(_workStateListener!);
      _workStateListener = null;
    }
  }

  Future<void> dispose() => stop();

  Future<void> _prime() async {
    try {
      final status = await services.modbus.readGroup('status');
      _applyMap(status);
      _primed = true;
    } catch (e) {
      debugPrint('rgb-led-policy: prime failed: $e');
      // Keep _primed false → red/green off until a real sample arrives.
    }
  }

  void _onChanges(List<ModbusAttributeChange> changes) {
    var changed = false;
    for (final c in changes) {
      if (_applyValue(c.id, c.value)) {
        changed = true;
      }
    }
    if (changed) {
      _primed = true;
      unawaited(refresh());
    }
  }

  void _applyMap(Map<String, Object?> map) {
    for (final e in map.entries) {
      _applyValue(e.key, e.value);
    }
  }

  bool _applyValue(String id, Object? value) {
    final on = value == true || value == 1;
    switch (id) {
      case DeviceControlIds.laserOn:
        if (_laserOn == on) return false;
        _laserOn = on;
        return true;
      case DeviceControlIds.keySwitchOn:
        if (_keySwitchOn == on) return false;
        _keySwitchOn = on;
        return true;
      case laserCommAttr:
        if (_laserCommAlarm == on) return false;
        _laserCommAlarm = on;
        return true;
      case safetyGroundLockAttr:
        if (_safetyGroundLock == on) return false;
        _safetyGroundLock = on;
        return true;
      case cncConnectedAttr:
        if (_cncConnected == on) return false;
        _cncConnected = on;
        return true;
      default:
        return false;
    }
  }

  Set<String> get _activeCodes => {
        for (final e in warnAlarm.coordinator.episodes.values)
          if (e.faultActive) e.code,
      };

  Future<void> refresh() async {
    if (!_started || _manualOverride) {
      return;
    }
    if (_applying) {
      _pendingRefresh = true;
      return;
    }
    _applying = true;
    try {
      do {
        _pendingRefresh = false;
        await _applyDesiredModes();
      } while (_pendingRefresh && !_manualOverride && _started);
    } finally {
      _applying = false;
    }
  }

  Future<void> _applyDesiredModes() async {
    try {
      final snap = dangerous.policySnapshot;
      final active = _activeCodes;
      final red = RgbLedDecision.redMode(
        primed: _primed,
        laserOn: _laserOn,
        laserCommAlarm: _laserCommAlarm,
      );
      final yellow = RgbLedDecision.yellowMode(
        hasWarnSeverityAlarm: RgbLedDecision.hasAnyActiveWarnSeverity(
          activeCodes: active,
          snapshot: snap,
        ),
      );
      final green = RgbLedDecision.greenMode(
        primed: _primed,
        laserOn: _laserOn,
        keySwitchOn: _keySwitchOn,
        readyIndicatorBlocked: RgbLedDecision.readyIndicatorBlockedFromActive(
          activeCodes: active,
          snapshot: snap,
        ),
        laserEnableActive: _ledWorkState.laserEnableActive,
        safetyGroundLockLocked: _safetyGroundLock,
        cncMode: _ledWorkState.isCncCut,
        cncConnected: _cncConnected,
      );
      final apply = _applyMode ?? services.leds.setMode;
      await apply(LedColor.red, red);
      await apply(LedColor.yellow, yellow);
      await apply(LedColor.green, green);
    } catch (e) {
      debugPrint('rgb-led-policy: refresh failed: $e');
    }
  }

  /// Test helper: seed laser / ready inputs without Modbus.
  @visibleForTesting
  void debugSetInputs({
    bool? primed,
    bool? laserOn,
    bool? laserCommAlarm,
    bool? keySwitchOn,
    bool? safetyGroundLock,
    bool? cncConnected,
  }) {
    if (primed != null) _primed = primed;
    if (laserOn != null) _laserOn = laserOn;
    if (laserCommAlarm != null) _laserCommAlarm = laserCommAlarm;
    if (keySwitchOn != null) _keySwitchOn = keySwitchOn;
    if (safetyGroundLock != null) _safetyGroundLock = safetyGroundLock;
    if (cncConnected != null) _cncConnected = cncConnected;
  }

  /// Test helper: mark started without Modbus/GPIO (listeners optional).
  @visibleForTesting
  void debugMarkStarted() {
    _started = true;
  }
}
