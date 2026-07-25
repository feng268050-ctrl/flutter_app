import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';

/// Optional hook when a dangerous bypass is turned OFF while work may be active.
///
/// Parity with lws-ui `LaserWorkGuard.evaluateAndInterruptIfNeeded`. Assign when
/// a laser interrupt module exists; leave null until then.
typedef LaserWorkInterruptCallback = void Function();

/// Read/write facade for dangerous-operation bypass toggles (App store).
///
/// Policy: use [LaserAlarmPolicy] pure helpers with these flags — do not
/// re-implement allow-* / keepLaserOn rules in widgets.
///
/// TODO(warn-alarm): Wire into warn severity / laser enable preflight /
/// runtime interrupt when those modules exist. On bypass OFF, invoke
/// [onBypassDisabled] if set.
final class DangerousOperationsSettings extends ChangeNotifier {
  DangerousOperationsSettings(
    this._store, {
    this.onBypassDisabled,
  }) {
    _store.addListener(_onStoreChanged);
  }

  final AdvancedSettingsStore _store;

  /// Called after a dangerous toggle is set to false (parity re-evaluate).
  LaserWorkInterruptCallback? onBypassDisabled;

  bool get keepLaserOnWhileAlarmed => _store.keepLaserOnWhileAlarmed;
  bool get allowWorkAfterCameraAlarm => _store.allowWorkAfterCameraAlarm;
  bool get allowWorkAfterGasAlarm => _store.allowWorkAfterGasAlarm;
  bool get allowWorkAfterLensContamination =>
      _store.allowWorkAfterLensContamination;
  bool get allowWorkAfterFeederAlarm => _store.allowWorkAfterFeederAlarm;

  LaserAlarmPolicySnapshot get policySnapshot => LaserAlarmPolicySnapshot(
        keepLaserOnWhileAlarmed: keepLaserOnWhileAlarmed,
        allowWorkAfterCameraAlarm: allowWorkAfterCameraAlarm,
        allowWorkAfterGasAlarm: allowWorkAfterGasAlarm,
        allowWorkAfterLensContamination: allowWorkAfterLensContamination,
        allowWorkAfterFeederAlarm: allowWorkAfterFeederAlarm,
      );

  Future<void> setKeepLaserOnWhileAlarmed(bool enabled) =>
      _setDangerous(() => _store.setKeepLaserOnWhileAlarmed(enabled), enabled);

  Future<void> setAllowWorkAfterCameraAlarm(bool enabled) => _setDangerous(
        () => _store.setAllowWorkAfterCameraAlarm(enabled),
        enabled,
      );

  Future<void> setAllowWorkAfterGasAlarm(bool enabled) =>
      _setDangerous(() => _store.setAllowWorkAfterGasAlarm(enabled), enabled);

  Future<void> setAllowWorkAfterLensContamination(bool enabled) =>
      _setDangerous(
        () => _store.setAllowWorkAfterLensContamination(enabled),
        enabled,
      );

  Future<void> setAllowWorkAfterFeederAlarm(bool enabled) => _setDangerous(
        () => _store.setAllowWorkAfterFeederAlarm(enabled),
        enabled,
      );

  Future<void> _setDangerous(
    Future<void> Function() persist,
    bool enabled,
  ) async {
    await persist();
    if (!enabled) {
      onBypassDisabled?.call();
    }
  }

  void _onStoreChanged() => notifyListeners();

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
