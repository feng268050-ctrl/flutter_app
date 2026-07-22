import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/home/presentation/home_bluetooth_status_icon.dart';
import 'package:lws_hmi/features/home/presentation/home_camera_status_icon.dart';
import 'package:lws_hmi/features/home/presentation/home_status_bar_phase.dart';
import 'package:lws_hmi/features/home/presentation/home_wifi_status_icon.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/wifi/wifi_controller.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

/// Top-right Home status strip: Wi‑Fi · Bluetooth · Camera (rightmost).
class HomeStatusBar extends StatefulWidget {
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

  /// Injected for tests; otherwise resolved from [AppScope].
  final WifiController? wifi;
  final BluetoothController? bluetooth;

  @override
  State<HomeStatusBar> createState() => _HomeStatusBarState();
}

class _HomeStatusBarState extends State<HomeStatusBar> {
  WifiRadioState _wifiRadio = WifiRadioState.off;
  WifiConnectionState _wifiConn = WifiConnectionState.disconnected;
  BluetoothAdapterState _btAdapter = BluetoothAdapterState.off;
  List<BluetoothRemoteDevice> _btDevices = const [];
  BluetoothPairingChallenge? _btChallenge;

  StreamSubscription<WifiRadioState>? _wifiRadioSub;
  StreamSubscription<WifiConnectionState>? _wifiConnSub;
  StreamSubscription<BluetoothAdapterState>? _btAdapterSub;
  StreamSubscription<List<BluetoothRemoteDevice>>? _btDevicesSub;
  StreamSubscription<BluetoothPairingChallenge?>? _btChallengeSub;
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
    _bindControllers();
  }

  @override
  void didUpdateWidget(covariant HomeStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
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

    if (mounted) {
      setState(() {});
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
    } catch (_) {
      // Status bar must stay non-fatal if D-Bus briefly fails.
    }
  }

  Future<void> _cancelSubs() async {
    _wifiSignalTimer?.cancel();
    _wifiSignalTimer = null;
    await _wifiRadioSub?.cancel();
    await _wifiConnSub?.cancel();
    await _btAdapterSub?.cancel();
    await _btDevicesSub?.cancel();
    await _btChallengeSub?.cancel();
    _wifiRadioSub = null;
    _wifiConnSub = null;
    _btAdapterSub = null;
    _btDevicesSub = null;
    _btChallengeSub = null;
  }

  @override
  void dispose() {
    unawaited(_cancelSubs());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wifiPhase = mapWifiStatusBarPhase(
      radio: _wifiRadio,
      connection: _wifiConn.phase,
    );
    final btPhase = mapBluetoothStatusBarPhase(
      adapter: _btAdapter,
      devices: _btDevices,
      pairingChallenge: _btChallenge,
    );

    final children = <Widget>[
      if (wifiPhase != HomeConnectivityIconPhase.hidden)
        HomeWifiStatusIcon(
          phase: wifiPhase,
          signalDbm: _wifiConn.signalDbm,
          size: widget.iconSize,
        ),
      if (btPhase != HomeConnectivityIconPhase.hidden)
        HomeBluetoothStatusIcon(
          phase: btPhase,
          size: widget.iconSize,
        ),
      HomeCameraStatusIcon(
        key: const ValueKey('home-status-camera'),
        status: widget.cameraStatus,
        size: widget.iconSize,
      ),
    ];

    return Row(
      key: const ValueKey('home-status-bar'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: widget.gap),
          children[i],
        ],
      ],
    );
  }
}
