import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/debug.dart';
import 'package:cyber_hal/input.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/linux_bluez_bluetooth_controller.dart';
import 'package:lws_hmi/platform/http/http_client_controller.dart';
import 'package:lws_hmi/platform/http/linux_http_client_controller.dart';

/// App-scoped HAL / platform controllers (single owner for Home, Settings, Demo).
final class AppServices {
  AppServices({
    required this.boardProfile,
    this.deviceSnReader = const DeviceSnReader(),
    SysInfo? sysInfo,
    ModbusRtuClient? modbusClient,
    GpioLedController? ledController,
    MediaAudioController? audioController,
    BacklightController? backlightController,
    EthernetController? ethernetController,
    WifiController? wifiController,
    HttpClientController? httpClientController,
    DateTimeController? dateTimeController,
    SshDebugController? sshDebugController,
    UsbDebugController? usbDebugController,
    BluetoothController? bluetoothController,
    Keyboard? keyboard,
    MouseSettingsController? mouse,
  }) : bindings = BoardBindings(boardProfile) {
    final b = bindings;
    this.sysInfo = sysInfo ??
        b.sysInfo(deviceSnReader: deviceSnReader, appVersion: kSystemVersion);
    final gpioAsset = boardProfile.resolvedGpioAsset;
    final modbusAsset = boardProfile.resolvedModbusAsset;
    modbus = modbusClient ??
        ModbusRtuClient(
          profile: boardProfile,
          halFuture: (modbusAsset != null && modbusAsset.isNotEmpty)
              ? Future(() => b.modbus())
              : null,
        );
    leds = ledController ??
        GpioLedController(
          profile: boardProfile,
          halFuture: (gpioAsset != null && gpioAsset.isNotEmpty)
              ? Future(() => b.gpio())
              : null,
        );
    audio = audioController ?? b.mediaAudio();
    backlight = backlightController ?? b.backlight();
    ethernet = ethernetController ?? b.ethernetSession();
    wifi = wifiController ?? b.wifiSession();
    dateTime = dateTimeController ?? b.dateTime();
    http = httpClientController ??
        LinuxHttpClientController(dateTimeController: dateTime);
    sshDebug = sshDebugController ?? b.sshDebug();
    usbDebug = usbDebugController ?? b.usbDebug();
    bluetooth = bluetoothController ?? b.bluetooth();
    this.keyboard = keyboard ?? b.keyboard();
    this.mouse = mouse ?? b.mouse();
  }

  final BoardProfile boardProfile;
  final BoardBindings bindings;
  final DeviceSnReader deviceSnReader;

  late final SysInfo sysInfo;
  late final ModbusRtuClient modbus;
  late final GpioLedController leds;
  late final MediaAudioController audio;
  late final BacklightController backlight;
  late final EthernetController ethernet;
  late final WifiController wifi;
  late final DateTimeController dateTime;
  late final HttpClientController http;
  late final SshDebugController sshDebug;
  late final UsbDebugController usbDebug;
  late final BluetoothController bluetooth;
  late final Keyboard keyboard;
  late final MouseSettingsController mouse;

  bool _restoreStarted = false;
  bool _modbusLiveStarted = false;

  final StreamController<List<ModbusAttributeChange>> _modbusChanges =
      StreamController<List<ModbusAttributeChange>>.broadcast();
  final StreamController<ModbusHealth> _modbusHealth =
      StreamController<ModbusHealth>.broadcast();

  /// Shared Modbus attribute diffs (Home temps + Demo / Device Info).
  Stream<List<ModbusAttributeChange>> get modbusAttributeChanges =>
      _modbusChanges.stream;

  Stream<ModbusHealth> get modbusHealthChanges => _modbusHealth.stream;

  /// Start Modbus live poll once; fans out to [modbusAttributeChanges].
  Future<void> ensureModbusLive() async {
    if (_modbusLiveStarted) {
      return;
    }
    _modbusLiveStarted = true;
    try {
      await modbus.startLiveDemo(
        onAttributeChanges: _modbusChanges.add,
        onHealth: _modbusHealth.add,
      );
    } catch (_) {
      _modbusLiveStarted = false;
    }
  }

  /// Idempotent post-frame restore (brightness, volume, network prefs, …).
  Future<void> restorePersistedSettingsOnce() async {
    if (_restoreStarted) {
      return;
    }
    _restoreStarted = true;
    try {
      await bindings.restorePersistedSettings(
        backlight: backlight is LinuxSysfsBacklight
            ? backlight as LinuxSysfsBacklight
            : null,
        mediaAudio: audio is LinuxMediaAudioController
            ? audio as LinuxMediaAudioController
            : null,
        mouse: mouse is LinuxMouseSettingsController
            ? mouse as LinuxMouseSettingsController
            : null,
        wifi: wifi is LinuxWifiSession ? wifi as LinuxWifiSession : null,
        ethernet:
            ethernet is LinuxEthernetSession ? ethernet as LinuxEthernetSession : null,
        bluetooth: bluetooth is LinuxBluezBluetoothController
            ? bluetooth as LinuxBluezBluetoothController
            : null,
        dateTime: dateTime is LinuxDateTimeController
            ? dateTime as LinuxDateTimeController
            : null,
      );
    } catch (_) {
      // Soft-fail: Settings/Demo keep defaults.
    }
  }
}

/// Provides [AppServices] to the subtree.
final class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.services;
  }

  static AppServices? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()?.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      services != oldWidget.services;
}
