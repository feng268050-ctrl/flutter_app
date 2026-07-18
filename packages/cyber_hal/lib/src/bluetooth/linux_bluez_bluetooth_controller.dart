import 'dart:async';
import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:cyber_hal/src/bluetooth/bluetooth_controller.dart';
import 'package:cyber_hal/src/bluetooth/bluetooth_models.dart';
import 'package:cyber_hal/src/bluetooth/bluetoothctl_parse.dart';
import 'package:cyber_hal/src/bluetooth/hmi_bluez_agent.dart';
import 'package:cyber_hal/src/bluetooth/bt_stack.dart';
import 'package:cyber_hal/src/bluetooth/bluez_ops.dart';
import 'package:cyber_hal/src/bluetooth/keyboard_battery_keepalive.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';

/// BlueZ D-Bus for status and Device1 writes; [BtStack] for board bring-up.
///
/// Product write path is [DBusBluezOps] (Pair/Connect/Trusted/Remove) — no
/// `bluetoothctl` / `busctl` shell. Prefer [BoardBindings.bluetooth].
class LinuxBluezBluetoothController implements BluetoothController {
  LinuxBluezBluetoothController({
    BtStack? btStack,
    BluezOps? ops,
    BlueZClient? client,
    this.a2dpPrefPath = '/var/lib/bluetooth/bt-a2dp-sink',
    this.btWantedPath = '/var/lib/bluetooth/bt-wanted',
    this.hmiAgentMarkerPath = '/run/bt-hmi-agent',
  }) : _ownedClient = client == null,
       _client = client ?? BlueZClient(),
       _btStack = btStack ?? SystemdBluezStack() {
    _ops = ops ?? DBusBluezOps(() => _client);
    unawaited(_loadA2dpPref());
  }

  final String a2dpPrefPath;
  final String btWantedPath;
  final String hmiAgentMarkerPath;
  final BtStack _btStack;
  late final BluezOps _ops;
  final bool _ownedClient;
  BlueZClient _client;

  final _stateCtrl = StreamController<BluetoothAdapterState>.broadcast();
  final _infoCtrl = StreamController<BluetoothAdapterInfo>.broadcast();
  final _devicesCtrl =
      StreamController<List<BluetoothRemoteDevice>>.broadcast();
  final _scanCtrl = StreamController<bool>.broadcast();
  final _challengeCtrl =
      StreamController<BluetoothPairingChallenge?>.broadcast();
  final _a2dpCtrl = StreamController<bool>.broadcast();

  BluetoothAdapterState _state = BluetoothAdapterState.off;
  BluetoothAdapterInfo _info = const BluetoothAdapterInfo();
  final Map<String, BluetoothRemoteDevice> _deviceMap = {};
  final Set<String> _discoveredAddresses = {};
  /// Snapshot of this scan session so BlueZ LE object expiry does not empty the UI.
  final Map<String, BluetoothRemoteDevice> _scanSession = {};
  bool _scanning = false;
  bool _a2dpSinkEnabled = false;
  BluetoothPairingChallenge? _challenge;
  String? _lastError;
  Timer? _wantedWatch;
  Timer? _scanTimeout;
  int _wantedTicks = 0;
  bool _clientConnected = false;
  bool _clientListenersWired = false;
  bool _agentRegistered = false;
  bool _outboundPairActive = false;
  bool _outboundUserConsented = false;
  /// Set by [cancelPairing]; pair/connect wait loops check and exit early.
  bool _pairAbort = false;
  String? _consentChallengeId;
  Completer<bool>? _consentWait;
  int _agentPathSeq = 0;
  bool _autoRecoverInFlight = false;
  bool _suppressDaemonRecover = false;
  Future<void> _opChain = Future<void>.value();
  final List<StreamSubscription<dynamic>> _subs = [];
  final Set<String> _devicePropWired = {};
  final Set<String> _adapterPropWired = {};
  /// Bumped on Cancel / Remove so in-flight input attach exits wait loops.
  int _hidEnsureEpoch = 0;
  final Map<String, bool> _lastConnectedByAddr = {};
  /// Latest evdev probe per HID address (null = N/A).
  final Map<String, bool> _hidInputReadyByAddr = {};
  /// User Disconnect sticky: do not auto-Trust peer re-links until explicit Connect.
  final Set<String> _stickyUntrustAddrs = {};
  /// Explicit Remove in flight — do not keep a bonded UI stub on Device1 drop.
  final Set<String> _forgettingAddrs = {};
  bool _hidEnsureInFlight = false;
  final KeyboardBatteryKeepalive _batteryKeepalive = KeyboardBatteryKeepalive();
  HmiBluezAgent? _agent;

  static const _wantedWatchMaxTicks = 120;
  static const _gattGrace = Duration(seconds: 15);
  static const _hogSettle = Duration(seconds: 8);
  static final _hogpUuid =
      BlueZUUID.fromString('00001812-0000-1000-8000-00805f9b34fb');
  static final _classicHidUuid =
      BlueZUUID.fromString('00001124-0000-1000-8000-00805f9b34fb');

  @override
  String? get lastError => _lastError;

  @override
  BluetoothAdapterState get currentAdapterState => _state;

  @override
  BluetoothAdapterInfo get currentAdapterInfo => _info;

  @override
  List<BluetoothRemoteDevice> get currentDevices =>
      _deviceMap.values.toList(growable: false);

  @override
  bool get currentScanning => _scanning;

  @override
  BluetoothPairingChallenge? get currentPairingChallenge => _challenge;

  @override
  bool get currentA2dpSinkEnabled => _a2dpSinkEnabled;

  @override
  Stream<BluetoothAdapterState> get adapterState => _stateCtrl.stream;

  @override
  Stream<BluetoothAdapterInfo> get adapterInfo => _infoCtrl.stream;

  @override
  Stream<List<BluetoothRemoteDevice>> get devices => _devicesCtrl.stream;

  @override
  Stream<List<BluetoothRemoteDevice>> get incomingDevices => devices;

  @override
  List<BluetoothRemoteDevice> get currentIncomingDevices => currentDevices;

  @override
  Stream<bool> get scanning => _scanCtrl.stream;

  @override
  Stream<BluetoothPairingChallenge?> get pairingChallenge =>
      _challengeCtrl.stream;

  @override
  Stream<bool> get a2dpSinkEnabled => _a2dpCtrl.stream;

  Future<T> _serialized<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _opChain = _opChain.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  void _emitState(BluetoothAdapterState s) {
    _state = s;
    if (!_stateCtrl.isClosed) {
      _stateCtrl.add(s);
    }
  }

  void _emitInfo(BluetoothAdapterInfo info) {
    _info = info;
    if (!_infoCtrl.isClosed) {
      _infoCtrl.add(info);
    }
  }

  void _emitDevices() {
    // Re-attach scan-session snapshots BlueZ may have dropped.
    for (final e in _scanSession.entries) {
      _deviceMap.putIfAbsent(e.key, () => e.value.copyWith(discovered: true));
      _discoveredAddresses.add(e.key);
    }
    final list = _deviceMap.values.toList(growable: false)
      ..sort((a, b) {
        final ar = a.rssi ?? -999;
        final br = b.rssi ?? -999;
        if (ar != br) {
          return br.compareTo(ar);
        }
        return a.address.compareTo(b.address);
      });
    if (!_devicesCtrl.isClosed) {
      _devicesCtrl.add(list);
    }
  }

  void _emitScanning(bool v) {
    _scanning = v;
    if (!_scanCtrl.isClosed) {
      _scanCtrl.add(v);
    }
  }

  void _emitChallenge(BluetoothPairingChallenge? c) {
    _challenge = c;
    if (!_challengeCtrl.isClosed) {
      _challengeCtrl.add(c);
    }
  }

  void _emitA2dp(bool enabled) {
    _a2dpSinkEnabled = enabled;
    if (!_a2dpCtrl.isClosed) {
      _a2dpCtrl.add(enabled);
    }
  }

  Future<ProcessResult> _run(List<String> cmd) async {
    lwsTrace('bt: ${cmd.join(' ')}');
    return Process.run(cmd.first, cmd.sublist(1));
  }

  void _throwIfPairAbort([String? address]) {
    if (_pairAbort) {
      throw BluetoothOperationException('Pairing cancelled', address: address);
    }
  }

  Future<void> _loadA2dpPref() async {
    try {
      final f = File(a2dpPrefPath);
      if (!await f.exists()) {
        _emitA2dp(false);
        return;
      }
      final v = (await f.readAsString()).trim();
      _emitA2dp(
        v == '1' || v.toLowerCase() == 'on' || v.toLowerCase() == 'true',
      );
    } catch (_) {
      _emitA2dp(false);
    }
  }

  Future<void> _writeWanted(bool wanted) async {
    try {
      final f = File(btWantedPath);
      if (wanted) {
        await f.parent.create(recursive: true);
        await f.writeAsString('', flush: true);
      } else if (await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('bt: wanted marker failed: $e');
    }
  }

  Future<void> _writeHmiAgentMarker(bool present) async {
    try {
      final f = File(hmiAgentMarkerPath);
      if (present) {
        await f.parent.create(recursive: true);
        await f.writeAsString('1', flush: true);
      } else if (await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('bt: hmi agent marker failed: $e');
    }
  }

  Future<bool> _bluetoothServiceActive() async {
    try {
      final r =
          await _run(const ['systemctl', 'is-active', 'bluetooth.service']);
      return (r.stdout as String? ?? '').trim() == 'active';
    } catch (_) {
      return false;
    }
  }

  Future<bool> _bluealsaActive() async {
    try {
      final r = await _run(const ['systemctl', 'is-active', 'bluealsa.service']);
      return (r.stdout as String? ?? '').trim() == 'active';
    } catch (_) {
      return false;
    }
  }

  BlueZAdapter? get _adapter =>
      _client.adapters.isEmpty ? null : _client.adapters.first;

  BluetoothRemoteDevice _mapDevice(BlueZDevice d, {bool? discovered}) {
    final addr = BluetoothctlParse.normalizeAddress(d.address);
    final name = d.alias.isNotEmpty ? d.alias : d.name;
    final uuids = d.uuids.map((u) => u.toString()).toList(growable: false);
    final rssi = d.rssi;
    final kind = inferBluetoothDeviceKind(
      icon: d.icon,
      deviceClass: d.deviceClass,
      uuids: uuids,
    );
    final prev = _deviceMap[addr];
    final paired = d.paired || (prev?.paired == true);
    final hidLike = kind == BluetoothDeviceKind.keyboard ||
        kind == BluetoothDeviceKind.mouse ||
        (prev != null && _isHidLikeRemote(prev));
    return BluetoothRemoteDevice(
      address: addr,
      name: name,
      paired: paired,
      trusted: d.trusted,
      connected: d.connected,
      inputReady: hidLike ? _hidInputReadyByAddr[addr] : null,
      discovered: discovered ??
          _discoveredAddresses.contains(addr) || (prev?.discovered ?? false),
      rssi: rssi == 0 && prev?.rssi != null ? prev!.rssi : (rssi == 0 ? null : rssi),
      batteryPercent: prev?.batteryPercent,
      kind: kind == BluetoothDeviceKind.unknown && prev != null
          ? prev.kind
          : kind,
      uuids: uuids,
      icon: d.icon,
    );
  }

  void _upsertDevice(BlueZDevice d, {bool markDiscovered = false}) {
    final addr = BluetoothctlParse.normalizeAddress(d.address);
    final mapped = _mapDevice(
      d,
      discovered: markDiscovered ? true : null,
    );
    if (markDiscovered || _scanning) {
      if (!isBluetoothNearbyCandidate(mapped) &&
          !mapped.paired &&
          !mapped.trusted &&
          !mapped.connected) {
        // Do not pollute the map with Settings-irrelevant LE spam.
        return;
      }
      _discoveredAddresses.add(addr);
      _scanSession[addr] = mapped.copyWith(discovered: true);
    }
    _deviceMap[addr] = mapped;
    // Keep bond flags in the scan snapshot so a temporary LE Device1 drop
    // does not resurrect an unpaired ghost row (UI paired=false).
    if (mapped.paired || mapped.trusted) {
      _scanSession[addr] = mapped;
    }
    _emitDevices();
  }

  void _removeDeviceAddress(String address) {
    final addr = BluetoothctlParse.normalizeAddress(address);
    _devicePropWired.remove(addr);
    final prev = _deviceMap[addr];
    final forgetting = _forgettingAddrs.contains(addr);
    // BlueZ often drops LE Device1 while the bond remains. Do not replace a
    // known bond with an unpaired scan-session snapshot — unless the user
    // asked to Remove (forget).
    if (!forgetting && prev != null && (prev.paired || prev.trusted)) {
      final kept = prev.copyWith(connected: false, discovered: false);
      _deviceMap[addr] = kept;
      _scanSession[addr] = kept;
      _lastConnectedByAddr[addr] = false;
      _setHidInputReady(addr, false);
      _emitDevices();
      return;
    }
    // Keep scan-session rows after BlueZ drops temporary LE Device1 objects.
    final cached = _scanSession[addr];
    if (!forgetting &&
        cached != null &&
        !cached.paired &&
        !cached.trusted &&
        !cached.connected) {
      _deviceMap[addr] = cached.copyWith(discovered: true);
      _discoveredAddresses.add(addr);
      _emitDevices();
      return;
    }
    _deviceMap.remove(addr);
    _scanSession.remove(addr);
    _discoveredAddresses.remove(addr);
    _emitDevices();
  }

  void _clearScanSession() {
    for (final addr in _scanSession.keys.toList(growable: false)) {
      final d = _deviceMap[addr];
      if (d != null && !d.paired && !d.trusted && !d.connected) {
        _deviceMap.remove(addr);
      }
      _discoveredAddresses.remove(addr);
    }
    _scanSession.clear();
  }

  void _rebuildDeviceMap({bool markAllDiscovered = false}) {
    final bonded = <String, BluetoothRemoteDevice>{};
    for (final d in _client.devices) {
      final addr = BluetoothctlParse.normalizeAddress(d.address);
      final mapped = _mapDevice(d, discovered: false);
      if (mapped.paired || mapped.trusted || mapped.connected) {
        bonded[addr] = mapped;
      }
    }
    _deviceMap
      ..clear()
      ..addAll(bonded);
    if (!markAllDiscovered) {
      // Keep scan-session overlays when refreshing mid-scan.
      for (final e in _scanSession.entries) {
        _deviceMap.putIfAbsent(e.key, () => e.value);
      }
    }
    _emitDevices();
  }

  void _refreshAdapterInfo() {
    final a = _adapter;
    if (a == null) {
      _emitInfo(const BluetoothAdapterInfo());
      return;
    }
    _emitInfo(
      BluetoothAdapterInfo(
        address: BluetoothctlParse.normalizeAddress(a.address),
        name: a.alias.isNotEmpty ? a.alias : a.name,
        powered: a.powered,
        discoverable: a.discoverable,
        pairable: a.pairable,
      ),
    );
  }

  void _wireDeviceProps(BlueZDevice d) {
    final addr = BluetoothctlParse.normalizeAddress(d.address);
    if (_devicePropWired.contains(addr)) {
      return;
    }
    _devicePropWired.add(addr);
    _lastConnectedByAddr[addr] = d.connected;
    _subs.add(d.propertiesChanged.listen((_) {
      final wasConnected = _lastConnectedByAddr[addr] ?? false;
      _upsertDevice(d, markDiscovered: _scanning);
      final nowConnected = d.connected;
      _lastConnectedByAddr[addr] = nowConnected;

      final mapped = _deviceMap[addr];
      if (mapped == null || !_isHidLikeRemote(mapped)) {
        return;
      }
      if (!nowConnected && wasConnected) {
        _setHidInputReady(addr, false);
        return;
      }
      if (nowConnected) {
        // Paired+Connected but Trusted=no (peer LE link after Untrust, or
        // incomplete Connect). Fill Trust unless user sticky-Disconnected.
        unawaited(_serialized(() async {
          if (_stickyUntrustAddrs.contains(addr)) {
            await _refreshHidInputStatus(addr);
            return;
          }
          await _ensureTrustedWhenLinked(addr);
          final live = _findLiveDevice(addr);
          if (live == null || !live.connected) {
            return;
          }
          if (!wasConnected || live.trusted) {
            await _ensureHidInput(addr);
          } else {
            await _refreshHidInputStatus(addr);
          }
        }));
      }
    }));
  }

  void _setHidInputReady(String addr, bool? ready) {
    if (ready == null) {
      _hidInputReadyByAddr.remove(addr);
    } else {
      _hidInputReadyByAddr[addr] = ready;
    }
    final d = _deviceMap[addr];
    if (d == null || !_isHidLikeRemote(d)) {
      return;
    }
    if (d.inputReady != ready) {
      _deviceMap[addr] = d.copyWith(
        inputReady: ready,
        clearInputReady: ready == null,
      );
      _emitDevices();
    }
  }

  /// Keyboard battery keepalive only. HID inputReady is refreshed on
  /// Connected edge / PropertiesChanged / Pair-Connect — not on a timer.
  void _startHidStatusWatch() {
    _batteryKeepalive.start(_refreshKeyboardBatteries);
  }

  void _stopHidStatusWatch() {
    _batteryKeepalive.stop();
  }

  /// Poll BlueZ Battery1 for connected keyboards (keepalive + UI %).
  Future<void> _refreshKeyboardBatteries() async {
    if (_state != BluetoothAdapterState.on || !_clientConnected) {
      return;
    }
    var changed = false;
    for (final live in _client.devices) {
      final addr = BluetoothctlParse.normalizeAddress(live.address);
      final mapped = _deviceMap[addr];
      if (mapped == null || mapped.kind != BluetoothDeviceKind.keyboard) {
        continue;
      }
      if (!mapped.connected && !live.connected) {
        continue;
      }
      final pct = await _batteryKeepalive.readPercent(live.path.value);
      if (pct == null) {
        continue;
      }
      if (mapped.batteryPercent != pct) {
        _deviceMap[addr] = mapped.copyWith(batteryPercent: pct);
        changed = true;
      }
    }
    if (changed) {
      _emitDevices();
    }
  }

  Future<void> _refreshAllHidInputStatus() async {
    if (_state != BluetoothAdapterState.on) {
      return;
    }
    for (final d in _deviceMap.values.toList(growable: false)) {
      if (!_isHidLikeRemote(d)) {
        continue;
      }
      await _refreshHidInputStatus(d.address);
    }
  }

  Future<void> _refreshHidInputStatus(String address) async {
    final addr = BluetoothctlParse.normalizeAddress(address);
    final mapped = _deviceMap[addr];
    if (mapped == null || !_isHidLikeRemote(mapped)) {
      return;
    }
    // Stale uhid nodes often survive BlueZ Disconnect (QM002). Never report
    // inputReady while the link is down.
    if (!mapped.connected) {
      _setHidInputReady(addr, false);
      return;
    }
    final hasEvdev = await _hidEvdevPresent(addr);
    _setHidInputReady(addr, hasEvdev);
  }

  bool _isHidLikeRemote(BluetoothRemoteDevice d) {
    if (d.kind == BluetoothDeviceKind.keyboard ||
        d.kind == BluetoothDeviceKind.mouse) {
      return true;
    }
    for (final u in d.uuids) {
      final lower = u.toLowerCase();
      if (lower.contains('00001812-') || lower.contains('00001124-')) {
        return true;
      }
    }
    final name = d.name.toLowerCase();
    return name.contains('keyboard') ||
        name.contains('mouse') ||
        name.contains('qm002');
  }

  bool _ensureShouldAbort(int epoch) {
    return _pairAbort || epoch != _hidEnsureEpoch;
  }

  bool _isPairCancelledError(Object e) {
    if (e is BluetoothOperationException &&
        e.message.toLowerCase().contains('pairing cancelled')) {
      return true;
    }
    return e.toString().toLowerCase().contains('pairing cancelled');
  }

  /// Attach HOGP/HID input when BlueZ link is already up (Policy or user Connect).
  ///
  /// Sticky LE "Connected but ServicesResolved=no / no evdev" needs a brief
  /// Untrust→Disconnect→Trust→Connect cycle (Policy will not drop Trusted
  /// Connected otherwise). Same Untrust/Trust pairing as user Disconnect/Connect.
  Future<void> _ensureHidInput(String address) async {
    final addr = BluetoothctlParse.normalizeAddress(address);
    if (_hidEnsureInFlight) {
      return;
    }
    if (_stickyUntrustAddrs.contains(addr)) {
      stderr.writeln('bt: HID ensure skip (sticky untrust) $addr');
      return;
    }
    final mapped = _deviceMap[addr];
    if (mapped != null && !_isHidLikeRemote(mapped)) {
      return;
    }

    final epoch = _hidEnsureEpoch;
    _hidEnsureInFlight = true;
    try {
      stderr.writeln('bt: HID ensure input $addr');
      await _ensureTrustedWhenLinked(addr);
      final live0 = _findLiveDevice(addr);
      if (live0 == null) {
        return;
      }
      if (!_isHidLikeRemote(
        mapped ??
            BluetoothRemoteDevice(
              address: addr,
              name: live0.name,
              paired: live0.paired,
              trusted: live0.trusted,
              connected: live0.connected,
              uuids: live0.uuids.map((u) => u.toString()).toList(),
            ),
      )) {
        return;
      }

      Future<bool> waitEvdev(Duration d) async {
        final deadline = DateTime.now().add(d);
        while (DateTime.now().isBefore(deadline)) {
          if (_ensureShouldAbort(epoch)) {
            return false;
          }
          if (await _hidEvdevPresent(addr)) {
            return true;
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        return _hidEvdevPresent(addr);
      }

      Future<void> tryConnectProfiles() async {
        final live = _findLiveDevice(addr);
        if (live == null) {
          return;
        }
        final uuidBlob =
            live.uuids.map((u) => u.toString().toLowerCase()).join(' ');
        final hasHogp = uuidBlob.contains('1812');
        final hasClassic = uuidBlob.contains('1124');
        if (hasHogp) {
          stderr.writeln('bt: HID ensure ConnectProfile HOGP $addr');
          try {
            await live.connectProfile(_hogpUuid);
          } catch (e) {
            stderr.writeln('bt: ConnectProfile HOGP soft-fail: $e');
          }
        }
        if (hasClassic) {
          stderr.writeln('bt: HID ensure ConnectProfile Classic HID $addr');
          try {
            await live.connectProfile(_classicHidUuid);
          } catch (e) {
            stderr.writeln('bt: ConnectProfile HID soft-fail: $e');
          }
        }
      }

      /// Force a real ATT teardown against Policy sticky-Connected.
      Future<void> refreshGattLink() async {
        stderr.writeln(
          'bt: HID ensure GATT refresh Untrust/Disconnect/Trust/Connect $addr',
        );
        await _untrust(addr);
        try {
          await _disconnectDevice(addr);
        } catch (e) {
          stderr.writeln('bt: HID refresh Disconnect soft-fail: $e');
        }
        for (var i = 0; i < 20; i++) {
          if (_ensureShouldAbort(epoch)) {
            return;
          }
          if (!_infoFlagYes(_deviceInfoMapFor(addr), 'connected')) {
            break;
          }
          try {
            await _disconnectDevice(addr);
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (_ensureShouldAbort(epoch)) {
          return;
        }
        await _setTrusted(addr, true);
        try {
          await _connectAndWait(addr, ensureDiscovery: false);
        } catch (e) {
          if (_isPairCancelledError(e)) {
            rethrow;
          }
          stderr.writeln('bt: HID refresh Connect soft-fail: $e');
        }
      }

      if (_ensureShouldAbort(epoch)) {
        stderr.writeln('bt: HID ensure aborted $addr');
        return;
      }

      var info = _deviceInfoMapFor(addr);
      if (!_infoFlagYes(info, 'connected')) {
        stderr.writeln(
          'bt: HID ensure skip (link down; Policy/Connect owns) $addr',
        );
        _setHidInputReady(addr, false);
        return;
      }
      if (await _hidEvdevPresent(addr)) {
        _setHidInputReady(addr, true);
        return;
      }

      if (!_infoFlagYes(info, 'servicesresolved')) {
        stderr.writeln(
          'bt: HID ensure GATT grace ${_gattGrace.inSeconds}s $addr',
        );
        final deadline = DateTime.now().add(_gattGrace);
        while (DateTime.now().isBefore(deadline)) {
          if (_ensureShouldAbort(epoch)) {
            stderr.writeln('bt: HID ensure aborted during grace $addr');
            return;
          }
          if (await _hidEvdevPresent(addr)) {
            _setHidInputReady(addr, true);
            return;
          }
          info = _deviceInfoMapFor(addr);
          if (_infoFlagYes(info, 'servicesresolved')) {
            break;
          }
          if (!_infoFlagYes(info, 'connected')) {
            stderr.writeln('bt: HID ensure link dropped during grace $addr');
            _setHidInputReady(addr, false);
            return;
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        info = _deviceInfoMapFor(addr);
      }

      if (_ensureShouldAbort(epoch)) {
        return;
      }

      if (_infoFlagYes(info, 'connected') &&
          _infoFlagYes(info, 'servicesresolved')) {
        if (await waitEvdev(_hogSettle)) {
          _setHidInputReady(addr, true);
          return;
        }
      }

      if (_ensureShouldAbort(epoch)) {
        return;
      }

      if (await _hidEvdevPresent(addr)) {
        _setHidInputReady(addr, true);
        return;
      }

      // Soft profile nudge (works when GATT already resolved; fails on zombie).
      info = _deviceInfoMapFor(addr);
      if (_infoFlagYes(info, 'connected')) {
        await tryConnectProfiles();
        if (_ensureShouldAbort(epoch)) {
          return;
        }
        if (await waitEvdev(const Duration(seconds: 5))) {
          _setHidInputReady(addr, true);
          return;
        }
      }

      // Zombie LE: Connected + no SR / no evdev — Untrust so Disconnect sticks.
      info = _deviceInfoMapFor(addr);
      if (_infoFlagYes(info, 'connected') && !await _hidEvdevPresent(addr)) {
        await refreshGattLink();
        if (_ensureShouldAbort(epoch)) {
          return;
        }
        info = _deviceInfoMapFor(addr);
        if (_infoFlagYes(info, 'connected')) {
          if (_infoFlagYes(info, 'servicesresolved')) {
            if (await waitEvdev(_hogSettle)) {
              _setHidInputReady(addr, true);
              return;
            }
          }
          await tryConnectProfiles();
          if (_ensureShouldAbort(epoch)) {
            return;
          }
          if (await waitEvdev(const Duration(seconds: 5))) {
            _setHidInputReady(addr, true);
            return;
          }
        }
      }

      if (_ensureShouldAbort(epoch)) {
        return;
      }
      final ok = await _hidEvdevPresent(addr);
      _setHidInputReady(
        addr,
        ok && _infoFlagYes(_deviceInfoMapFor(addr), 'connected'),
      );
      if (!ok) {
        stderr.writeln('bt: HID ensure still no evdev $addr');
      }
    } on BluetoothOperationException catch (e) {
      if (_isPairCancelledError(e)) {
        rethrow;
      }
      stderr.writeln('bt: HID ensure soft-fail: $e');
    } catch (e) {
      if (_isPairCancelledError(e)) {
        rethrow;
      }
      stderr.writeln('bt: HID ensure soft-fail: $e');
    } finally {
      _hidEnsureInFlight = false;
      if (!_ensureShouldAbort(epoch)) {
        await _refreshHidInputStatus(addr);
      }
    }
  }

  Future<void> _cancelClientSubs() async {
    for (final s in _subs) {
      try {
        await s.cancel();
      } catch (_) {}
    }
    _subs.clear();
    _clientListenersWired = false;
    _devicePropWired.clear();
    _adapterPropWired.clear();
  }

  /// Drop a stale BlueZ D-Bus session after bluetoothd dies/restarts.
  Future<void> _resetBluezClient() async {
    await _cancelClientSubs();
    _agentRegistered = false;
    _agent = null;
    if (!_ownedClient) {
      _clientConnected = false;
      return;
    }
    if (_clientConnected) {
      try {
        await _client.close();
      } catch (e) {
        debugPrint('bt: client close: $e');
      }
    }
    _client = BlueZClient();
    _clientConnected = false;
  }

  Future<void> _ensureClient() async {
    if (!_clientConnected) {
      await _client.connect();
      _clientConnected = true;
    }
    if (_clientListenersWired) {
      return;
    }
    _clientListenersWired = true;
    _subs.add(_client.deviceAdded.listen((d) {
      _upsertDevice(d, markDiscovered: _scanning);
      _wireDeviceProps(d);
    }));
    _subs.add(_client.deviceRemoved.listen((d) {
      _removeDeviceAddress(d.address);
    }));
    _subs.add(_client.adapterAdded.listen((adapter) {
      _wireAdapter(adapter);
      _refreshAdapterInfo();
    }));
    _subs.add(_client.adapterRemoved.listen((_) {
      _refreshAdapterInfo();
      unawaited(_maybeRecoverDeadDaemon());
    }));
    final a = _adapter;
    if (a != null) {
      _wireAdapter(a);
    }
    for (final d in _client.devices) {
      _wireDeviceProps(d);
    }
  }

  /// bluetoothd ABRT leaves org.bluez gone; D-Bus activation used to fail without
  /// dbus-org.bluez.service. Re-attach after systemd brings the daemon back.
  Future<void> _maybeRecoverDeadDaemon() async {
    if (_suppressDaemonRecover || _autoRecoverInFlight) {
      return;
    }
    if (_state != BluetoothAdapterState.on &&
        _state != BluetoothAdapterState.starting) {
      return;
    }
    await _serialized(() async {
      if (_suppressDaemonRecover || _autoRecoverInFlight) {
        return;
      }
      if (_state != BluetoothAdapterState.on &&
          _state != BluetoothAdapterState.starting) {
        return;
      }
      _autoRecoverInFlight = true;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final serviceUp = await _bluetoothServiceActive();
        if (serviceUp && _adapter != null && _adapter!.powered) {
          return;
        }
        _lastError = 'bluetoothd restarted — recovering';
        debugPrint('bt: $_lastError');
        _emitState(BluetoothAdapterState.starting);
        await _resetBluezClient();
        if (!serviceUp) {
          try {
            await _btStack.startStack();
          } catch (_) {
            _lastError = 'bluetoothd recovery failed';
            _emitState(BluetoothAdapterState.error);
            return;
          }
        }
        // Daemon may have auto-restarted (Restart=on-abnormal); wait for HCI.
        for (var i = 0; i < 20; i++) {
          await _ensureClient();
          if (_adapter != null) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await _resetBluezClient();
        }
        await _attachBluezSession();
        _lastError = null;
        _emitState(BluetoothAdapterState.on);
        _refreshAdapterInfo();
      } catch (e) {
        _lastError = 'bluetoothd recovery failed: $e';
        debugPrint('bt: $_lastError');
        _emitState(BluetoothAdapterState.error);
      } finally {
        _autoRecoverInFlight = false;
      }
    });
  }

  void _wireAdapter(BlueZAdapter? adapter) {
    if (adapter == null) {
      return;
    }
    final key = adapter.address;
    if (_adapterPropWired.contains(key)) {
      return;
    }
    _adapterPropWired.add(key);
    _subs.add(adapter.propertiesChanged.listen((props) {
      _refreshAdapterInfo();
      if (props.contains('Discovering')) {
        if (!adapter.discovering && _scanning) {
          _emitScanning(false);
        }
      }
      if (props.contains('Powered') && !adapter.powered) {
        if (_state == BluetoothAdapterState.on) {
          _emitState(BluetoothAdapterState.off);
        }
      }
    }));
  }

  bool _autoConfirmPolicy() {
    // After the user Accepts the Demo consent sheet, BlueZ SMP prompts
    // (RequestConfirmation / JustWorks) must not block again.
    if (_outboundPairActive && _outboundUserConsented) {
      return true;
    }
    // Incoming phone/PC while Pairable: keep headless auto-yes.
    if (!_outboundPairActive && _info.pairable) {
      return true;
    }
    return false;
  }

  Future<bool> _awaitOutboundPairConsent({
    required String address,
    required String name,
  }) async {
    final id =
        'consent-$address-${DateTime.now().microsecondsSinceEpoch}';
    _consentChallengeId = id;
    _consentWait = Completer<bool>();
    _emitChallenge(
      BluetoothPairingChallenge(
        id: id,
        address: address,
        name: name,
        kind: BluetoothPairingChallengeKind.requestAuthorization,
      ),
    );
    try {
      return await _consentWait!.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => false,
      );
    } finally {
      _consentChallengeId = null;
      _consentWait = null;
      if (_challenge?.id == id) {
        _emitChallenge(null);
      }
    }
  }

  Future<void> _registerHmiAgent() async {
    try {
      await _btStack.stopAgent();
    } catch (_) {}
    await _writeHmiAgentMarker(true);
    _agent = HmiBluezAgent(
      shouldAutoConfirm: _autoConfirmPolicy,
      onChallenge: _emitChallenge,
    );
    try {
      if (_agentRegistered) {
        try {
          await _client.unregisterAgent();
        } catch (_) {}
        _agentRegistered = false;
      }
      // Avoid /org/bluez/* paths (owned by bluetoothd namespace). Unique path
      // also sidesteps stale D-Bus object registration after re-register.
      _agentPathSeq++;
      final agentPath = DBusObjectPath('/com/lws/hmi/bluez_agent/$_agentPathSeq');
      await _client.registerAgent(
        _agent!,
        path: agentPath,
        capability: BlueZAgentCapability.displayYesNo,
      );
      await _client.requestDefaultAgent();
      _agentRegistered = true;
      stderr.writeln(
        'bt: Agent1 registered at $agentPath (DisplayYesNo, default)',
      );
    } catch (e) {
      debugPrint('bt: registerAgent failed: $e');
      stderr.writeln('bt: registerAgent failed: $e');
      await _writeHmiAgentMarker(false);
      try {
        await _btStack.ensureAgent();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _unregisterHmiAgent({bool restoreShellAgent = false}) async {
    try {
      if (_agentRegistered && await _bluetoothServiceActive()) {
        await _client.unregisterAgent();
        _agentRegistered = false;
      }
    } catch (e) {
      debugPrint('bt: unregisterAgent: $e');
    }
    _agentRegistered = false;
    _agent = null;
    _emitChallenge(null);
    await _writeHmiAgentMarker(false);
    if (restoreShellAgent) {
      try {
        await _btStack.ensureAgent();
      } catch (_) {}
    }
  }

  Future<void> _refreshA2dp() async {
    if (_state != BluetoothAdapterState.on) {
      await _loadA2dpPref();
      return;
    }
    _emitA2dp(await _bluealsaActive());
  }

  Future<void> _attachBluezSession() async {
    await _ensureClient();
    _refreshAdapterInfo();
    _rebuildDeviceMap();
    try {
      await _btStack.setAlias();
    } catch (_) {}
    await _registerHmiAgent();
    await _refreshA2dp();
    _startHidStatusWatch();
    unawaited(_refreshAllHidInputStatus());
    unawaited(_serialized(_reconcilePairedConnectedTrust));
  }

  @override
  Future<void> setAdapterEnabled(bool enabled) => _serialized(() async {
        _stopWantedWatch();
        if (enabled) {
          _emitState(BluetoothAdapterState.starting);
          // Claim Agent1 before stack-up so bt-ensure-agent skips the shell agent.
          await _writeHmiAgentMarker(true);
          // Drop any stale D-Bus session left after a bluetoothd core-dump.
          await _resetBluezClient();
          try {
            await _btStack.startStack();
          } catch (e) {
            await _writeHmiAgentMarker(false);
            _lastError = '$e';
            debugPrint('bt: $_lastError');
            _emitState(BluetoothAdapterState.error);
            return;
          }
          _lastError = null;
          await _writeWanted(true);
          try {
            await _attachBluezSession();
            _emitState(BluetoothAdapterState.on);
            _refreshAdapterInfo();
          } catch (e) {
            _lastError = '$e';
            await _writeHmiAgentMarker(false);
            try {
              await _btStack.ensureAgent();
            } catch (_) {}
            _emitState(BluetoothAdapterState.error);
          }
        } else {
          _suppressDaemonRecover = true;
          try {
            // If bluetoothd already crashed, skip D-Bus (activation used to hang /
            // fail on missing dbus-org.bluez.service) and just tear the stack down.
            final serviceUp = await _bluetoothServiceActive();
            if (serviceUp) {
              await _stopScanLocked();
              await _unregisterHmiAgent();
            } else {
              _scanTimeout?.cancel();
              _scanTimeout = null;
              if (_scanning) {
                _emitScanning(false);
              }
              _agentRegistered = false;
              _agent = null;
              _emitChallenge(null);
              await _writeHmiAgentMarker(false);
            }
            _lastError = null;
            try {
              await _btStack.stopStack();
            } catch (_) {}
            await _resetBluezClient();
            await _writeWanted(false);
            _stopHidStatusWatch();
            _clearScanSession();
            _deviceMap.clear();
            _discoveredAddresses.clear();
            _hidInputReadyByAddr.clear();
            _lastConnectedByAddr.clear();
            _emitDevices();
            _emitState(BluetoothAdapterState.off);
            _emitInfo(const BluetoothAdapterInfo());
            await _loadA2dpPref();
          } finally {
            _suppressDaemonRecover = false;
          }
        }
      });

  void _stopWantedWatch() {
    _wantedWatch?.cancel();
    _wantedWatch = null;
    _wantedTicks = 0;
  }

  void _startWantedWatch() {
    _stopWantedWatch();
    _wantedWatch = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tickWantedWatch());
    });
  }

  Future<void> _tickWantedWatch() async {
    _wantedTicks++;
    try {
      final serviceUp = await _bluetoothServiceActive();
      if (serviceUp) {
        await _ensureClient();
        final a = _adapter;
        if (a != null && a.powered) {
          _stopWantedWatch();
          _lastError = null;
          await _attachBluezSession();
          _emitState(BluetoothAdapterState.on);
          return;
        }
      }
      if (_wantedTicks >= _wantedWatchMaxTicks) {
        _stopWantedWatch();
        await setAdapterEnabled(true);
      }
    } catch (e) {
      debugPrint('bt: wanted watch: $e');
    }
  }

  @override
  Future<void> syncFromSystem() async {
    try {
      final serviceUp = await _bluetoothServiceActive();
      final wanted = await File(btWantedPath).exists();
      final a2dpPref = await File(a2dpPrefPath).exists()
          ? (await File(a2dpPrefPath).readAsString()).trim()
          : '';
      final a2dpWanted = a2dpPref == '1' ||
          a2dpPref.toLowerCase() == 'on' ||
          a2dpPref.toLowerCase() == 'true';

      if (serviceUp) {
        await _ensureClient();
        final a = _adapter;
        if (a != null && a.powered) {
          _stopWantedWatch();
          _lastError = null;
          await _attachBluezSession();
          _emitState(BluetoothAdapterState.on);
          return;
        }
      }

      if (wanted || a2dpWanted) {
        // HAL-owned restore: start stack (no overlay restore-settings).
        await _loadA2dpPref();
        await setAdapterEnabled(true);
        if (a2dpWanted && !_a2dpSinkEnabled) {
          try {
            await setA2dpSinkEnabled(true);
          } catch (e) {
            debugPrint('bt: a2dp restore soft-fail: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('bt: syncFromSystem failed: $e');
    }
  }

  Future<void> _stopScanLocked() async {
    _scanTimeout?.cancel();
    _scanTimeout = null;
    if (!await _bluetoothServiceActive()) {
      if (_scanning) {
        _emitScanning(false);
      }
      return;
    }
    final a = _adapter;
    if (a != null && a.discovering) {
      try {
        await a.stopDiscovery();
      } catch (e) {
        lwsTrace('bt: stopDiscovery: $e');
      }
    }
    if (_scanning) {
      _emitScanning(false);
    }
  }

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _serialized(() async {
        if (_state != BluetoothAdapterState.on) {
          throw BluetoothOperationException('Bluetooth adapter is not on');
        }
        if (!await _bluetoothServiceActive()) {
          throw BluetoothOperationException(
            'bluetoothd is not running — toggle Bluetooth off/on',
          );
        }
        final a = _adapter;
        if (a == null) {
          throw BluetoothOperationException('No Bluetooth adapter');
        }
        if (_scanning) {
          return;
        }
        try {
          _clearScanSession();
          _rebuildDeviceMap(markAllDiscovered: true);
          try {
            // Soft filter only — UI applies Settings-style candidate filtering.
            // Avoid aggressive RSSI filters that churn Device1 add/remove on BlueZ.
            await a.setDiscoveryFilter(
              duplicateData: false,
              transport: 'auto',
            );
          } catch (e) {
            lwsTrace('bt: setDiscoveryFilter: $e');
          }
          await a.startDiscovery();
          _emitScanning(true);
          _scanTimeout?.cancel();
          _scanTimeout = Timer(timeout, () {
            unawaited(_serialized(_stopScanLocked));
          });
        } catch (e) {
          _emitScanning(false);
          final msg = '$e';
          if (msg.contains('NoSuchUnit') ||
              msg.contains('org.bluez') ||
              msg.contains('NotReady')) {
            unawaited(_maybeRecoverDeadDaemon());
          }
          throw BluetoothOperationException('Scan failed: $e');
        }
      });

  @override
  Future<void> stopScan() => _serialized(_stopScanLocked);

  BlueZDevice? _findLiveDevice(String addr) {
    for (final d in _client.devices) {
      if (BluetoothctlParse.normalizeAddress(d.address) == addr) {
        return d;
      }
    }
    return null;
  }

  Future<void> _ensureDiscoveryRunning() async {
    final a = _adapter;
    if (a == null) {
      return;
    }
    if (a.discovering) {
      return;
    }
    try {
      await a.setDiscoveryFilter(duplicateData: false, transport: 'auto');
    } catch (_) {}
    await a.startDiscovery();
    _emitScanning(true);
    stderr.writeln('bt: discovery started (keep LE Device1 alive)');
  }

  /// Scan/refresh until Device1 appears in [BlueZClient] (not shell info).
  /// Bonded reconnect: if Device1 is already cached, do **not** start discovery.
  Future<BlueZDevice> _waitUntilDevicePresent(
    String addr, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    var live = _findLiveDevice(addr);
    if (live != null) {
      return live;
    }
    stderr.writeln(
      'bt: $addr not in BlueZ yet — scanning until Device1 appears',
    );
    await _ensureDiscoveryRunning();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      _throwIfPairAbort(addr);
      await _ensureDiscoveryRunning();
      live = _findLiveDevice(addr);
      if (live != null) {
        stderr.writeln('bt: BlueZ sees $addr');
        return live;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw BluetoothOperationException(
      'Keyboard left BlueZ cache. Put it in pairing mode, tap Scan, then Pair within a few seconds.',
      address: addr,
    );
  }

  /// Helper map shape for call sites (paired/connected/trusted/uuids/…).
  Map<String, String> _deviceInfoMap(BlueZDevice d) {
    final addrType =
        d.addressType == BlueZAddressType.random ? 'random' : 'public';
    final uuidBlob = d.uuids.map((u) => u.toString()).join(' ');
    return {
      'address': BluetoothctlParse.normalizeAddress(d.address),
      'name': d.name,
      'alias': d.alias,
      'paired': d.paired ? 'yes' : 'no',
      'bonded': d.paired ? 'yes' : 'no',
      'connected': d.connected ? 'yes' : 'no',
      'trusted': d.trusted ? 'yes' : 'no',
      'addresstype': addrType,
      'uuids': uuidBlob,
      'uuid': uuidBlob,
      'servicesresolved': d.servicesResolved ? 'yes' : 'no',
    };
  }

  Map<String, String> _deviceInfoMapFor(String addr) {
    final d = _findLiveDevice(addr);
    if (d == null) {
      return const {};
    }
    return _deviceInfoMap(d);
  }

  bool _infoFlagYes(Map<String, String> info, String key) {
    return (info[key] ?? '').toLowerCase().startsWith('yes');
  }

  bool _infoBondedOrPaired(Map<String, String> info) {
    return _infoFlagYes(info, 'paired') || _infoFlagYes(info, 'bonded');
  }

  Future<void> _pairAndWait(
    String addr, {
    Duration timeout = const Duration(seconds: 40),
  }) async {
    _throwIfPairAbort(addr);
    await _ensureDiscoveryRunning();
    stderr.writeln('bt: Device1.Pair $addr');
    try {
      await _ops.pair(addr);
    } catch (e) {
      // Already paired / in-progress — still poll Paired below.
      stderr.writeln('bt: Pair soft-fail: $e');
    }
    _throwIfPairAbort(addr);

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      _throwIfPairAbort(addr);
      if (_findLiveDevice(addr) == null) {
        await _ensureDiscoveryRunning();
      }
      final info = _deviceInfoMapFor(addr);
      if (_infoBondedOrPaired(info)) {
        stderr.writeln('bt: bonded/paired=yes after Pair for $addr');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final info = _deviceInfoMapFor(addr);
    throw BluetoothOperationException(
      'Pair: still paired=${info['paired'] ?? "?"} '
      'connected=${info['connected'] ?? "?"}',
      address: addr,
    );
  }

  Future<void> _setTrusted(String addr, bool trusted) async {
    stderr.writeln('bt: Device1.Trusted=$trusted $addr');
    try {
      await _ops.setTrusted(addr, trusted);
    } catch (e) {
      stderr.writeln('bt: setTrusted soft-fail: $e');
    }
    for (var i = 0; i < 10; i++) {
      final info = _deviceInfoMapFor(addr);
      if (_infoFlagYes(info, 'trusted') == trusted) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Clear Trusted before RemoveDevice so LE inbound does not recreate the bond.
  Future<void> _untrust(String addr) => _setTrusted(addr, false);

  /// If already bonded and link is up, restore Trusted (Policy + authorize).
  /// Skipped while [addr] is in sticky-untrust after user Disconnect.
  Future<void> _ensureTrustedWhenLinked(String addr) async {
    if (_stickyUntrustAddrs.contains(addr)) {
      return;
    }
    final live = _findLiveDevice(addr);
    if (live == null || !live.connected || !live.paired || live.trusted) {
      return;
    }
    stderr.writeln('bt: auto-Trust paired+connected $addr');
    await _setTrusted(addr, true);
    final after = _findLiveDevice(addr);
    if (after != null) {
      _upsertDevice(after);
    }
  }

  /// One-shot after BlueZ session attach: heal Trust/input on orphan links.
  Future<void> _reconcilePairedConnectedTrust() async {
    for (final live in _client.devices.toList(growable: false)) {
      final addr = BluetoothctlParse.normalizeAddress(live.address);
      if (!live.connected || !live.paired) {
        continue;
      }
      final mapped = _deviceMap[addr] ?? _mapDevice(live);
      if (!_isHidLikeRemote(mapped)) {
        continue;
      }
      await _ensureTrustedWhenLinked(addr);
      if (_findLiveDevice(addr)?.connected ?? false) {
        await _ensureHidInput(addr);
      }
    }
  }

  /// Remove a Device1 that still has properties but lost Connect/Disconnect
  /// (seen after bluetoothd ABRT / heap corruption on AIC).
  Future<void> _forceRemoveCorruptDevice(String addr) async {
    try {
      await _ops.remove(addr);
    } catch (e) {
      stderr.writeln('bt: RemoveDevice soft-fail: $e');
    }
    _removeDeviceAddress(addr);
  }

  /// True when a Bluetooth (uhid) HID node for [addr] exists — never USB mice.
  ///
  /// Pure Dart sysfs walk (no `sh -c`). Shell probes under flutter-pi often
  /// reported `bt_hid:none` while root saw the same `event*` uniq match.
  Future<bool> _hidEvdevPresent(String addr) async {
    final want = addr.toLowerCase();
    final hits = <String>[];
    try {
      final root = Directory('/sys/class/input');
      if (!await root.exists()) {
        stderr.writeln('bt: input probe bt_hid:none (no /sys/class/input)');
        return false;
      }
      await for (final entity in root.list(followLinks: false)) {
        final base = entity.path.split('/').last;
        if (!base.startsWith('event')) {
          continue;
        }
        final deviceDir = Directory('${entity.path}/device');
        final uniqFile = File('${deviceDir.path}/uniq');
        final nameFile = File('${deviceDir.path}/name');
        var uniq = '';
        if (await uniqFile.exists()) {
          uniq = (await uniqFile.readAsString()).trim().toLowerCase();
        }
        var name = '';
        if (await nameFile.exists()) {
          name = (await nameFile.readAsString()).trim();
        }
        if (uniq.isNotEmpty && uniq == want) {
          hits.add('$base:$name');
          continue;
        }
        // Fallback: uhid path + keyboard-like name (uniq sometimes empty briefly).
        try {
          final real = await File(deviceDir.path).resolveSymbolicLinks();
          if (real.contains('uhid')) {
            final lower = name.toLowerCase();
            if (lower.contains('keyboard') || lower.contains('qm002')) {
              hits.add('$base:$name');
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      stderr.writeln('bt: input probe failed: $e');
      return false;
    }
    if (hits.isEmpty) {
      stderr.writeln('bt: input probe bt_hid:none');
      return false;
    }
    stderr.writeln('bt: input probe bt_hid: ${hits.join(' ')}');
    return true;
  }

  /// Upstream BlueZ empty-arg Connect.
  Future<void> _connectDevice(String addr) async {
    await _ops.connect(addr);
  }

  /// Upstream BlueZ empty-arg Disconnect.
  Future<void> _disconnectDevice(String addr) async {
    await _ops.disconnect(addr);
  }

  bool _isTransientBluezConnectError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('inprogress') ||
        s.contains('already in progress') ||
        s.contains('reconnection-profile-unavailable') ||
        s.contains('br-connection-profile-unavailable') ||
        s.contains('profile unavailable') ||
        s.contains('org.bluez.error.inprogress');
  }

  /// Host Connect; wait until Connected.
  ///
  /// [ensureDiscovery]: fresh Pair / missing Device1 only. Bonded reconnect
  /// should leave discovery off to avoid InProgress races with Connect.
  Future<void> _connectAndWait(
    String addr, {
    Duration timeout = const Duration(seconds: 25),
    bool ensureDiscovery = true,
  }) async {
    _throwIfPairAbort(addr);
    if (ensureDiscovery) {
      await _ensureDiscoveryRunning();
    }
    final live = _findLiveDevice(addr);
    if (live == null) {
      throw BluetoothOperationException(
        'No BlueZ Device1 for Connect',
        address: addr,
      );
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      _throwIfPairAbort(addr);
      if (_infoFlagYes(_deviceInfoMapFor(addr), 'connected')) {
        stderr.writeln('bt: Connect skip (already connected) $addr');
        return;
      }
      stderr.writeln('bt: Connect $addr (attempt ${attempt + 1})');
      try {
        await _connectDevice(addr);
        break;
      } catch (e) {
        final info = _deviceInfoMapFor(addr);
        if (_infoFlagYes(info, 'connected')) {
          stderr.writeln(
            'bt: Connect error but Connected=yes — treat as ok ($e)',
          );
          return;
        }
        if (_isTransientBluezConnectError(e) && attempt == 0) {
          stderr.writeln('bt: Connect soft-retry after: $e');
          await Future<void>.delayed(const Duration(milliseconds: 800));
          if (_infoFlagYes(_deviceInfoMapFor(addr), 'connected')) {
            return;
          }
          continue;
        }
        throw BluetoothOperationException(
          'Connect failed: $e',
          address: addr,
        );
      }
    }
    _throwIfPairAbort(addr);

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      _throwIfPairAbort(addr);
      final info = _deviceInfoMapFor(addr);
      // Require Connected — stale uhid after Disconnect must not end the wait.
      if (_infoFlagYes(info, 'connected')) {
        stderr.writeln(
          'bt: Connect ok connected=yes services=${info['servicesresolved']}',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final info = _deviceInfoMapFor(addr);
    throw BluetoothOperationException(
      'Connect timed out (connected=${info['connected']}, '
      'services=${info['servicesresolved']}). '
      'Wake the keyboard and tap Connect again.',
      address: addr,
    );
  }

  /// Outbound HID state machine:
  /// 1) Pair if not bonded  2) Trust (Policy auto-reconnect)  3) Connect if down
  /// 4) Ensure HOGP/evdev when Connected but input missing.
  ///
  /// Connect = Trust + Connect. Disconnect = Untrust + Disconnect (sticky).
  /// Policy auto-reconnects only while Trusted (after link loss, not after
  /// user Disconnect). Explicit Connect runs step 2–3 again.
  Future<void> _pairConnectTrust(String addr) async {
    await _waitUntilDevicePresent(addr);

    var info = _deviceInfoMapFor(addr);
    stderr.writeln(
      'bt: before pair/connect info paired=${info['paired']} '
      'bonded=${info['bonded']} connected=${info['connected']} '
      'trusted=${info['trusted']}',
    );

    final alreadyBonded = _infoBondedOrPaired(info);

    // Fresh Pair needs discovery for LE appearance; bonded reconnect does not.
    if (!alreadyBonded) {
      await _ensureDiscoveryRunning();
    }

    // 1) Bond once (fresh pair). Already-bonded reconnect skips this.
    if (!alreadyBonded) {
      await _pairAndWait(addr);
      info = _deviceInfoMapFor(addr);
    }

    // 2) Trusted so BlueZ Policy may auto-reconnect after link loss.
    _stickyUntrustAddrs.remove(addr);
    if (!_infoFlagYes(info, 'trusted')) {
      await _setTrusted(addr, true);
      info = _deviceInfoMapFor(addr);
    }

    // 3) Explicit Connect when link is down (Policy may already have restored it).
    if (!_infoFlagYes(info, 'connected')) {
      await _connectAndWait(addr, ensureDiscovery: !alreadyBonded);
      info = _deviceInfoMapFor(addr);
    }

    // 4) Attach HOGP/evdev when Connected but Linux input is missing.
    if (_infoFlagYes(info, 'connected') && !await _hidEvdevPresent(addr)) {
      await _ensureHidInput(addr);
      info = _deviceInfoMapFor(addr);
    }

    final bonded = _infoBondedOrPaired(info);
    final connected = _infoFlagYes(info, 'connected');
    final hasInput = connected && await _hidEvdevPresent(addr);
    if (!bonded) {
      throw BluetoothOperationException(
        'Still unpaired (paired=${info['paired']} bonded=${info['bonded']}). '
        'Put keyboard in pairing mode, Scan, then Pair.',
        address: addr,
      );
    }
    if (!connected) {
      throw BluetoothOperationException(
        'Connect failed (connected=${info['connected']}, '
        'services=${info['servicesresolved']}). '
        'Wake the keyboard and tap Connect again.',
        address: addr,
      );
    }
    stderr.writeln(
      'bt: pair/connect/trust ok bonded=yes connected=yes input=$hasInput',
    );
  }

  @override
  Future<void> pairAndConnect(String address) async {
    if (_state != BluetoothAdapterState.on) {
      throw BluetoothOperationException('Bluetooth adapter is not on');
    }
    final addr = BluetoothctlParse.normalizeAddress(address);
    _pairAbort = false;

    await _serialized(() async {
      if (!await _bluetoothServiceActive()) {
        throw BluetoothOperationException(
          'bluetoothd is not running — toggle Bluetooth off/on',
        );
      }
      final a = _adapter;
      if (a != null && !a.pairable) {
        await a.setPairable(true);
        _refreshAdapterInfo();
      }
      if (!_agentRegistered) {
        await _registerHmiAgent();
      } else {
        try {
          await _client.requestDefaultAgent();
        } catch (e) {
          debugPrint('bt: requestDefaultAgent: $e');
          await _registerHmiAgent();
        }
      }
      _outboundPairActive = true;
      _outboundUserConsented = false;
    });

    try {
      final cached = _scanSession[addr] ?? _deviceMap[addr];
      final label =
          (cached != null && cached.name.isNotEmpty) ? cached.name : addr;

      // Fresh Pair needs consent; already-bonded reconnect is just Connect.
      // Consent stays outside the op lock so Cancel/Disconnect are not blocked
      // while the dialog is open.
      final prior = _deviceInfoMapFor(addr);
      final alreadyBonded =
          _infoBondedOrPaired(prior) || (cached?.paired ?? false);
      if (alreadyBonded) {
        _outboundUserConsented = true;
        stderr.writeln(
          'bt: reconnect bonded $addr — skip pair consent, Connect path',
        );
      } else {
        final accepted = await _awaitOutboundPairConsent(
          address: addr,
          name: label,
        );
        if (!accepted) {
          throw BluetoothOperationException('Pairing cancelled', address: addr);
        }
        _outboundUserConsented = true;
        stderr.writeln(
          'bt: user accepted pair $addr — Device1 Pair/Connect path',
        );
      }

      _throwIfPairAbort(addr);

      // Connect + UI sync under one lock — no Disconnect/Remove/Scan race.
      await _serialized(() async {
        _throwIfPairAbort(addr);
        await _pairConnectTrust(addr);
        await _stopScanLocked();
        _scanSession.remove(addr);

        final info = _deviceInfoMapFor(addr);
        final live = _findLiveDevice(addr);
        final name = info['name'] ??
            info['alias'] ??
            (live != null && (live.alias.isNotEmpty || live.name.isNotEmpty)
                ? (live.alias.isNotEmpty ? live.alias : live.name)
                : label);
        final paired = _infoBondedOrPaired(info);
        final trusted = _infoFlagYes(info, 'trusted');
        final connected = _infoFlagYes(info, 'connected');
        final kind = cached?.kind ??
            (live != null
                ? inferBluetoothDeviceKind(
                    icon: live.icon,
                    deviceClass: live.deviceClass,
                    uuids: live.uuids.map((u) => u.toString()),
                  )
                : BluetoothDeviceKind.keyboard);
        bool? inputReady;
        if (kind == BluetoothDeviceKind.keyboard ||
            kind == BluetoothDeviceKind.mouse) {
          // Require Connected — stale uhid after Disconnect is not ready.
          inputReady = connected && await _hidEvdevPresent(addr);
          _setHidInputReady(addr, inputReady);
        }
        stderr.writeln(
          'bt: UI sync paired=$paired bonded=${info['bonded']} '
          'trusted=$trusted connected=$connected '
          'services=${info['servicesresolved']} input=$inputReady',
        );
        _deviceMap[addr] = BluetoothRemoteDevice(
          address: addr,
          name: name,
          paired: paired,
          trusted: trusted,
          connected: connected,
          inputReady: inputReady,
          discovered: false,
          kind: kind,
          uuids: cached?.uuids ??
              live?.uuids.map((u) => u.toString()).toList(growable: false) ??
              const [],
          icon: live?.icon ?? cached?.icon ?? '',
        );
        _lastConnectedByAddr[addr] = connected;
        _emitDevices();
        if (live != null) {
          _wireDeviceProps(live);
        }
      });
    } catch (e) {
      if (e is BluetoothOperationException) {
        rethrow;
      }
      throw BluetoothOperationException(
        'Pair/connect failed: $e',
        address: addr,
      );
    } finally {
      _outboundPairActive = false;
      _outboundUserConsented = false;
      _pairAbort = false;
    }
  }

  @override
  Future<void> cancelPairing() async {
    _pairAbort = true;
    _hidEnsureEpoch++;
    final consent = _consentWait;
    if (consent != null && !consent.isCompleted) {
      consent.complete(false);
    }
    try {
      await _agent?.cancel();
    } catch (_) {}
    for (final d in _client.devices.toList(growable: false)) {
      try {
        await d.cancelPairing();
      } catch (_) {}
    }
  }

  @override
  Future<void> setDiscoverable(bool enabled) => _serialized(() async {
        final a = _adapter;
        if (a == null) {
          throw BluetoothOperationException('No Bluetooth adapter');
        }
        try {
          await _btStack.setAlias();
        } catch (_) {}
        if (enabled) {
          await a.setDiscoverableTimeout(180);
        }
        await a.setDiscoverable(enabled);
        _refreshAdapterInfo();
      });

  @override
  Future<void> setPairable(bool enabled) => _serialized(() async {
        final a = _adapter;
        if (a == null) {
          throw BluetoothOperationException('No Bluetooth adapter');
        }
        try {
          await _btStack.setAlias();
        } catch (_) {}
        await a.setPairable(enabled);
        if (enabled) {
          await a.setDiscoverableTimeout(180);
          await a.setDiscoverable(true);
        }
        _refreshAdapterInfo();
      });

  @override
  Future<void> setA2dpSinkEnabled(bool enabled) => _serialized(() async {
        if (enabled) {
          if (_state != BluetoothAdapterState.on) {
            throw StateError('Enable Bluetooth adapter before A2DP Sink');
          }
          await _btStack.startA2dpSink();
          _emitA2dp(true);
        } else {
          try {
            await _btStack.stopA2dpSink();
          } catch (_) {}
          _emitA2dp(false);
        }
      });

  @override
  Future<void> disconnectRemote(String address) => _serialized(() async {
        final addr = BluetoothctlParse.normalizeAddress(address);
        // Sticky Disconnect: Untrust so Policy will not immediately re-attach.
        _hidEnsureEpoch++;
        _stickyUntrustAddrs.add(addr);
        _setHidInputReady(addr, false);

        stderr.writeln('bt: Disconnect $addr (user, Untrust+Disconnect)');
        await _untrust(addr);
        try {
          await _disconnectDevice(addr);
        } catch (e) {
          stderr.writeln('bt: Disconnect soft-fail: $e');
        }

        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (!_infoFlagYes(_deviceInfoMapFor(addr), 'connected')) {
            break;
          }
          stderr.writeln(
            'bt: Disconnect wait (still connected) — Disconnect again $addr',
          );
          try {
            await _disconnectDevice(addr);
          } catch (_) {}
        }

        final afterLive = _findLiveDevice(addr);
        if (afterLive != null) {
          _upsertDevice(afterLive);
          _lastConnectedByAddr[addr] = afterLive.connected;
        } else {
          final prev = _deviceMap[addr];
          if (prev != null) {
            _deviceMap[addr] = prev.copyWith(
              connected: false,
              trusted: false,
            );
            _emitDevices();
          }
          _lastConnectedByAddr[addr] = false;
        }

        final after = _deviceInfoMapFor(addr);
        if (_infoFlagYes(after, 'connected')) {
          stderr.writeln(
            'bt: Disconnect returned with Connected=yes '
            'trusted=${after['trusted']}',
          );
          _setHidInputReady(
            addr,
            await _hidEvdevPresent(addr),
          );
          return;
        }
        _setHidInputReady(addr, false);

        // Quiet window so immediate user Connect does not hit teardown InProgress.
        await Future<void>.delayed(const Duration(milliseconds: 800));
        stderr.writeln(
          'bt: Disconnect done connected=false trusted=${_deviceInfoMapFor(addr)['trusted']}',
        );
      });

  @override
  Future<void> removeRemote(String address) => _serialized(() async {
        final addr = BluetoothctlParse.normalizeAddress(address);
        final a = _adapter;
        if (a == null) {
          throw BluetoothOperationException('No Bluetooth adapter');
        }
        _hidInputReadyByAddr.remove(addr);
        _lastConnectedByAddr.remove(addr);
        _stickyUntrustAddrs.remove(addr);
        _forgettingAddrs.add(addr);
        _hidEnsureEpoch++;

        try {
          // Untrust + Disconnect first so LE inbound does not recreate the object
          // while RemoveDevice runs.
          await _untrust(addr);
          try {
            await _disconnectDevice(addr);
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 400));

          final stillThere = _findLiveDevice(addr);
          if (stillThere != null) {
            try {
              await a.removeDevice(stillThere);
            } catch (e) {
              stderr.writeln('bt: removeDevice: $e');
              await _forceRemoveCorruptDevice(addr);
              return;
            }
            _removeDeviceAddress(addr);
            return;
          }
          // Device1 may be gone from Dart cache but still in bluetoothd.
          await _forceRemoveCorruptDevice(addr);
          _removeDeviceAddress(addr);
        } finally {
          _forgettingAddrs.remove(addr);
        }
      });

  @override
  Future<void> respondToPairingChallenge(
    String challengeId, {
    required bool accept,
    int? passkey,
    String? pinCode,
  }) async {
    final consent = _consentWait;
    if (consent != null &&
        !consent.isCompleted &&
        _consentChallengeId == challengeId) {
      consent.complete(accept);
      return;
    }
    final agent = _agent;
    if (agent == null) {
      throw BluetoothOperationException('No pairing agent');
    }
    await agent.respond(
      challengeId: challengeId,
      accept: accept,
      passkey: passkey,
      pinCode: pinCode,
    );
  }

  @override
  Future<void> dispose() async {
    _stopWantedWatch();
    _stopHidStatusWatch();
    _scanTimeout?.cancel();
    final serviceUp = await _bluetoothServiceActive();
    if (serviceUp) {
      await _stopScanLocked();
      await _unregisterHmiAgent(
        restoreShellAgent: _state == BluetoothAdapterState.on,
      );
    } else {
      _agentRegistered = false;
      _agent = null;
      await _writeHmiAgentMarker(false);
    }
    await _resetBluezClient();
    await _stateCtrl.close();
    await _infoCtrl.close();
    await _devicesCtrl.close();
    await _scanCtrl.close();
    await _challengeCtrl.close();
    await _a2dpCtrl.close();
  }
}
