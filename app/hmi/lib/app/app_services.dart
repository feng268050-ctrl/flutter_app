import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/debug.dart';
import 'package:cyber_hal/input.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/app/flutter_frame_timing_sampler.dart';
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
    ProductInfo? productInfo,
    FrameTimingSampler? frameTimingSampler,
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
    DisplayStack? displayStack,
  }) : bindings = BoardBindings(boardProfile) {
    final b = bindings;
    _productInfoOverride = productInfo;
    // Only attach Flutter timings when we own LinuxSysInfo (tests inject StubSysInfo).
    if (sysInfo != null) {
      _frameTimingSampler =
          frameTimingSampler ?? const FixedFrameTimingSampler();
      this.sysInfo = sysInfo;
      if (sysInfo is StubSysInfo && productInfo == null) {
        _productInfo = sysInfo.productInfo;
      } else if (productInfo != null) {
        _productInfo = productInfo;
      }
    } else {
      _frameTimingSampler = frameTimingSampler ?? FlutterFrameTimingSampler();
      this.sysInfo = b.sysInfo(
        deviceSnReader: deviceSnReader,
        appVersion: kSystemVersion,
        frameTimingSampler: _frameTimingSampler,
        productInfo: productInfo,
      );
      if (productInfo != null) {
        _productInfo = productInfo;
      }
    }
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
    if (displayStack != null) {
      this.displayStack = displayStack;
      _displayStackResolved = true;
    } else {
      this.displayStack = DisplayStack.unknown;
      unawaited(ensureDisplayStack());
    }
  }

  final BoardProfile boardProfile;
  final BoardBindings bindings;
  final DeviceSnReader deviceSnReader;

  ProductInfo? _productInfoOverride;
  ProductInfo? _productInfo;
  Future<ProductInfo>? _productInfoFuture;

  late final FrameTimingSampler _frameTimingSampler;
  late final SysInfo sysInfo;

  /// Factory product identity (`/var/lib/hmi/product.ini`).
  Future<ProductInfo> ensureProductInfo() {
    if (_productInfo != null) {
      return Future<ProductInfo>.value(_productInfo!);
    }
    if (_productInfoOverride != null) {
      _productInfo = _productInfoOverride;
      return Future<ProductInfo>.value(_productInfo!);
    }
    final s = sysInfo;
    if (s is LinuxSysInfo) {
      return _productInfoFuture ??= s.ensureProductInfo().then((p) {
        _productInfo = p;
        return p;
      });
    }
    if (s is StubSysInfo) {
      _productInfo = s.productInfo;
      return Future<ProductInfo>.value(_productInfo!);
    }
    return _productInfoFuture ??= bindings
        .productInfo(deviceSnReader: deviceSnReader)
        .then((p) {
      _productInfo = p;
      return p;
    });
  }
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

  /// flutter-pi vs Weston (Settings gates via [displayStack.mouseSettings]).
  ///
  /// Resolved asynchronously in [ensureDisplayStack] / restore — starts as
  /// [DisplayStack.unknown] until the stamp probe completes.
  late DisplayStack displayStack;

  bool _restoreStarted = false;
  bool _modbusLiveStarted = false;
  bool _displayStackResolved = false;
  Future<DisplayStack>? _displayStackFuture;

  /// True after first successful [ensureModbusLive] (poll stays up for process life).
  bool get modbusLiveStarted => _modbusLiveStarted;

  /// Resolve embedder stamp once (async file I/O — never `*Sync`).
  Future<DisplayStack> ensureDisplayStack() {
    if (_displayStackResolved) {
      return Future<DisplayStack>.value(displayStack);
    }
    return _displayStackFuture ??= bindings.displayStack().then((stack) {
      displayStack = stack;
      _displayStackResolved = true;
      return stack;
    });
  }

  final StreamController<List<ModbusAttributeChange>> _modbusChanges =
      StreamController<List<ModbusAttributeChange>>.broadcast();
  final StreamController<ModbusHealth> _modbusHealth =
      StreamController<ModbusHealth>.broadcast();

  /// Shared Modbus attribute diffs (Home temps + Demo / Device Info).
  Stream<List<ModbusAttributeChange>> get modbusAttributeChanges =>
      _modbusChanges.stream;

  Stream<ModbusHealth> get modbusHealthChanges => _modbusHealth.stream;

  /// Start Modbus live poll; fans out to [modbusAttributeChanges].
  ///
  /// Optional [watchIds] widen the HAL watch allowlist (e.g. Monitor alarms).
  /// Safe to call again after the first start to expand ids without stopping
  /// poll.
  Future<void> ensureModbusLive({Iterable<String>? watchIds}) async {
    try {
      await modbus.startLiveDemo(
        onAttributeChanges: _modbusChanges.add,
        onHealth: _modbusHealth.add,
        watchIds: watchIds,
      );
      _modbusLiveStarted = true;
    } catch (_) {
      if (!_modbusLiveStarted) {
        // leave false so a later retry can succeed
      }
    }
  }

  /// Idempotent post-frame restore (brightness, volume, network prefs, …).
  Future<void> restorePersistedSettingsOnce() async {
    if (_restoreStarted) {
      return;
    }
    _restoreStarted = true;
    try {
      await ensureDisplayStack();
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
