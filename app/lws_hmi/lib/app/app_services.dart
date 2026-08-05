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
import 'package:lws_hmi/device/product_property_defaults.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_gate.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_show_overlay_applier.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';
import 'package:lws_hmi/gpio/rgb_led_policy_driver.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/linux_bluez_bluetooth_controller.dart';
import 'package:lws_hmi/platform/datetime/os_wall_clock.dart';
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
    primaryNetwork = b.primaryNetwork(wifi: wifi, ethernet: ethernet);
    dateTime = dateTimeController ?? b.dateTime();
    wallClock = OsWallClock(dateTime)..start();
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

  /// Factory product identity + tunables (`/var/lib/hal/properties.ini`).
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

  /// Production RGB policy; set from [LwsHmiApp] after warn-alarm wiring.
  RgbLedPolicyDriver? rgbLedPolicy;
  late final MediaAudioController audio;
  late final BacklightController backlight;
  late final AutoSleep autoSleep;
  late final ButtonFeedback buttonFeedback;
  late final EthernetController ethernet;
  late final WifiController wifi;
  late final PrimaryNetworkController primaryNetwork;
  late final DateTimeController dateTime;
  late final OsWallClock wallClock;
  late final HttpClientController http;
  late final SshDebugController sshDebug;
  late final UsbOtg usbOtg;
  late final BluetoothController bluetooth;
  late final Keyboard keyboard;
  late final MouseSettingsController mouse;

  /// Shared camera OSD apply path (Settings dialog + LAN HTTP).
  CameraShowOverlayApplier get cameraShowOverlay =>
      _cameraShowOverlay ??= CameraShowOverlayApplier();
  CameraShowOverlayApplier? _cameraShowOverlay;

  bool _restoreStarted = false;
  bool _modbusLiveStarted = false;
  NetworkTimeSyncWatcher? _networkTimeSyncWatcher;

  IpCameraProductSession? _ipCamera;
  Future<IpCameraProductSession>? _ipCameraFuture;

  /// This product session owns a dedicated Ethernet path to its single IPC.
  bool get ipCameraSupported =>
      boardProfile.capabilities.has(Capability.ethernet);

  /// Product IP-camera session (one HAL instance + LWS eth0/MediaMTX).
  ///
  /// Prefer [ensureIpCamera] before first use so host comes from properties.ini.
  IpCameraProductSession? get ipCameraOrNull => _ipCamera;

  /// Resolve product camera host and construct the session once.
  Future<IpCameraProductSession> ensureIpCamera() {
    if (_ipCamera != null) {
      return Future<IpCameraProductSession>.value(_ipCamera!);
    }
    return _ipCameraFuture ??= () async {
      final info = await ensureProductInfo();
      final session = IpCameraProductSession.create(
        productCameraIp: effectiveCameraIpFromProduct(info),
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
  bool _startupLaserDisarmDone = false;

  /// Ensure process-wide continuous Modbus polling (no attribute watch).
  ///
  /// Product rule: one [modbus] client on [AppServices]; every top-level route
  /// (Home / Monitor / Settings / Demo) calls this after first frame so poll
  /// runs even if entry is not Home. UI surfaces open their own
  /// [ModbusRtuClient.watchAttributes] with explicit ids.
  ///
  /// Intercepts: [modbusLiveAllowed] false → no-op; [BootSelfCheckGate.isActive]
  /// → no-op until Home self-check `onComplete` (or a later ensure) runs.
  /// Callers that still issue on-demand reads (`readGroup` / live-cache seed)
  /// MUST also [BootSelfCheckGate.waitForModbusAccess] — this ensure alone does
  /// not serialize those one-shots against the self-check snapshot.
  ///
  /// Also applies properties.ini `control_card_comm_alarm_mode` once (C001 window)
  /// and disarms `control.laser_enable` once at process start so a prior crash
  /// / unclean exit cannot leave the controller armed for emission.
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
      await disarmLaserEnableForSafety(
        reason: 'process-start',
        oncePerProcess: true,
      );
    } catch (_) {
      if (!_modbusLiveStarted) {
        // leave false so a later retry can succeed
      }
    }
  }

  /// Product rule: emission requires an explicit Laser Enable button press.
  ///
  /// Clears laser enable + manual wire work. Used on HMI process start, Quick /
  /// Engineer leave, and process teardown — never while the operator is mid
  /// Laser Enable session on the work page (callers gate that).
  Future<void> disarmLaserEnableForSafety({
    String reason = 'safety',
    bool oncePerProcess = false,
  }) async {
    if (!modbusLiveAllowed) {
      return;
    }
    if (oncePerProcess && _startupLaserDisarmDone) {
      return;
    }
    if (BootSelfCheckGate.isActive) {
      return;
    }
    try {
      await modbus.ensurePolling();
      final ok = await modbus.exclusiveSession(() async {
        // Single CONTROL_FIELD_1 write (bits 0–2 / direction off via word clear).
        return modbus.writeAttribute(DeviceControlIds.controlField1, 0);
      });
      if (ok && oncePerProcess) {
        _startupLaserDisarmDone = true;
      }
      if (!ok) {
        debugPrint('AppServices: disarm laser ($reason) write returned false');
      }
    } catch (e) {
      debugPrint('AppServices: disarm laser ($reason) failed: $e');
    }
  }

  Future<void> _applyCommAlarmModeOnce() async {
    if (_commAlarmModeApplied) {
      return;
    }
    try {
      final info = await ensureProductInfo();
      final mode = effectiveControlCardCommAlarmModeFromProduct(info);
      // Empty after defaults means invalid override — keep modbus.json mode.
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
      await wallClock.refresh();
    } catch (_) {
      // Soft-fail: Settings/Demo keep defaults.
    }
    // Product policy: this App uses Wi‑Fi as the internet uplink (eth = camera).
    try {
      await primaryNetwork.load();
      if (await primaryNetwork.getPrimaryRole() == null) {
        await primaryNetwork.setPrimaryRole(NetRole.wifiStation);
      }
    } catch (_) {
      // Soft-fail: board metric order remains until prefs exist.
    }
    // After wifi/eth syncFromSystem, watch primary IPv4 rising edges.
    _networkTimeSyncWatcher ??= NetworkTimeSyncWatcher(
      dateTime: dateTime,
      wifi: wifi,
      ethernet: ethernet,
      primaryNetwork: primaryNetwork,
    )..start();
  }

  /// Cancel link-up NTP watcher (optional; process exit is enough on appliance).
  void disposeNetworkTimeSyncWatcher() {
    _networkTimeSyncWatcher?.dispose();
    _networkTimeSyncWatcher = null;
  }

  void disposeCameraShowOverlay() {
    _cameraShowOverlay?.dispose();
    _cameraShowOverlay = null;
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
