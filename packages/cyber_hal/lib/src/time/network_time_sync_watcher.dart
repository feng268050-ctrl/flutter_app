import 'dart:async';

import 'package:cyber_hal/src/core/net_role.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/network/ethernet_controller.dart';
import 'package:cyber_hal/src/network/ethernet_models.dart';
import 'package:cyber_hal/src/network/primary_network.dart';
import 'package:cyber_hal/src/network/wifi_controller.dart';
import 'package:cyber_hal/src/network/wifi_models.dart';
import 'package:cyber_hal/src/time/time_service.dart';

/// Runs [DateTimeController.syncFromNetwork] when Automatic mode is on and the
/// **primary** (product-chosen internet) network gains IPv4.
///
/// Primary comes from [PrimaryNetworkController] (product `setPrimaryRole`).
/// Listens to both Wi‑Fi and Ethernet streams but only acts on the current
/// primary role — camera LAN must not trigger NTP.
class NetworkTimeSyncWatcher {
  NetworkTimeSyncWatcher({
    required DateTimeController dateTime,
    required WifiController wifi,
    required EthernetController ethernet,
    required PrimaryNetworkController primaryNetwork,
    this.debounce = const Duration(seconds: 2),
  })  : _dateTime = dateTime,
        _wifi = wifi,
        _ethernet = ethernet,
        _primaryNetwork = primaryNetwork;

  final DateTimeController _dateTime;
  final WifiController _wifi;
  final EthernetController _ethernet;
  final PrimaryNetworkController _primaryNetwork;

  final Duration debounce;

  StreamSubscription<WifiConnectionState>? _wifiSub;
  StreamSubscription<EthLinkState>? _ethSub;
  StreamSubscription<RankedNetworkPath?>? _primarySub;
  Timer? _debounceTimer;
  bool _online = false;
  bool _syncInFlight = false;
  bool _started = false;

  static bool isPrimaryOnline({
    required RankedNetworkPath? primary,
    required WifiConnectionState wifi,
    required EthLinkState ethernet,
  }) {
    if (primary == null) {
      return false;
    }
    switch (primary.role) {
      case NetRole.wifiStation:
        return wifi.phase == WifiConnectionPhase.connected &&
            (wifi.ipv4?.isNotEmpty ?? false);
      case NetRole.ethernetPrimary:
        return ethernet.phase == EthLinkPhase.up && ethernet.hasIpv4;
    }
  }

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _online = isPrimaryOnline(
      primary: _primaryNetwork.currentPrimary,
      wifi: _wifi.currentConnection,
      ethernet: _ethernet.currentLink,
    );
    // Subscribe to both; gate on current primary so setPrimaryRole works live.
    _wifiSub = _wifi.connection.listen((_) => _evaluate());
    _ethSub = _ethernet.link.listen((_) => _evaluate());
    _primarySub = _primaryNetwork.primaryChanges.listen((_) {
      _evaluate();
    });
    lwsTrace(
      'datetime: network sync watcher started '
      '(primary=${_primaryNetwork.currentPrimary?.iface} online=$_online)',
    );
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    unawaited(_wifiSub?.cancel());
    unawaited(_ethSub?.cancel());
    unawaited(_primarySub?.cancel());
    _wifiSub = null;
    _ethSub = null;
    _primarySub = null;
    _started = false;
  }

  void _evaluate() {
    final next = isPrimaryOnline(
      primary: _primaryNetwork.currentPrimary,
      wifi: _wifi.currentConnection,
      ethernet: _ethernet.currentLink,
    );
    if (next && !_online) {
      _scheduleSync();
    }
    _online = next;
  }

  void _scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      _debounceTimer = null;
      unawaited(_syncIfAutomatic());
    });
  }

  Future<void> _syncIfAutomatic() async {
    if (_syncInFlight) {
      return;
    }
    _syncInFlight = true;
    try {
      final mode = await _dateTime.getSyncMode();
      if (mode != TimeSyncMode.network) {
        lwsTrace('datetime: primary link up but sync_mode=$mode — skip');
        return;
      }
      if (!isPrimaryOnline(
        primary: _primaryNetwork.currentPrimary,
        wifi: _wifi.currentConnection,
        ethernet: _ethernet.currentLink,
      )) {
        return;
      }
      lwsTrace(
        'datetime: primary link up '
        '(${_primaryNetwork.currentPrimary?.iface}) → syncFromNetwork',
      );
      final r = await _dateTime.syncFromNetwork();
      lwsTrace('datetime: primary link-up sync → $r');
      try {
        if (await _dateTime.getAutoTimezone()) {
          final tz = await _dateTime.syncTimezoneFromNetwork();
          lwsTrace('datetime: primary link-up timezone → $tz');
        }
      } catch (e) {
        lwsTrace('datetime: primary link-up timezone failed: $e');
      }
    } catch (e) {
      lwsTrace('datetime: primary link-up sync failed: $e');
    } finally {
      _syncInFlight = false;
    }
  }
}
