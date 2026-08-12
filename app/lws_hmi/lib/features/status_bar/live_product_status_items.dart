import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/status_bar/status_bar_phase.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/cloud/cloud_link_ui_status.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime_scope.dart';
import 'package:lws_hmi/platform/cloud/remote_lock_scope.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

/// Live binder: maps App Wi‑Fi / BT / camera session → CyberUI status icons.
class LiveProductStatusItems extends StatefulWidget {
  const LiveProductStatusItems({
    super.key,
    required this.builder,
    this.cameraStatus,
    this.iconSize = 28,
    this.wifi,
    this.bluetooth,
  });

  /// When null, resolves from [AppServices.ensureIpCamera] / session stream.
  final IpCameraUiStatus? cameraStatus;
  final double iconSize;
  final WifiController? wifi;
  final BluetoothController? bluetooth;
  final Widget Function(BuildContext context, List<Widget> items) builder;

  @override
  State<LiveProductStatusItems> createState() => _LiveProductStatusItemsState();
}

class _LiveProductStatusItemsState extends State<LiveProductStatusItems> {
  WifiRadioState _wifiRadio = WifiRadioState.off;
  WifiConnectionState _wifiConn = WifiConnectionState.disconnected;
  BluetoothAdapterState _btAdapter = BluetoothAdapterState.off;
  List<BluetoothRemoteDevice> _btDevices = const [];
  BluetoothPairingChallenge? _btChallenge;
  IpCameraUiStatus _camera = IpCameraUiStatus.connecting;
  CloudLinkUiStatus _cloudLink = CloudLinkUiStatus.disabled;

  StreamSubscription<WifiRadioState>? _wifiRadioSub;
  StreamSubscription<WifiConnectionState>? _wifiConnSub;
  StreamSubscription<BluetoothAdapterState>? _btAdapterSub;
  StreamSubscription<List<BluetoothRemoteDevice>>? _btDevicesSub;
  StreamSubscription<BluetoothPairingChallenge?>? _btChallengeSub;
  StreamSubscription<IpCameraUiStatus>? _cameraSub;
  StreamSubscription<CloudLinkUiStatus>? _cloudLinkSub;
  Timer? _wifiSignalTimer;
  WifiController? _wifi;

  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) {
      return;
    }
    _wired = true;
    if (widget.cameraStatus != null) {
      _camera = widget.cameraStatus!;
    }
    _bindControllers();
  }

  @override
  void didUpdateWidget(covariant LiveProductStatusItems oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cameraStatus != null &&
        widget.cameraStatus != oldWidget.cameraStatus) {
      _camera = widget.cameraStatus!;
    }
    if (oldWidget.wifi != widget.wifi ||
        oldWidget.bluetooth != widget.bluetooth) {
      unawaited(_rebind());
    }
  }

  Future<void> _rebind() async {
    await _cancelSubs();
    _bindControllers();
  }

  void _bindControllers() {
    final services = AppScope.maybeOf(context);
    final wifi = widget.wifi ?? services?.wifi;
    final bt = widget.bluetooth ?? services?.bluetooth;
    _wifi = wifi;

    if (wifi != null) {
      _wifiRadio = wifi.currentRadio;
      _wifiConn = wifi.currentConnection;
      _wifiRadioSub = wifi.radio.listen((s) {
        if (mounted) {
          setState(() => _wifiRadio = s);
          _syncWifiSignalPoll();
        }
      });
      _wifiConnSub = wifi.connection.listen((s) {
        if (mounted) {
          setState(() => _wifiConn = s);
          _syncWifiSignalPoll();
        }
      });
      _syncWifiSignalPoll();
    }

    if (bt != null) {
      _btAdapter = bt.currentAdapterState;
      _btDevices = List<BluetoothRemoteDevice>.of(bt.currentDevices);
      _btChallenge = bt.currentPairingChallenge;
      _btAdapterSub = bt.adapterState.listen((s) {
        if (mounted) {
          setState(() => _btAdapter = s);
        }
      });
      _btDevicesSub = bt.devices.listen((d) {
        if (mounted) {
          setState(() => _btDevices = d);
        }
      });
      _btChallengeSub = bt.pairingChallenge.listen((c) {
        if (mounted) {
          setState(() => _btChallenge = c);
        }
      });
    }

    if (widget.cameraStatus == null &&
        services != null &&
        services.ipCameraSupported) {
      unawaited(_bindCamera(services));
    }

    _bindCloudLink();

    if (mounted) {
      setState(() {});
    }
  }

  void _bindCloudLink() {
    final runtime = CloudLocalRuntimeScope.maybeOf(context);
    if (runtime == null) {
      _cloudLink = CloudLinkUiStatus.disabled;
      return;
    }
    _cloudLink = runtime.currentLinkStatus;
    unawaited(_cloudLinkSub?.cancel());
    _cloudLinkSub = runtime.linkStatusChanges.listen((s) {
      if (mounted) {
        setState(() => _cloudLink = s);
      }
    });
  }

  Future<void> _bindCamera(AppServices services) async {
    try {
      final session = await services.ensureIpCamera();
      if (!mounted) {
        return;
      }
      setState(() => _camera = session.currentStatus);
      await _cameraSub?.cancel();
      _cameraSub = session.status.listen((s) {
        if (mounted) {
          setState(() => _camera = s);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _camera = const IpCameraUiStatus(phase: IpCameraUiPhase.failed);
        });
      }
    }
  }

  void _syncWifiSignalPoll() {
    final linked = _wifi != null &&
        _wifiRadio != WifiRadioState.off &&
        _wifiConn.phase == WifiConnectionPhase.connected;
    if (linked) {
      _wifiSignalTimer ??= Timer.periodic(
        const Duration(seconds: 4),
        (_) => unawaited(_pollWifiSignal()),
      );
      unawaited(_pollWifiSignal());
    } else {
      _wifiSignalTimer?.cancel();
      _wifiSignalTimer = null;
    }
  }

  Future<void> _pollWifiSignal() async {
    final wifi = _wifi;
    if (wifi == null || !mounted) {
      return;
    }
    try {
      final link = await wifi.linkDetails();
      if (!mounted) {
        return;
      }
      if (link.signalDbm != _wifiConn.signalDbm &&
          _wifiConn.phase == WifiConnectionPhase.connected) {
        setState(() {
          _wifiConn = _wifiConn.copyWith(signalDbm: link.signalDbm);
        });
      }
    } catch (_) {}
  }

  Future<void> _cancelSubs() async {
    _wifiSignalTimer?.cancel();
    _wifiSignalTimer = null;
    await _wifiRadioSub?.cancel();
    await _wifiConnSub?.cancel();
    await _btAdapterSub?.cancel();
    await _btDevicesSub?.cancel();
    await _btChallengeSub?.cancel();
    await _cameraSub?.cancel();
    await _cloudLinkSub?.cancel();
    _wifiRadioSub = null;
    _wifiConnSub = null;
    _btAdapterSub = null;
    _btDevicesSub = null;
    _btChallengeSub = null;
    _cameraSub = null;
    _cloudLinkSub = null;
  }

  @override
  void dispose() {
    unawaited(_cancelSubs());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.cameraStatus ?? _camera;
    final lockStore = RemoteLockScope.maybeOf(context);
    final remoteLocked = lockStore?.isLocked ?? false;
    final items = buildProductStatusIconItems(
      wifiPhase: mapWifiStatusBarPhase(
        radio: _wifiRadio,
        connection: _wifiConn.phase,
      ),
      bluetoothPhase: mapBluetoothStatusBarPhase(
        adapter: _btAdapter,
        devices: _btDevices,
        pairingChallenge: _btChallenge,
      ),
      cameraStatus: mapCameraLinkStatus(camera.phase),
      wifiSignalDbm: _wifiConn.signalDbm,
      iconSize: widget.iconSize,
      remoteLocked: remoteLocked,
      cloudPhase: _cloudLink.phase,
    );
    return widget.builder(context, items);
  }
}

/// Home overlay host for [CyberHomeStatusBar].
class HomeStatusBar extends StatelessWidget {
  const HomeStatusBar({
    super.key,
    required this.cameraStatus,
    this.iconSize = 28,
    this.gap = 12,
    this.wifi,
    this.bluetooth,
  });

  final IpCameraUiStatus cameraStatus;
  final double iconSize;
  final double gap;
  final WifiController? wifi;
  final BluetoothController? bluetooth;

  @override
  Widget build(BuildContext context) {
    return LiveProductStatusItems(
      cameraStatus: cameraStatus,
      iconSize: iconSize,
      wifi: wifi,
      bluetooth: bluetooth,
      builder: (context, items) {
        return CyberHomeStatusBar(
          key: const ValueKey('home-status-bar'),
          items: items,
          gap: gap,
          iconSize: iconSize,
        );
      },
    );
  }
}
