import 'dart:async';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_preflight.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/statistics/application/work_session_statistics_recorder.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';
import 'package:lws_hmi/gpio/laser_enable_led_holder.dart';

/// Frost Operation-failed / tip triggers from runtime safety edges.
///
/// Tip timing (lws-ui OperationDialogBuilder / EmergencyStopJobHaltPolicy):
/// - E-stop tip ("Device is in E-stop"): on press; auto-dismiss on release
///   (same as warn frost falling → dismiss).
/// - Key switch OFF tip ("Key switch is off"): on switch-off; auto-dismiss
///   when the key returns ON.
/// Warn frost alarms (e.g. H029) stay deferred until reset via the warn-alarm
/// adapter — not this enum.
enum DeviceControlSafetyEvent {
  /// Machine e-stop pressed; tip dialog once per press (immediate).
  emergencyStop,

  /// Key switch turned OFF; tip dialog once per switch-off (immediate).
  keySwitchOff,

  /// Machine e-stop released; dismiss open e-stop tip if still showing.
  emergencyStopCleared,

  /// Key switch returned ON; dismiss open key-off tip if still showing.
  keySwitchRestored,
}

/// Live laser, gas, and manual wire-control writes.
final class DeviceControlController extends ChangeNotifier {
  DeviceControlController(this.services, {this.workSessionStatistics});

  final AppServices services;
  final WorkSessionStatisticsRecorder? workSessionStatistics;

  bool laserEnable = false;
  bool manualGas = false;
  bool autoWireFeed = true;
  bool wireWork = false;
  bool wireRetracting = false;
  bool wireFeedingOn = false;
  bool laserOn = false;
  bool airValveOn = false;
  bool keySwitchOn = false;
  bool emergencyStop = false;
  double gasPressureKpa = 0;
  bool busy = false;
  String? lastError;

  /// Serializes Modbus writes with process apply (lws-ui ModbusSerialGate parity).
  Future<T> _enqueueWrite<T>(Future<T> Function() body) {
    return services.modbus.runCommandQueued(body);
  }

  /// Laser Enable **session** armed (lws-ui `DeviceControlData.isOpenLaser()`).
  ///
  /// Use for End-of-work button, side-ops hide, record-work sync, and wire
  /// interlocks. [laserOn] is emission feedback only and must not keep the
  /// session UI open after a safety disarm.
  bool get laserSessionArmed => laserEnable;

  /// UI hook for Frost Operation-failed dialogs (Quick/Engineer pages).
  void Function(DeviceControlSafetyEvent event)? onSafetyEvent;

  StreamSubscription<List<ModbusAttributeChange>>? _sub;
  bool _started = false;
  bool _haltWriteInFlight = false;
  bool _disposed = false;

  /// While forcing Auto Wire Feed ON (entry / process-tab default), ignore
  /// stale watch OFF so Quick side keys do not flash between snapshot/prime
  /// and the CONTROL_FIELD_1 write.
  bool _holdingAutoWireDefault = false;

  /// Latch: tip already shown for the current e-stop press.
  bool _eStopTipShownThisPress = false;

  /// Suppress Misc key-switch warn frost while Laser Enable preflight surfaces
  /// the same condition as a toast (avoids dialog on hold-to-enable).
  bool _suppressKeySwitchOffSafetyPrompt = false;
  Timer? _suppressKeySwitchOffSafetyPromptTimer;

  bool get suppressKeySwitchOffSafetyPrompt =>
      _suppressKeySwitchOffSafetyPrompt;

  /// Process `0x0068` saved across a manual Feed/Retract so we can restore it.
  int? _savedProcessWireSpeedMmPerS;
  bool _processWireSpeedBoosted = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    try {
      await services.ensureModbusLive();
      if (!await _refreshSnapshot()) {
        // First group-read can fail while the RTU link is still settling; retry
        // so we do not leave laserEnable stuck false while the controller is
        // still armed (UI shows Laser Enable but gun can emit).
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _refreshSnapshot();
      }
      // Snapshot often leaves auto-wire off after a prior page's
      // shutdownForExit. Apply watch prime first (cache may still say off),
      // then force ON — never subscribe after the write or a stale prime can
      // uncheck the UI while CONTROL_FIELD_1 bit4 stays set on the card.
      final stream = await services.modbus.watchAttributes(
        ids: DeviceControlIds.watchIds,
      );
      _sub = stream.listen(applyChanges);
      // Soft entry defaults: never hold [busy] (Quick side keys stay fully
      // opaque; busy is toast-mutex only). Defer writes so concurrent
      // ProcessApply modeSwitch can claim the RTU first.
      await ensureAutoWireFeedDefault(
        defer: const Duration(milliseconds: 200),
      );
      if (_disposed) {
        return;
      }
      // lws-ui advanced-settings sync: fixed default manual feed speed 80 mm/s.
      await ensureManualWireFeedSpeed();
    } catch (e) {
      debugPrint('device-control: modbus watch failed: $e');
      lastError = 'Status watch failed';
      notifyListeners();
    }
  }

  /// Match lws-ui Quick `initData`: always force Auto Wire Feed ON when safe.
  ///
  /// Soft write: does not toggle [busy] (entry sync must not block taps).
  /// [defer] yields before Modbus so ProcessApply can enqueue first on entry.
  Future<void> ensureAutoWireFeedDefault({
    Duration defer = Duration.zero,
  }) async {
    if (emergencyStop) {
      return;
    }
    _holdingAutoWireDefault = true;
    if (!autoWireFeed) {
      autoWireFeed = true;
      notifyListeners();
    }
    try {
      if (defer > Duration.zero) {
        await Future<void>.delayed(defer);
      }
      if (_disposed || emergencyStop) {
        return;
      }
      LaserEnableBlockReason? lastError;
      for (var attempt = 0; attempt < 3; attempt++) {
        if (_disposed || emergencyStop) {
          return;
        }
        lastError = await setAutoWireFeed(true, holdBusy: false);
        if (lastError == null) {
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
      }
      debugPrint(
        'device-control: ensureAutoWireFeedDefault failed '
        'after retries: $lastError',
      );
    } finally {
      _holdingAutoWireDefault = false;
    }
  }

  /// Match lws-ui default `manualWireFeedSpeed` (80 mm/s) on holding 0x0098.
  ///
  /// Best-effort: a transient C001 / UART glitch must not block entering the
  /// work page. The register often already holds 80 from a prior successful
  /// write (verified on-device).
  Future<void> ensureManualWireFeedSpeed() async {
    Future<bool> once() async {
      try {
        return await services.modbus.writeAttribute(
          DeviceControlIds.manualWireFeedSpeed,
          DeviceControlIds.manualWireFeedSpeedMmPerS,
        );
      } catch (e) {
        debugPrint('device-control: manual wire feed speed write error: $e');
        return false;
      }
    }

    if (await once()) {
      return;
    }
    debugPrint('device-control: manual wire feed speed write failed; retrying');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!await once()) {
      debugPrint('device-control: manual wire feed speed write failed');
    }
  }

  Future<bool> _softWriteSpeed(String id, int mmPerS, String label) async {
    try {
      final ok = await services.modbus.writeAttribute(id, mmPerS);
      if (!ok) {
        debugPrint('device-control: $label write soft-failed');
      }
      return ok;
    } catch (e) {
      debugPrint('device-control: $label write error: $e');
      return false;
    }
  }

  /// Best-effort speeds before latching wire_work.
  ///
  /// Writes:
  /// - `0x0098` manual feed = 80 (lws-ui advanced default)
  /// - `0x0099` manual retract = 15 (lws-ui default)
  /// - `0x0068` process wire speed = 80 (some firmwares drive manual Feed from
  ///   the process register; presets are often ~10 mm/s — verified bab69…)
  Future<void> _assertManualWireSpeedsBestEffort() async {
    await _softWriteSpeed(
      DeviceControlIds.manualWireFeedSpeed,
      DeviceControlIds.manualWireFeedSpeedMmPerS,
      'manual feed speed (0x0098)',
    );
    await _softWriteSpeed(
      DeviceControlIds.manualDrawStringSpeed,
      DeviceControlIds.manualDrawStringSpeedMmPerS,
      'manual draw speed (0x0099)',
    );
    try {
      if (!_processWireSpeedBoosted) {
        final raw = await services.modbus.readAttribute(
          DeviceControlIds.processWireFeedingSpeed,
        );
        _savedProcessWireSpeedMmPerS = switch (raw) {
          int i => i,
          num n => n.toInt(),
          _ => null,
        };
        _processWireSpeedBoosted = true;
      }
    } catch (e) {
      debugPrint('device-control: process wire speed read error: $e');
      _processWireSpeedBoosted = true;
    }
    await _softWriteSpeed(
      DeviceControlIds.processWireFeedingSpeed,
      DeviceControlIds.manualWireFeedSpeedMmPerS,
      'process wire speed (0x0068)',
    );
  }

  Future<void> _restoreProcessWireSpeedBestEffort() async {
    if (!_processWireSpeedBoosted) {
      return;
    }
    final saved = _savedProcessWireSpeedMmPerS;
    _processWireSpeedBoosted = false;
    _savedProcessWireSpeedMmPerS = null;
    if (saved == null) {
      return;
    }
    await _softWriteSpeed(
      DeviceControlIds.processWireFeedingSpeed,
      saved,
      'restore process wire speed (0x0068)',
    );
  }

  /// lws-ui `createDeviceControlSwitchData`: one CONTROL_FIELD_1 word.
  ///
  /// Bits: laser=0, gas/auto preserved from local snapshot, wire/dir as args.
  Future<bool> _writePackedWireControl({
    required bool run,
    required bool retract,
  }) async {
    var word = 0;
    if (manualGas) {
      word |= 1 << 1;
    }
    if (run) {
      word |= 1 << 2;
    }
    if (run && retract) {
      word |= 1 << 3;
    }
    if (autoWireFeed) {
      word |= 1 << 4;
    }
    return services.modbus.writeAttribute(
      DeviceControlIds.controlField1,
      word,
    );
  }

  /// Returns `true` when control+status groups were read successfully.
  Future<bool> _refreshSnapshot() async {
    try {
      final control = await services.modbus.readGroup('control');
      final status = await services.modbus.readGroup('status');
      laserEnable = _isOn(control[DeviceControlIds.laserEnable]);
      manualGas = _isOn(control[DeviceControlIds.manualGas]);
      // lws-ui calls bit4 `autoWireFeedEnable`, despite the HAL's legacy
      // `wire_manual_mode` identifier. Keep its on-wire behavior for parity.
      autoWireFeed = _isOn(control[DeviceControlIds.wireManualMode]);
      wireWork = _isOn(control[DeviceControlIds.wireWork]);
      wireRetracting = _isOn(control[DeviceControlIds.wireDirection]);
      laserOn = _isOn(status[DeviceControlIds.laserOn]);
      airValveOn = _isOn(status[DeviceControlIds.airValveOn]);
      wireFeedingOn = _isOn(status[DeviceControlIds.wireFeedingOn]);
      keySwitchOn = _isOn(status[DeviceControlIds.keySwitchOn]);
      emergencyStop = _isOn(status[DeviceControlIds.emergencyStop]);
      try {
        final data = await services.modbus.readGroup('data');
        gasPressureKpa = _asDouble(data[DeviceControlIds.blowPressure]);
      } catch (_) {
        // Pressure is non-critical for enable UI; keep prior value.
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('device-control: snapshot failed: $e');
      return false;
    }
  }

  static bool _isOn(Object? value) => value == true || value == 1;

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  @visibleForTesting
  void applyChanges(List<ModbusAttributeChange> changes) {
    if (changes.isEmpty) {
      return;
    }
    final keyWasOn = keySwitchOn;
    final eStopWas = emergencyStop;
    final laserWasEnabled = laserEnable;
    var changed = false;
    for (final c in changes) {
      final on = c.value == true || c.value == 1;
      switch (c.id) {
        case DeviceControlIds.laserEnable:
          if (laserEnable != on) {
            laserEnable = on;
            changed = true;
          }
        case DeviceControlIds.manualGas:
          if (manualGas != on) {
            manualGas = on;
            changed = true;
          }
        case DeviceControlIds.wireManualMode:
          // Stale OFF from snapshot/watch prime must not uncheck while we are
          // forcing the lws-ui default ON onto CONTROL_FIELD_1.
          if (_holdingAutoWireDefault && !on) {
            break;
          }
          if (autoWireFeed != on) {
            autoWireFeed = on;
            changed = true;
          }
        case DeviceControlIds.wireWork:
          if (wireWork != on) {
            wireWork = on;
            changed = true;
          }
        case DeviceControlIds.wireDirection:
          if (wireRetracting != on) {
            wireRetracting = on;
            changed = true;
          }
        case DeviceControlIds.laserOn:
          if (laserOn != on) {
            debugPrint(
              'device-control: machine.laser_on $laserOn → $on '
              '(enable=$laserEnable)',
            );
            laserOn = on;
            changed = true;
          }
        case DeviceControlIds.airValveOn:
          if (airValveOn != on) {
            airValveOn = on;
            changed = true;
          }
        case DeviceControlIds.wireFeedingOn:
          if (wireFeedingOn != on) {
            wireFeedingOn = on;
            changed = true;
          }
        case DeviceControlIds.keySwitchOn:
          if (keySwitchOn != on) {
            keySwitchOn = on;
            changed = true;
          }
        case DeviceControlIds.emergencyStop:
          if (emergencyStop != on) {
            emergencyStop = on;
            changed = true;
          }
        case DeviceControlIds.blowPressure:
          final next = _asDouble(c.value);
          if (gasPressureKpa != next) {
            gasPressureKpa = next;
            changed = true;
          }
      }
    }
    if (changed) {
      notifyListeners();
    }
    if (laserWasEnabled && !laserEnable) {
      unawaited(workSessionStatistics?.settle() ?? Future<void>.value());
    }
    _handleSafetyEdges(
      keyWasOn: keyWasOn,
      eStopWas: eStopWas,
    );
  }

  void _handleSafetyEdges({
    required bool keyWasOn,
    required bool eStopWas,
  }) {
    final eStopRose = !eStopWas && emergencyStop;
    final eStopFell = eStopWas && !emergencyStop;
    final keyFell = keyWasOn && !keySwitchOn;
    final keyRose = !keyWasOn && keySwitchOn;

    // E-stop press: exit Laser Enable UI + halt jobs immediately; tip once.
    if (eStopFell) {
      _eStopTipShownThisPress = false;
      onSafetyEvent?.call(DeviceControlSafetyEvent.emergencyStopCleared);
    }
    if (emergencyStop) {
      if (eStopRose || _shouldReHaltWhileEstopHeld()) {
        // Apply local halt before the async Modbus write so the Laser Enable
        // button / side-ops leave the armed session even if RTU is slow.
        _applyLocalJobHalt();
        if (eStopRose && !_eStopTipShownThisPress) {
          _eStopTipShownThisPress = true;
          onSafetyEvent?.call(DeviceControlSafetyEvent.emergencyStop);
        }
        unawaited(_performEmergencyStopHalt());
      }
    }

    // Key OFF is a non-alarm safety tip, matching the E-stop interaction.
    // H022 remains separately masked by the warn-alarm adapter while the key
    // switch is OFF, so this does not create an alarm popup/history entry.
    if (keyFell) {
      onSafetyEvent?.call(DeviceControlSafetyEvent.keySwitchOff);
    }
    if (keyRose) {
      _clearSuppressKeySwitchOffSafetyPrompt();
      onSafetyEvent?.call(DeviceControlSafetyEvent.keySwitchRestored);
    }

    // Key OFF also closes an active Laser Enable session immediately.
    if (!keySwitchOn && laserSessionArmed) {
      if (keyFell) {
        _disarmLaserSessionLocally();
        unawaited(forceDisableLaserForSafety());
      } else {
        // Stale control.laser_enable feedback while key is still off — keep UI
        // disarmed without re-spamming Modbus writes.
        _disarmLaserSessionLocally();
      }
    }
  }

  /// Local session close only (lws-ui failRest=false flip of `laserStatus`).
  void _disarmLaserSessionLocally() {
    if (!laserEnable && !wireWork) {
      return;
    }
    laserEnable = false;
    wireWork = false;
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// lws-ui `DeviceControlUtils.applyHaltAllJobFunctions` local sync.
  void _applyLocalJobHalt() {
    laserEnable = false;
    manualGas = false;
    wireWork = false;
    autoWireFeed = false;
    wireRetracting = false;
    // Clear emission feedback so re-halt checks / status LEDs do not fight
    // the local session; UI session itself is [laserEnable] only.
    laserOn = false;
    wireFeedingOn = false;
    airValveOn = false;
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool _shouldReHaltWhileEstopHeld() {
    // Align EmergencyStopJobHaltPolicy.shouldReHalt: any job request or
    // emission / feeder / gas feedback still on while e-stop held.
    if (laserSessionArmed ||
        manualGas ||
        wireWork ||
        autoWireFeed ||
        laserOn ||
        wireFeedingOn ||
        airValveOn) {
      return true;
    }
    return false;
  }

  Future<void> _performEmergencyStopHalt() async {
    if (!_haltWriteInFlight) {
      await haltAllJobFunctions();
    }
  }

  /// lws-ui `DeviceControlUtils.createHaltAllJobFunctionsConfig` write.
  ///
  /// One holding write to CONTROL_FIELD_1 (0x0058) — not five bit RMW round
  /// trips. Under e-stop the card often times out; five serial writes were
  /// starving continuous poll (~seconds) so status bar / Laser Enable lagged.
  Future<void> haltAllJobFunctions() async {
    if (_haltWriteInFlight) {
      return;
    }
    _haltWriteInFlight = true;
    await _enqueueWrite(() async {
      busy = true;
      lastError = null;
      _applyLocalJobHalt();
      try {
        final ok = await services.modbus.exclusiveSession(() async {
          // Android packs all five job switches into one CONTROL_FIELD_1 word.
          return services.modbus.writeAttribute(
            DeviceControlIds.controlField1,
            0,
          );
        });
        if (!ok) {
          lastError = 'Halt write failed';
          debugPrint('device-control: haltAllJobFunctions write returned false');
          // Keep local halt even when the write fails — e-stop hardware already
          // cut outputs; UI must not remain in Laser Enable.
          _applyLocalJobHalt();
        }
      } catch (e) {
        debugPrint('device-control: haltAllJobFunctions failed: $e');
        lastError = '$e';
        _applyLocalJobHalt();
      } finally {
        busy = false;
        _haltWriteInFlight = false;
        // Reconcile job-control bits only — do not re-read status here or a
        // transient group-read failure / empty fake can clear e-stop/key while
        // the halt edge is still being processed.
        await _reconcileControlBitsFromHardware();
        // If RTU still reports enable armed after a failed halt write, keep the
        // local session exited for this e-stop (lws-ui forces local UI off).
        if (emergencyStop && laserEnable) {
          _applyLocalJobHalt();
        }
      }
    });
    _haltWriteInFlight = false;
  }

  /// Close Laser Enable even if another write briefly holds [busy].
  ///
  /// Always leaves the Laser Enable UI disarmed (lws-ui failRest=false on
  /// safety closes). Modbus may still reject writes while the key is off.
  Future<void> forceDisableLaserForSafety() async {
    _disarmLaserSessionLocally();
    await disableLaser(keepUiDisarmed: true);
    _disarmLaserSessionLocally();
  }

  /// Pull holding-register job switches from the controller (Laser Enable UI).
  Future<void> _reconcileControlBitsFromHardware() async {
    try {
      final control = await services.modbus.readGroup('control');
      void applyBit(String id, void Function(bool) set) {
        final value = control[id];
        if (value != null) {
          set(_isOn(value));
        }
      }

      applyBit(DeviceControlIds.laserEnable, (v) => laserEnable = v);
      applyBit(DeviceControlIds.manualGas, (v) => manualGas = v);
      applyBit(DeviceControlIds.wireManualMode, (v) => autoWireFeed = v);
      applyBit(DeviceControlIds.wireWork, (v) => wireWork = v);
      applyBit(DeviceControlIds.wireDirection, (v) => wireRetracting = v);
      // Safety paths own the session UI: never re-arm from a stale holding
      // register while key is off or e-stop is held (lws-ui failRest=false).
      if ((!keySwitchOn || emergencyStop) && laserEnable) {
        laserEnable = false;
        wireWork = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('device-control: control reconcile failed: $e');
      // Keep optimistic local bits; live watch will correct when RTU recovers.
    }
  }

  /// Returns null on success, otherwise a block reason.
  Future<LaserEnableBlockReason?> setManualGas(bool enabled) async {
    return _enqueueWrite(() async {
      busy = true;
      lastError = null;
      notifyListeners();
      try {
      // One CONTROL_FIELD_1 word: mutual exclusion with laser + wire (lws-ui).
      final ok = await _exclusiveField1WithRetry(() async {
        var word = 0;
        if (enabled) {
          // Enabling gas clears laser (mutual exclusion).
          word |= 1 << 1;
        } else if (laserEnable) {
          word |= 1 << 0;
        }
        if (autoWireFeed) {
          word |= 1 << 4;
        }
        return services.modbus.writeAttribute(
          DeviceControlIds.controlField1,
          word,
        );
      });
      if (!ok) {
        lastError = 'Manual Gas Write Failed';
        return LaserEnableBlockReason.writeFailed;
      }
      manualGas = enabled;
      wireWork = false;
      wireRetracting = false;
      if (enabled) {
        laserEnable = false;
      }
      return null;
    } catch (e) {
      lastError = '$e';
      return LaserEnableBlockReason.writeFailed;
    } finally {
      busy = false;
      notifyListeners();
    }
    });
  }

  /// Toggle automatic wire-feed enable, first stopping any manual movement.
  ///
  /// [holdBusy] false for entry/default sync so init writes do not trip the
  /// toast-mutex while ProcessApply shares the RTU.
  Future<LaserEnableBlockReason?> setAutoWireFeed(
    bool enabled, {
    bool holdBusy = true,
  }) async {
    return _enqueueWrite(() async {
      if (holdBusy) {
        busy = true;
        lastError = null;
        notifyListeners();
      }
      try {
        final ok = await _exclusiveField1WithRetry(() async {
          var word = 0;
          if (manualGas) {
            word |= 1 << 1;
          }
          if (enabled) {
            word |= 1 << 4;
          }
          // Clearing wire bits; leave laser alone only when already off — when
          // syncing auto-wire on process switch, laser session should be idle.
          if (laserEnable) {
            word |= 1 << 0;
          }
          return services.modbus.writeAttribute(
            DeviceControlIds.controlField1,
            word,
          );
        });
        if (!ok) {
          lastError = 'Auto wire-feed write failed';
          return LaserEnableBlockReason.writeFailed;
        }
        autoWireFeed = enabled;
        wireWork = false;
        wireRetracting = false;
        return null;
      } catch (e) {
        lastError = '$e';
        return LaserEnableBlockReason.writeFailed;
      } finally {
        if (holdBusy) {
          busy = false;
        }
        if (!_disposed) {
          notifyListeners();
        }
      }
    });
  }

  /// Begin a manual feed (forward) or retract (reverse) movement.
  Future<LaserEnableBlockReason?> startWire({required bool retract}) async {
    return _enqueueWrite(() async {
      // Soft speed writes outside [busy] so a flaky RTU does not block Manual
      // Gas / Laser taps for multiple timeouts.
      await _assertManualWireSpeedsBestEffort();
      busy = true;
      lastError = null;
      notifyListeners();
      try {
        final ok = await _exclusiveField1WithRetry(() async {
          // lws-ui openFeed/openBackFeed: one CONTROL_FIELD_1 word (not bit RMW).
          return _writePackedWireControl(run: true, retract: retract);
        });
        if (!ok) {
          lastError = 'Wire control write failed';
          return LaserEnableBlockReason.writeFailed;
        }
        laserEnable = false;
        wireRetracting = retract;
        wireWork = true;
        return null;
      } catch (e) {
        lastError = '$e';
        return LaserEnableBlockReason.writeFailed;
      } finally {
        busy = false;
        notifyListeners();
      }
    });
  }

  /// Idempotent clear of continuous feed/retract (mode switch / exit prep).
  Future<LaserEnableBlockReason?> clearContinuousWire() => stopWire();

  /// Stop whichever manual wire movement is active.
  Future<LaserEnableBlockReason?> stopWire() async {
    return _enqueueWrite(() async {
      busy = true;
      lastError = null;
      notifyListeners();
      try {
        final ok = await _exclusiveField1WithRetry(() async {
          // lws-ui closeFeedOrBack: wire off, direction feed, laser off.
          return _writePackedWireControl(
            run: false,
            retract: false,
          );
        });
        if (!ok) {
          lastError = 'Wire control write failed';
          return LaserEnableBlockReason.writeFailed;
        }
        wireWork = false;
        wireRetracting = false;
        // Restore process wire speed outside the exclusive write so we release
        // [busy] promptly; soft-fail is fine.
        unawaited(_restoreProcessWireSpeedBestEffort());
        return null;
      } catch (e) {
        lastError = '$e';
        return LaserEnableBlockReason.writeFailed;
      } finally {
        busy = false;
        notifyListeners();
      }
    });
  }

  /// Hold-to-enable path: run preflight then write laser_enable=true.
  LaserEnableBlockReason? preflightLaserEnable({
    WarnAlarmController? warnAlarm,
    LaserAlarmPolicySnapshot? policy,
  }) {
    if (manualGas) {
      return LaserEnableBlockReason.manualGasOn;
    }

    final machineBlock = LaserEnablePreflight.machineStatusBlock(
      emergencyStop: emergencyStop,
      keySwitchOn: keySwitchOn,
    );
    if (machineBlock != null) {
      if (machineBlock == LaserEnableBlockReason.keySwitchOff) {
        _armSuppressKeySwitchOffSafetyPrompt();
      }
      lastError = machineBlock.message;
      notifyListeners();
      return machineBlock;
    }

    final snapshot = policy ??
        const LaserAlarmPolicySnapshot(
          keepLaserOnWhileAlarmed: false,
          allowWorkAfterCameraAlarm: false,
          allowWorkAfterGasAlarm: false,
          allowWorkAfterLensContamination: false,
          allowWorkAfterFeederAlarm: false,
        );
    final active = <String>{
      if (warnAlarm != null)
        for (final e in warnAlarm.coordinator.episodes.values)
          if (e.faultActive) e.code,
    };
    final alarm = LaserEnablePreflight.alarmBlock(
      activeAlarmCodes: active,
      policy: snapshot,
    );
    if (alarm != null) {
      lastError = alarm.message;
      notifyListeners();
      return alarm;
    }
    return null;
  }

  Future<LaserEnableBlockReason?> enableLaser({
    WarnAlarmController? warnAlarm,
    LaserAlarmPolicySnapshot? policy,
  }) async {
    return _enqueueWrite(() async {
      final block = preflightLaserEnable(
        warnAlarm: warnAlarm,
        policy: policy,
      );
      if (block != null) {
        if (block == LaserEnableBlockReason.keySwitchOff) {
          _armSuppressKeySwitchOffSafetyPrompt();
        }
        return block;
      }

      busy = true;
      lastError = null;
      notifyListeners();
      try {
        // One CONTROL_FIELD_1 write: set laser, clear wire_work + direction
        // (same register as disableLaser — avoids two bit timeouts).
        final ok = await _exclusiveField1WithRetry(() async {
          return _writeControlField1RmW(
            // laser | wire_work | wire_direction
            clearMask: 0xD,
            setMask: 0x1, // laser_enable
          );
        });
        if (!ok) {
          lastError = LaserEnableBlockReason.writeFailed.message;
          return LaserEnableBlockReason.writeFailed;
        }
        laserEnable = true;
        wireWork = false;
        wireRetracting = false;
        await workSessionStatistics?.recordLaserEnabled();
        return null;
      } catch (e) {
        lastError = '$e';
        return LaserEnableBlockReason.writeFailed;
      } finally {
        busy = false;
        notifyListeners();
      }
    });
  }

  Future<LaserEnableBlockReason?> disableLaser({
    bool keepUiDisarmed = false,
  }) async {
    return _enqueueWrite(() async {
      busy = true;
      lastError = null;
      notifyListeners();
      try {
        final ok = await _exclusiveField1WithRetry(() async {
          // One RMW of CONTROL_FIELD_1 — clears laser_enable + wire_work together
          // (lws-ui single-register switch write). Avoids two bit timeouts that
          // pause continuous poll under a sticky key/e-stop bus.
          return _writeControlField1ClearingJobBits(
            clearMask: 0x5, // bit0 laser_enable | bit2 wire_work
          );
        });
        if (!ok) {
          lastError = LaserEnableBlockReason.writeFailed.message;
          if (keepUiDisarmed) {
            _disarmLaserSessionLocally();
          }
          return LaserEnableBlockReason.writeFailed;
        }
        _disarmLaserSessionLocally();
        await workSessionStatistics?.settle();
        busy = false;
        if (!keepUiDisarmed) {
          await _reconcileControlBitsFromHardware();
          if (laserEnable) {
            lastError = LaserEnableBlockReason.writeFailed.message;
            return LaserEnableBlockReason.writeFailed;
          }
        }
        return null;
      } catch (e) {
        lastError = '$e';
        if (keepUiDisarmed) {
          _disarmLaserSessionLocally();
        }
        return LaserEnableBlockReason.writeFailed;
      } finally {
        busy = false;
        notifyListeners();
      }
    });
  }

  /// Clear and/or set bits in CONTROL_FIELD_1 with a single holding write.
  ///
  /// Prefer this over multiple bit [writeAttribute]s — each bit RMW can burn a
  /// full RTU timeout and keep [busy] held (Quick Mode "控制忙" toasts).
  Future<bool> _writeControlField1RmW({
    required int clearMask,
    int setMask = 0,
  }) async {
    final raw =
        await services.modbus.readAttribute(DeviceControlIds.controlField1);
    final word = switch (raw) {
      int i => i,
      num n => n.toInt(),
      _ => 0,
    };
    final next = ((word & ~clearMask) | setMask) & 0xFFFF;
    return services.modbus.writeAttribute(
      DeviceControlIds.controlField1,
      next,
    );
  }

  /// Clear selected job bits in CONTROL_FIELD_1 with a single holding write.
  Future<bool> _writeControlField1ClearingJobBits({
    required int clearMask,
  }) =>
      _writeControlField1RmW(clearMask: clearMask);

  /// One CONTROL_FIELD_1 write with short retry (transient RTU gaps).
  Future<bool> _exclusiveField1WithRetry(
    Future<bool> Function() write,
  ) async {
    var ok = await services.modbus.exclusiveSession(write);
    if (ok) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return services.modbus.exclusiveSession(write);
  }

  /// Best-effort Modbus shutdown when leaving Quick/Engineer / disposing /
  /// process teardown.
  ///
  /// Product rule: laser emission is allowed only after an explicit Laser
  /// Enable press. Exit / crash / restart paths must clear all CONTROL_FIELD_1
  /// job bits (laser, manual gas, wire work/dir, auto wire). Retries once on
  /// failure.
  Future<void> shutdownForExit() async {
    await _enqueueWrite(() async {
      busy = true;
      lastError = null;
      if (!_disposed) {
        notifyListeners();
      }
      try {
        Future<bool> writeOff() => _writeControlField1RmW(
              clearMask: DeviceControlIds.controlField1JobBitsMask,
            );
        final ok = await _exclusiveField1WithRetry(writeOff);
        if (!ok) {
          lastError = 'Laser disarm write failed';
          debugPrint('device-control: shutdownForExit write returned false');
        } else {
          await workSessionStatistics?.settle();
        }
      } catch (e) {
        debugPrint('device-control: shutdownForExit failed: $e');
        lastError = '$e';
      } finally {
        laserEnable = false;
        manualGas = false;
        autoWireFeed = false;
        wireWork = false;
        wireRetracting = false;
        busy = false;
        if (!_disposed) {
          notifyListeners();
        }
      }
    });
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      LaserEnableLedHolder.instance.setActive(laserSessionArmed);
    }
    super.notifyListeners();
  }

  void _armSuppressKeySwitchOffSafetyPrompt() {
    _suppressKeySwitchOffSafetyPrompt = true;
    _suppressKeySwitchOffSafetyPromptTimer?.cancel();
    _suppressKeySwitchOffSafetyPromptTimer = Timer(
      const Duration(milliseconds: 800),
      () => _suppressKeySwitchOffSafetyPrompt = false,
    );
  }

  void _clearSuppressKeySwitchOffSafetyPrompt() {
    _suppressKeySwitchOffSafetyPromptTimer?.cancel();
    _suppressKeySwitchOffSafetyPromptTimer = null;
    _suppressKeySwitchOffSafetyPrompt = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _clearSuppressKeySwitchOffSafetyPrompt();
    LaserEnableLedHolder.instance.clearLaserEnable();
    // Fire-and-forget: page/route teardown must still request laser off even
    // when dispose cannot await (abnormal leave / Navigator pop).
    unawaited(shutdownForExit());
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
