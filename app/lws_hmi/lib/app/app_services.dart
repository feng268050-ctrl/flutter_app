import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/input.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:cyber_hal/usb_otg.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/app/flutter_frame_timing_sampler.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_gate.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
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
    AutoSleep? autoSleep,
    ButtonFeedback? buttonFeedback,
    EthernetController? ethernetController,
    WifiController? wifiController,
    HttpClientController? httpClientController,
    DateTimeController? dateTimeController,
    SshDebugController? sshDebugController,
    UsbOtg? usbOtg,
    BluetoothController? bluetoothController,
    Keyboard? keyboard,
    MouseSettingsController? mouse,
    IpCameraProductSession? ipCamera,
  }) : bindings = BoardBindings(boardProfile) {
    _ipCamera = ipCamera;
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
    this.autoSleep = autoSleep ?? b.autoSleep();
    this.buttonFeedback = buttonFeedback ?? b.buttonFeedback(mediaAudio: audio);
    ethernet = ethernetController ?? b.ethernetSession();
    wifi = wifiController ?? b.wifiSession();
    dateTime = dateTimeController ?? b.dateTime();
    http = httpClientController ??
        LinuxHttpClientController(dateTimeController: dateTime);
    sshDebug = sshDebugController ?? b.sshDebug();
    this.usbOtg = usbOtg ?? b.usbOtg();
    bluetooth = bluetoothController ?? b.bluetooth();
    this.keyboard = keyboard ?? b.keyboard();
    this.mouse = mouse ?? b.mouse();
  }

  final BoardProfile boardProfile;
  final BoardBindings bindings;
  final DeviceSnReader deviceSnReader;

  ProductInfo? _productInfoOverride;
  ProductInfo? _productInfo;
  Future<ProductInfo>? _productInfoFuture;

  late final FrameTimingSampler _frameTimingSampler;
  late final SysInfo sysInfo;

  /// Factory product identity (`/var/lib/hal/product.ini`).
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
    return _productInfoFuture ??=
        bindings.productInfo(deviceSnReader: deviceSnReader).then((p) {
      _productInfo = p;
      return p;
    });
  }

  late final ModbusRtuClient modbus;
  late final GpioLedController leds;
  late final MediaAudioController audio;
  late final BacklightController backlight;
  late final AutoSleep autoSleep;
  late final ButtonFeedback buttonFeedback;
  late final EthernetController ethernet;
  late final WifiController wifi;
  late final DateTimeController dateTime;
  late final HttpClientController http;
  late final SshDebugController sshDebug;
  late final UsbOtg usbOtg;
  late final BluetoothController bluetooth;
  late final Keyboard keyboard;
  late final MouseSettingsController mouse;

  bool _restoreStarted = false;
  bool _modbusLiveStarted = false;

  IpCameraProductSession? _ipCamera;
  Future<IpCameraProductSession>? _ipCameraFuture;

  /// This product session owns a dedicated Ethernet path to its single IPC.
  bool get ipCameraSupported =>
      boardProfile.capabilities.has(Capability.ethernet);

  /// Product IP-camera session (one HAL instance + LWS eth0/MediaMTX).
  ///
  /// Prefer [ensureIpCamera] before first use so host comes from product.ini.
  IpCameraProductSession? get ipCameraOrNull => _ipCamera;

  /// Resolve product camera host and construct the session once.
  Future<IpCameraProductSession> ensureIpCamera() {
    if (_ipCamera != null) {
      return Future<IpCameraProductSession>.value(_ipCamera!);
    }
    return _ipCameraFuture ??= () async {
      final info = await ensureProductInfo();
      final session = IpCameraProductSession.create(
        productCameraIp: info.cameraIp(),
        ethernet: ethernet,
        wifi: wifi,
      );
      _ipCamera = session;
      return session;
    }();
  }

  /// True after first successful [ensureModbusLive] (poll stays up for process life).
  bool get modbusLiveStarted => _modbusLiveStarted;

  /// True when the board profile advertises Modbus and has a config asset.
  ///
  /// Sim / host stubs without `Capability.modbus` skip live poll (no UART).
  bool get modbusLiveAllowed {
    if (!boardProfile.capabilities.has(Capability.modbus)) {
      return false;
    }
    final asset = boardProfile.resolvedModbusAsset;
    return asset != null && asset.isNotEmpty;
  }

  bool _commAlarmModeApplied = false;

  /// Ensure process-wide continuous Modbus polling (no attribute watch).
  ///
  /// Product rule: one [modbus] client on [AppServices]; every top-level route
  /// (Home / Monitor / Settings / Demo) calls this after first frame so poll
  /// runs even if entry is not Home. UI surfaces open their own
  /// [ModbusRtuClient.watchAttributes] with explicit ids.
  ///
  /// Intercepts: [modbusLiveAllowed] false → no-op; [BootSelfCheckGate.isActive]
  /// → no-op until Home self-check `onComplete` (or a later ensure) runs.
  ///
  /// Also applies product.ini `control_card_comm_alarm_mode` once (C001 window).
  Future<void> ensureModbusLive() async {
    if (!modbusLiveAllowed) {
      return;
    }
    if (BootSelfCheckGate.isActive) {
      return;
    }
    try {
      await modbus.ensurePolling();
      _modbusLiveStarted = true;
      await _applyCommAlarmModeOnce();
    } catch (_) {
      if (!_modbusLiveStarted) {
        // leave false so a later retry can succeed
      }
    }
  }

  Future<void> _applyCommAlarmModeOnce() async {
    if (_commAlarmModeApplied) {
      return;
    }
    try {
      final info = await ensureProductInfo();
      final mode = info.controlCardCommAlarmMode();
      // Empty → keep modbus.json default (`slide_window`).
      if (mode.isNotEmpty) {
        await modbus.applyHealthWindowMode(mode);
      }
      _commAlarmModeApplied = true;
    } catch (_) {
      // Soft-fail: C001 keeps asset JSON mode until a later ensure succeeds.
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
        ethernet: ethernet is LinuxEthernetSession
            ? ethernet as LinuxEthernetSession
            : null,
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
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

/// Post-frame [AppServices.ensureModbusLive] for top-level routes (poll only).
///
/// Call from Home / Monitor / Settings / Demo so continuous poll starts even
/// when the entry route is not Home. Attribute watches stay on each UI surface.
void scheduleEnsureModbusLive(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) {
      return;
    }
    final services = AppScope.maybeOf(context);
    if (services == null) {
      return;
    }
    unawaited(services.ensureModbusLive());
  });
}
