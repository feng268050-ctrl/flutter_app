import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/presentation/work_status_dialog_host.dart';
import 'package:lws_hmi/features/settings/application/laser_work_guard.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

/// Captures which radios were enabled before [UpgradeSafety.quiesceRadios].
final class UpgradeRadioSnapshot {
  const UpgradeRadioSnapshot({
    required this.restoreWifi,
    required this.restoreBluetooth,
  });

  final bool restoreWifi;
  final bool restoreBluetooth;

  static const none = UpgradeRadioSnapshot(
    restoreWifi: false,
    restoreBluetooth: false,
  );

  bool get isEmpty => !restoreWifi && !restoreBluetooth;
}

/// Shared safe-update prep for system OTA, control-board, and camera firmware.
///
/// Order of operations for network-backed applies:
/// 1. [stopWork] — before download (jobs must not run during transfer)
/// 2. download + verify (may need Wi‑Fi / Ethernet)
/// 3. [quiesceRadios] — before flash/burn (Wi‑Fi + BT off; Ethernet stays)
/// 4. apply
/// 5. [restoreRadios] — after apply ends (including whole-device reboot-armed
///    success: Wi‑Fi/BT are not systemd wants, so reboot will not re-enable them;
///    restore also rewrites wanted markers cleared by quiesce)
///
/// When the payload is already local (bundled / host file), call
/// [prepareForApply] once before Modbus/CGI/partition apply.
abstract final class UpgradeSafety {
  /// Stop laser / welding / job outputs (Modbus) and dismiss work dialogs.
  ///
  /// Soft-fails individual steps so upgrade can still proceed when Modbus is
  /// unreachable (host force path).
  static Future<void> stopWork(
    AppServices services, {
    required String reason,
  }) async {
    final host = LaserWorkGuard.registeredHost;
    if (host != null) {
      try {
        await host.forceLaserOffForGuardedAlarm();
      } catch (e) {
        debugPrint('UpgradeSafety: host laser force-off soft-failed: $e');
      }
    }
    try {
      await services.ensureModbusLive();
      await services.modbus.writeAttribute(
        LaserWorkGuard.laserEnableAttribute,
        false,
      );
    } catch (e) {
      debugPrint('UpgradeSafety: laser_enable clear soft-failed: $e');
    }
    await services.disarmLaserEnableForSafety(reason: reason);
    WorkStatusDialogHost.closeDialog();
  }

  /// Turn off Wi‑Fi radio and Bluetooth adapter (Ethernet / USB-SSH remain).
  ///
  /// Returns a snapshot so [restoreRadios] can re-enable what was on.
  /// Soft-fails so boards without radio still upgrade.
  static Future<UpgradeRadioSnapshot> quiesceRadios(AppServices services) async {
    final restoreWifi = _wifiWantedOn(services.wifi.currentRadio);
    final restoreBluetooth =
        _bluetoothWantedOn(services.bluetooth.currentAdapterState);
    try {
      await services.wifi.setRadioEnabled(false);
    } catch (e) {
      debugPrint('UpgradeSafety: Wi‑Fi off soft-failed: $e');
    }
    try {
      await services.bluetooth.setAdapterEnabled(false);
    } catch (e) {
      debugPrint('UpgradeSafety: Bluetooth off soft-failed: $e');
    }
    return UpgradeRadioSnapshot(
      restoreWifi: restoreWifi,
      restoreBluetooth: restoreBluetooth,
    );
  }

  /// Re-enable radios that were on when [quiesceRadios] ran.
  static Future<void> restoreRadios(
    AppServices services,
    UpgradeRadioSnapshot snapshot,
  ) async {
    if (snapshot.isEmpty) {
      return;
    }
    if (snapshot.restoreWifi) {
      try {
        await services.wifi.setRadioEnabled(true);
      } catch (e) {
        debugPrint('UpgradeSafety: Wi‑Fi restore soft-failed: $e');
      }
    }
    if (snapshot.restoreBluetooth) {
      try {
        await services.bluetooth.setAdapterEnabled(true);
      } catch (e) {
        debugPrint('UpgradeSafety: Bluetooth restore soft-failed: $e');
      }
    }
  }

  /// [stopWork] then [quiesceRadios] when network is no longer required.
  static Future<UpgradeRadioSnapshot> prepareForApply(
    AppServices services, {
    required String reason,
  }) async {
    await stopWork(services, reason: reason);
    return quiesceRadios(services);
  }

  static bool _wifiWantedOn(WifiRadioState state) =>
      state == WifiRadioState.on ||
      state == WifiRadioState.starting ||
      state == WifiRadioState.error;

  static bool _bluetoothWantedOn(BluetoothAdapterState state) =>
      state == BluetoothAdapterState.on ||
      state == BluetoothAdapterState.starting ||
      state == BluetoothAdapterState.error;
}
