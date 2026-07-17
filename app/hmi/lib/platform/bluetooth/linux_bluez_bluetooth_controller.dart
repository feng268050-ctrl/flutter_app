import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/bluetooth/bluetoothctl_parse.dart';
import 'package:lws_hmi/platform/bluetooth/hmi_bluez_agent.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// BlueZ via D-Bus (`bluez` package) + stack/A2DP shell helpers.
class LinuxBluezBluetoothController implements BluetoothController {
  LinuxBluezBluetoothController({
    this.stackUp = const ['/usr/libexec/bluetooth/bt-stack-up.sh'],
    this.stackDown = const ['/usr/libexec/bluetooth/bt-stack-down.sh'],
    this.a2dpUp = const ['/usr/libexec/bluetooth/bt-a2dp-sink-up.sh'],
    this.a2dpDown = const ['/usr/libexec/bluetooth/bt-a2dp-sink-down.sh'],
    this.stopAgent = const ['/usr/libexec/bluetooth/bt-stop-agent.sh'],
    this.ensureAgent = const ['/usr/libexec/bluetooth/bt-ensure-agent.sh'],
    this.setAlias = const ['/usr/libexec/bluetooth/bt-set-alias.sh'],
    this.a2dpPrefPath = '/var/lib/bluetooth/bt-a2dp-sink',
    this.btWantedPath = '/var/lib/bluetooth/bt-wanted',
    this.hmiAgentMarkerPath = '/run/bt-hmi-agent',
    BlueZClient? client,
  }) : _ownedClient = client == null,
       _client = client ?? BlueZClient() {
    unawaited(_loadA2dpPref());
  }

  final List<String> stackUp;
  final List<String> stackDown;
  final List<String> a2dpUp;
  final List<String> a2dpDown;
  final List<String> stopAgent;
  final List<String> ensureAgent;
  final List<String> setAlias;
  final String a2dpPrefPath;
  final String btWantedPath;
  final String hmiAgentMarkerPath;
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
  /// In-flight `bluetoothctl` (pair/connect) so Cancel can kill it.
  Process? _activeBtctl;
  String? _consentChallengeId;
  Completer<bool>? _consentWait;
  int _agentPathSeq = 0;
  bool _autoRecoverInFlight = false;
  bool _suppressDaemonRecover = false;
  Future<void> _opChain = Future<void>.value();
  final List<StreamSubscription<dynamic>> _subs = [];
  final Set<String> _devicePropWired = {};
  final Set<String> _adapterPropWired = {};
  /// User tapped Disconnect — session UI force; durable hold is Untrust.
  final Set<String> _userDisconnectedHid = {};
  /// Addresses confirmed bonded via bluetoothctl (survives LE Paired=false).
  final Set<String> _ctlBondedAddrs = {};
  final Map<String, bool> _lastConnectedByAddr = {};
  /// Latest OS heal status / evdev probe per HID address (null = N/A).
  final Map<String, bool> _hidInputReadyByAddr = {};
  /// Observe `/run/bt-hid/*` written by bt-hid-heal.service (not heal itself).
  Timer? _hidStatusWatch;
  HmiBluezAgent? _agent;

  static const _wantedWatchMaxTicks = 120;
  static const _hidStatusInterval = Duration(seconds: 5);
  static const _hidHealHelper = '/usr/libexec/bluetooth/bt-hid-heal.sh';
  static const _hidStatusDir = '/run/bt-hid';
  static const _hidHoldPath = '/run/bt-hid/hold';

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

  /// Killable bluetoothctl for Cancel during long pair/connect.
  Future<ProcessResult> _runTracked(List<String> cmd) async {
    lwsTrace('bt: ${cmd.join(' ')}');
    final proc = await Process.start(cmd.first, cmd.sublist(1));
    _activeBtctl = proc;
    try {
      final stdoutFut =
          proc.stdout.transform(utf8.decoder).join();
      final stderrFut =
          proc.stderr.transform(utf8.decoder).join();
      final code = await proc.exitCode;
      final out = await stdoutFut;
      final err = await stderrFut;
      return ProcessResult(proc.pid, code, out, err);
    } finally {
      if (identical(_activeBtctl, proc)) {
        _activeBtctl = null;
      }
    }
  }

  Future<void> _killActiveBtctl() async {
    final p = _activeBtctl;
    if (p == null) {
      return;
    }
    _activeBtctl = null;
    try {
      p.kill(ProcessSignal.sigterm);
    } catch (_) {}
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
    // Live D-Bus Paired, plus addresses confirmed bonded via bluetoothctl sync
    // (LE often leaves Device1.Paired=false while Bonded=yes). Cleared on Remove.
    final paired = d.paired || _ctlBondedAddrs.contains(addr);
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
    _emitDevices();
  }

  void _removeDeviceAddress(String address) {
    final addr = BluetoothctlParse.normalizeAddress(address);
    _devicePropWired.remove(addr);
    _ctlBondedAddrs.remove(addr);
    // Keep scan-session rows after BlueZ drops temporary LE Device1 objects.
    final cached = _scanSession[addr];
    if (cached != null &&
        !cached.paired &&
        !cached.trusted &&
        !cached.connected) {
      _deviceMap[addr] = cached.copyWith(discovered: true);
      _discoveredAddresses.add(addr);
      _emitDevices();
      return;
    }
    _deviceMap.remove(addr);
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
      // Heal lives in bt-hid-heal.service; HMI only refreshes inputReady for UI.
      unawaited(_refreshHidInputStatus(addr));
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

  void _startHidStatusWatch() {
    _hidStatusWatch?.cancel();
    _hidStatusWatch = Timer.periodic(_hidStatusInterval, (_) {
      unawaited(_refreshAllHidInputStatus());
    });
  }

  void _stopHidStatusWatch() {
    _hidStatusWatch?.cancel();
    _hidStatusWatch = null;
  }

  Future<void> _refreshAllHidInputStatus() async {
    if (_state != BluetoothAdapterState.on) {
      return;
    }
    for (final d in _deviceMap.values.toList(growable: false)) {
      if (!_isHidLikeRemote(d)) {
        continue;
      }
      if (_userDisconnectedHid.contains(d.address)) {
        _setHidInputReady(d.address, false);
        continue;
      }
      await _refreshHidInputStatus(d.address);
    }
  }

  Future<void> _refreshHidInputStatus(String address) async {
    final addr = BluetoothctlParse.normalizeAddress(address);
    if (_userDisconnectedHid.contains(addr)) {
      _setHidInputReady(addr, false);
      return;
    }
    final mapped = _deviceMap[addr];
    if (mapped == null || !_isHidLikeRemote(mapped)) {
      return;
    }
    // Stale uhid nodes often survive BlueZ Disconnect (QM002). Never report
    // inputReady while the link is down — that skips Connect on reconnect.
    if (!mapped.connected) {
      _setHidInputReady(addr, false);
      return;
    }
    // /run/bt-hid: only `ready` is authoritative when Connected.
    final bare = addr.toUpperCase().replaceAll(':', '_');
    try {
      final f = File('$_hidStatusDir/$bare');
      if (await f.exists()) {
        final v = (await f.readAsString()).trim().toLowerCase();
        if (v == 'ready') {
          _setHidInputReady(addr, true);
          return;
        }
      }
    } catch (_) {}
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

  /// Ask OS heal helper once (pair/Connect). Ongoing heal is bt-hid-heal.service.
  Future<void> _requestOsHidHeal(String addr) async {
    final helper = File(_hidHealHelper);
    if (!await helper.exists()) {
      stderr.writeln('bt: $_hidHealHelper missing — skip OS heal');
      return;
    }
    stderr.writeln('bt: OS HID heal $addr');
    // FORCE=1: allow one-shot while HMI hold is set (loop still paused).
    final r = await _run([
      'env',
      'LWS_BT_HID_FORCE=1',
      _hidHealHelper,
      addr,
    ]);
    stderr.writeln(
      'bt: OS HID heal exit=${r.exitCode} '
      '${'${r.stdout}\n${r.stderr}'.trim().replaceAll('\n', ' | ')}',
    );
    await _refreshHidInputStatus(addr);
  }

  Future<void> _setHidHealHold(bool held) async {
    try {
      final f = File(_hidHoldPath);
      if (held) {
        await f.parent.create(recursive: true);
        await f.writeAsString('${DateTime.now().millisecondsSinceEpoch}\n');
      } else if (await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('bt: hid hold: $e');
    }
  }

  Future<void> _clearOsHidStatus(String addr) async {
    final bare = addr.toUpperCase().replaceAll(':', '_');
    try {
      final f = File('$_hidStatusDir/$bare');
      if (await f.exists()) {
        await f.delete();
      }
      await _run([
        'rm',
        '-f',
        '$_hidStatusDir/backoff/$bare',
        '$_hidStatusDir/backoff/$bare.n',
      ]);
    } catch (_) {}
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
          final r = await _run(stackUp);
          if (r.exitCode != 0) {
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
    await _run(stopAgent);
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
      await _run(ensureAgent);
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
      await _run(ensureAgent);
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
    await _run(setAlias);
    await _registerHmiAgent();
    await _refreshA2dp();
    _startHidStatusWatch();
    unawaited(_refreshAllHidInputStatus());
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
          final r = await _run(stackUp);
          if (r.exitCode != 0) {
            await _writeHmiAgentMarker(false);
            final err = (r.stderr as String? ?? '').trim();
            final out = (r.stdout as String? ?? '').trim();
            _lastError = err.isNotEmpty
                ? err
                : (out.isNotEmpty
                    ? out
                    : 'bt-stack-up failed (exit ${r.exitCode})');
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
            await _run(ensureAgent);
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
            await _run(stackDown);
            await _resetBluezClient();
            await _writeWanted(false);
            _stopHidStatusWatch();
            _clearScanSession();
            _deviceMap.clear();
            _discoveredAddresses.clear();
            _userDisconnectedHid.clear();
            _ctlBondedAddrs.clear();
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
        _emitState(BluetoothAdapterState.starting);
        await _loadA2dpPref();
        _startWantedWatch();
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

  /// bluetoothctl is authoritative — the Dart BlueZClient cache often keeps
  /// ghost Device1 objects after BlueZ deletes them (Connect → UnknownMethod).
  Future<bool> _btctlDevicePresent(String addr) async {
    final r = await _run(['bluetoothctl', 'info', addr]);
    final out = '${r.stdout ?? ''}\n${r.stderr ?? ''}';
    if (r.exitCode != 0) {
      return false;
    }
    final lower = out.toLowerCase();
    if (lower.contains('not available') ||
        lower.contains('not found') ||
        lower.contains('failed to get')) {
      return false;
    }
    return lower.contains('paired:') ||
        lower.contains('name:') ||
        lower.contains('address:');
  }

  Future<Map<String, String>> _btctlInfoMap(String addr) async {
    final r = await _run(['bluetoothctl', 'info', addr]);
    final out = '${r.stdout ?? ''}\n${r.stderr ?? ''}';
    final map = <String, String>{};
    for (final line in out.split('\n')) {
      final t = line.trim();
      final i = t.indexOf(':');
      if (i <= 0) {
        continue;
      }
      final key = t.substring(0, i).trim().toLowerCase();
      final value = t.substring(i + 1).trim();
      // UUID appears once per line — append so ADDR_TYPE sees 1812 and 1124.
      if (key == 'uuid' || key == 'uuids') {
        final prev = map[key];
        map[key] = prev == null || prev.isEmpty ? value : '$prev $value';
      } else {
        map[key] = value;
      }
    }
    return map;
  }

  Future<void> _waitUntilBtctlSeesDevice(
    String addr, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    await _ensureDiscoveryRunning();
    if (await _btctlDevicePresent(addr)) {
      return;
    }
    stderr.writeln(
      'bt: $addr not in bluetoothctl yet — scanning until it reappears',
    );
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await _ensureDiscoveryRunning();
      if (await _btctlDevicePresent(addr)) {
        stderr.writeln('bt: bluetoothctl sees $addr');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw BluetoothOperationException(
      'Keyboard left BlueZ cache. Put it in pairing mode, tap Scan, then Pair within a few seconds.',
      address: addr,
    );
  }

  bool _infoFlagYes(Map<String, String> info, String key) {
    return (info[key] ?? '').toLowerCase().startsWith('yes');
  }

  bool _infoBondedOrPaired(Map<String, String> info) {
    return _infoFlagYes(info, 'paired') || _infoFlagYes(info, 'bonded');
  }

  /// Fire bluetoothctl pair/connect and poll `info` — exit codes are unreliable
  /// (often prints only "Attempting to connect" then exits non-zero).
  Future<void> _btctlKickAndWait({
    required String action,
    required String addr,
    required bool Function(Map<String, String> info) isDone,
    required String doneLabel,
    Duration timeout = const Duration(seconds: 40),
  }) async {
    _throwIfPairAbort(addr);
    await _ensureDiscoveryRunning();
    final secs = timeout.inSeconds;
    stderr.writeln('bt: bluetoothctl --timeout $secs $action $addr');
    var r = await _runTracked([
      'bluetoothctl',
      '--timeout',
      '$secs',
      action,
      addr,
    ]);
    _throwIfPairAbort(addr);
    var out = '${r.stdout ?? ''}\n${r.stderr ?? ''}'.trim();
    if (out.toLowerCase().contains('unrecognized option') ||
        out.toLowerCase().contains('invalid option') ||
        out.contains('Unknown command')) {
      stderr.writeln('bt: --timeout unsupported, plain bluetoothctl $action');
      r = await _runTracked(['bluetoothctl', action, addr]);
      out = '${r.stdout ?? ''}\n${r.stderr ?? ''}'.trim();
    }
    _throwIfPairAbort(addr);
    stderr.writeln(
      'bt: bluetoothctl $action exit=${r.exitCode} ${out.replaceAll('\n', ' | ')}',
    );

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      _throwIfPairAbort(addr);
      if (!await _btctlDevicePresent(addr)) {
        await _ensureDiscoveryRunning();
      }
      final info = await _btctlInfoMap(addr);
      if (isDone(info)) {
        stderr.writeln('bt: $doneLabel after $action for $addr');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final info = await _btctlInfoMap(addr);
    throw BluetoothOperationException(
      'bluetoothctl $action: still paired=${info['paired'] ?? "?"} '
      'bonded=${info['bonded'] ?? "?"} connected=${info['connected'] ?? "?"} '
      '(exit ${r.exitCode}) $out',
      address: addr,
    );
  }

  Future<void> _btctlTrust(String addr) async {
    stderr.writeln('bt: bluetoothctl trust $addr');
    final r = await _run(['bluetoothctl', 'trust', addr]);
    final out = '${r.stdout ?? ''}\n${r.stderr ?? ''}'.trim();
    stderr.writeln('bt: trust exit=${r.exitCode} $out');
    await _busctlSetBool(addr, 'Trusted', true);
    for (var i = 0; i < 10; i++) {
      final info = await _btctlInfoMap(addr);
      if (_infoFlagYes(info, 'trusted')) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Clear Trusted so BlueZ policy / keyboard inbound LE does not instantly
  /// re-attach after a user Disconnect (keeps the bond; Connect + trust again).
  Future<void> _btctlUntrust(String addr) async {
    stderr.writeln('bt: bluetoothctl untrust $addr (hold disconnect)');
    await _run(['bluetoothctl', 'untrust', addr]);
    await _busctlSetBool(addr, 'Trusted', false);
    for (var i = 0; i < 10; i++) {
      final info = await _btctlInfoMap(addr);
      if (!_infoFlagYes(info, 'trusted')) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Rockchip ADDR_TYPE for Connect/Disconnect: random|public|bredr|auto.
  ///
  /// Rockchip remaps these differently from stock BlueZ AddressType:
  /// - `random` / `public` → LE random / LE public
  /// - `bredr` → Classic BR/EDR (NOT the same as AddressType=public)
  /// - `auto` → keep bluetoothd's select_conn_bearer() choice
  Future<String> _rockchipAddrType(String addr) async {
    final uuids = await _busctlGetUuids(addr);
    final uuidBlob = uuids.join(' ').toLowerCase();
    var hasHogp = uuidBlob.contains('1812');
    var hasClassicHid = uuidBlob.contains('1124');
    if (!hasHogp && !hasClassicHid) {
      final info = await _btctlInfoMap(addr);
      final fallback =
          '${info['uuid'] ?? ''} ${info['uuids'] ?? ''}'.toLowerCase();
      hasHogp = fallback.contains('1812');
      hasClassicHid = fallback.contains('1124');
    }
    final fromDbus = await _busctlGetString(addr, 'AddressType');

    // Classic HID → must use bredr. Mapping AddressType "public" to Connect
    // "public" would incorrectly select LE public on Rockchip BlueZ.
    if (hasClassicHid && !hasHogp) {
      return 'bredr';
    }
    if (hasHogp) {
      if (fromDbus == 'random' || fromDbus == 'public') {
        return fromDbus!;
      }
      final info = await _btctlInfoMap(addr);
      final raw =
          '${info['device'] ?? ''} ${info['addresstype'] ?? ''}'.toLowerCase();
      if (raw.contains('random')) return 'random';
      if (raw.contains('public')) return 'public';
      return 'random'; // most BLE HOGP keyboards
    }
    if (fromDbus == 'random') return 'random';
    // Unknown dual-mode / phone / etc.: let bluetoothd pick the bearer.
    return 'auto';
  }

  /// Remove a Device1 that still has properties but lost Connect/Disconnect
  /// (seen after bluetoothd ABRT / heap corruption on AIC).
  Future<void> _forceRemoveCorruptDevice(String addr) async {
    await _run(['bluetoothctl', 'remove', addr]);
    final bare = addr.toUpperCase().replaceAll(':', '_');
    await _run([
      'sh',
      '-c',
      '''
devpath=\$(busctl tree org.bluez --list 2>/dev/null | grep -E "/dev_$bare\$" | head -1)
if [ -n "\$devpath" ]; then
  adapter=\$(dirname "\$devpath")
  busctl call org.bluez "\$adapter" org.bluez.Adapter1 RemoveDevice o "\$devpath" 2>&1 || true
fi
''',
    ]);
    _removeDeviceAddress(addr);
  }

  /// True when a Bluetooth (uhid) HID node for [addr] exists — never USB mice.
  Future<bool> _hidEvdevPresent(String addr) async {
    final want = addr.toLowerCase();
    final r = await _run([
      'sh',
      '-c',
      '''
want="$want"
found=""
for d in /sys/class/input/event*/device; do
  [ -d "\$d" ] || continue
  uniq=\$(cat "\$d/uniq" 2>/dev/null | tr 'A-Z' 'a-z' || true)
  if [ -n "\$uniq" ] && [ "\$uniq" = "\$want" ]; then
    n=\$(cat "\$d/name" 2>/dev/null || true)
    found="\$found \$n"
    continue
  fi
  # Fallback: uhid path + keyboard-like name (uniq sometimes empty briefly).
  real=\$(readlink -f "\$d" 2>/dev/null || true)
  case "\$real" in *uhid*)
    n=\$(cat "\$d/name" 2>/dev/null || true)
    case "\$n" in *[Kk]eyboard*|*QM002*) found="\$found \$n";; esac
    ;;
  esac
done
echo "bt_hid:\${found:-none}"
''',
    ]);
    final out = '${r.stdout}'.trim();
    stderr.writeln('bt: input probe ${out.replaceAll('\n', ' | ')}');
    return out.contains('bt_hid:') &&
        !out.contains('bt_hid:none') &&
        !out.endsWith('bt_hid:');
  }

  /// Rockchip: Connect/Disconnect need `s ADDR_TYPE`; stock methods are empty.
  Future<ProcessResult> _busctlDeviceCall(
    String addr,
    String method, {
    String? arg,
  }) async {
    final bare = addr.toUpperCase().replaceAll(':', '_');
    if (arg != null) {
      return _run([
        'sh',
        '-c',
        '''
devpath=\$(busctl tree org.bluez --list 2>/dev/null | grep -E "/dev_$bare\$" | head -1)
if [ -z "\$devpath" ]; then
  echo "no Device1 path for $bare"
  exit 2
fi
echo "devpath=\$devpath method=$method arg=$arg"
busctl call org.bluez "\$devpath" org.bluez.Device1 $method s "$arg" 2>&1
''',
      ]);
    }
    return _run([
      'sh',
      '-c',
      '''
devpath=\$(busctl tree org.bluez --list 2>/dev/null | grep -E "/dev_$bare\$" | head -1)
if [ -z "\$devpath" ]; then
  echo "no Device1 path for $bare"
  exit 2
fi
echo "devpath=\$devpath method=$method"
busctl call org.bluez "\$devpath" org.bluez.Device1 $method 2>&1
''',
    ]);
  }

  Future<void> _busctlSetBool(String addr, String prop, bool value) async {
    final bare = addr.toUpperCase().replaceAll(':', '_');
    final v = value ? 'true' : 'false';
    await _run([
      'sh',
      '-c',
      '''
devpath=\$(busctl tree org.bluez --list 2>/dev/null | grep -E "/dev_$bare\$" | head -1)
[ -n "\$devpath" ] || exit 1
busctl set-property org.bluez "\$devpath" org.bluez.Device1 $prop b $v 2>&1 || true
''',
    ]);
  }

  Future<String?> _busctlGetString(String addr, String prop) async {
    final bare = addr.toUpperCase().replaceAll(':', '_');
    final r = await _run([
      'sh',
      '-c',
      '''
devpath=\$(busctl tree org.bluez --list 2>/dev/null | grep -E "/dev_$bare\$" | head -1)
[ -n "\$devpath" ] || exit 1
busctl get-property org.bluez "\$devpath" org.bluez.Device1 $prop 2>/dev/null
''',
    ]);
    // e.g. s "random"
    final out = '${r.stdout}'.trim();
    final m = RegExp(r'"([^"]*)"').firstMatch(out);
    return m?.group(1);
  }

  /// Full Device1.UUIDs list (avoids bluetoothctl info last-UUID-wins).
  Future<List<String>> _busctlGetUuids(String addr) async {
    final bare = addr.toUpperCase().replaceAll(':', '_');
    final r = await _run([
      'sh',
      '-c',
      '''
devpath="/org/bluez/hci0/dev_$bare"
if ! busctl get-property org.bluez "\$devpath" org.bluez.Device1 Address >/dev/null 2>&1; then
  devpath=\$(busctl tree org.bluez --list 2>/dev/null | grep -E "/dev_$bare\$" | head -1)
fi
[ -n "\$devpath" ] || exit 1
busctl get-property org.bluez "\$devpath" org.bluez.Device1 UUIDs 2>/dev/null
''',
    ]);
    final out = '${r.stdout}'.trim();
    return RegExp(r'"([^"]+)"')
        .allMatches(out)
        .map((m) => m.group(1)!)
        .toList(growable: false);
  }

  /// Host Connect with Rockchip ADDR_TYPE; wait until Connected or BT evdev.
  Future<void> _busctlConnectAndWait(
    String addr, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    _throwIfPairAbort(addr);
    await _ensureDiscoveryRunning();
    final addrType = await _rockchipAddrType(addr);
    stderr.writeln('bt: Connect s "$addrType" $addr');
    var r = await _busctlDeviceCall(addr, 'Connect', arg: addrType);
    _throwIfPairAbort(addr);
    var out = '${r.stdout}\n${r.stderr}';
    if (out.contains('UnknownMethod') || out.contains("doesn't exist")) {
      if (addrType != 'auto') {
        stderr.writeln('bt: Connect $addrType UnknownMethod, retry auto');
        r = await _busctlDeviceCall(addr, 'Connect', arg: 'auto');
        out = '${r.stdout}\n${r.stderr}';
      }
    } else if (r.exitCode != 0 && addrType != 'auto') {
      r = await _busctlDeviceCall(addr, 'Connect', arg: 'auto');
      out = '${r.stdout}\n${r.stderr}';
    }
    // bluetoothctl connect as last host kick (exit codes unreliable).
    if (r.exitCode != 0) {
      stderr.writeln(
        'bt: busctl Connect exit=${r.exitCode} — bluetoothctl connect fallback',
      );
      await _runTracked(['bluetoothctl', 'connect', addr]);
    }
    _throwIfPairAbort(addr);

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      _throwIfPairAbort(addr);
      final info = await _btctlInfoMap(addr);
      // Require Connected — stale uhid after Disconnect must not end the wait.
      if (_infoFlagYes(info, 'connected')) {
        stderr.writeln(
          'bt: Connect ok connected=yes services=${info['servicesresolved']}',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final info = await _btctlInfoMap(addr);
    throw BluetoothOperationException(
      'Connect timed out (connected=${info['connected']}, '
      'services=${info['servicesresolved']}). '
      'Wake the keyboard and tap Connect again.',
      address: addr,
    );
  }

  /// Outbound HID state machine (discovery stays on for LE Device1 lifetime):
  /// 1) Pair if not bonded  2) Trust  3) Connect if link down  4) OS heal for HOGP/evdev
  ///
  /// User Disconnect keeps the bond and clears Trusted — reconnect must hit
  /// step 3 explicitly. Relying only on heal skipped Connect when already paired.
  Future<void> _btctlPairConnectTrust(String addr) async {
    await _waitUntilBtctlSeesDevice(addr);
    await _ensureDiscoveryRunning();

    var info = await _btctlInfoMap(addr);
    stderr.writeln(
      'bt: before pair/connect info paired=${info['paired']} '
      'bonded=${info['bonded']} connected=${info['connected']} '
      'trusted=${info['trusted']}',
    );

    // 1) Bond once (fresh pair). Already-bonded reconnect skips this.
    if (!_infoBondedOrPaired(info)) {
      await _btctlKickAndWait(
        action: 'pair',
        addr: addr,
        isDone: _infoBondedOrPaired,
        doneLabel: 'bonded/paired=yes',
      );
      info = await _btctlInfoMap(addr);
    }

    // 2) Trusted so BlueZ Policy + bt-hid-heal may assist after we release hold.
    if (!_infoFlagYes(info, 'trusted')) {
      await _btctlTrust(addr);
      info = await _btctlInfoMap(addr);
    }

    // 3) User Disconnect leaves bonded=yes connected=no — must Connect here.
    // Do NOT skip when stale uhid/evdev still exists (common after LE Disconnect).
    if (!_infoFlagYes(info, 'connected')) {
      await _busctlConnectAndWait(addr);
      info = await _btctlInfoMap(addr);
    }

    // 4) HOGP attach / zombie recovery when link is up but input is missing.
    if (_infoFlagYes(info, 'connected') && !await _hidEvdevPresent(addr)) {
      await _requestOsHidHeal(addr);
      info = await _btctlInfoMap(addr);
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

      // Explicit user Connect/Pair clears the Disconnect hold immediately.
      _userDisconnectedHid.remove(addr);

      // Fresh Pair needs consent; already-bonded reconnect is just Connect.
      // Consent stays outside the op lock so Cancel/Disconnect are not blocked
      // while the dialog is open.
      final prior = await _btctlInfoMap(addr);
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
          'bt: user accepted pair $addr — bluetoothctl path (ignore Dart Device1 cache)',
        );
      }

      _throwIfPairAbort(addr);

      // Hold + Connect + UI sync under one lock — no Disconnect/Remove/Scan race.
      await _serialized(() async {
        _throwIfPairAbort(addr);
        await _setHidHealHold(true);
        try {
          _throwIfPairAbort(addr);
          await _btctlPairConnectTrust(addr);
          await _stopScanLocked();
          _scanSession.remove(addr);
          await _clearOsHidStatus(addr);

          final info = await _btctlInfoMap(addr);
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
          if (paired) {
            _ctlBondedAddrs.add(addr);
          } else {
            _ctlBondedAddrs.remove(addr);
          }
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
          _userDisconnectedHid.remove(addr);
          _lastConnectedByAddr[addr] = connected;
          _emitDevices();
          if (live != null) {
            _wireDeviceProps(live);
          }
        } finally {
          await _setHidHealHold(false);
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
      await _setHidHealHold(false);
    }
  }

  @override
  Future<void> cancelPairing() async {
    _pairAbort = true;
    final consent = _consentWait;
    if (consent != null && !consent.isCompleted) {
      consent.complete(false);
    }
    await _killActiveBtctl();
    await _setHidHealHold(false);
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
        await _run(setAlias);
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
        await _run(setAlias);
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
          final r = await _run(a2dpUp);
          if (r.exitCode != 0) {
            final err = (r.stderr as String? ?? '').trim();
            throw StateError(
              err.isNotEmpty
                  ? err
                  : 'bt-a2dp-sink-up failed (exit ${r.exitCode})',
            );
          }
          _emitA2dp(true);
        } else {
          await _run(a2dpDown);
          _emitA2dp(false);
        }
      });

  @override
  Future<void> disconnectRemote(String address) => _serialized(() async {
        final addr = BluetoothctlParse.normalizeAddress(address);
        await _setHidHealHold(true);
        try {
        // Hold release: Untrust so bt-hid-heal / BlueZ Policy do not re-attach.
        _userDisconnectedHid.add(addr);
        _setHidInputReady(addr, false);
        await _clearOsHidStatus(addr);

        final mapped = _deviceMap[addr];
        final isHid = mapped != null
            ? _isHidLikeRemote(mapped)
            : true; // unknown bonded HID: still untrust to hold release

        // Trusted LE keyboards re-initiate ATT within ~250ms; BlueZ policy
        // accepts them. Untrust first so Disconnect actually sticks.
        if (isHid) {
          await _btctlUntrust(addr);
        }

        final addrType = await _rockchipAddrType(addr);
        stderr.writeln('bt: Disconnect s "$addrType" $addr (user)');
        var r = await _busctlDeviceCall(addr, 'Disconnect', arg: addrType);
        var out = '${r.stdout}\n${r.stderr}';
        if (out.contains('UnknownMethod') || out.contains("doesn't exist")) {
          if (addrType != 'auto') {
            stderr.writeln('bt: Disconnect $addrType UnknownMethod, retry auto');
            r = await _busctlDeviceCall(addr, 'Disconnect', arg: 'auto');
            out = '${r.stdout}\n${r.stderr}';
          }
        } else if (r.exitCode != 0 && addrType != 'auto') {
          r = await _busctlDeviceCall(addr, 'Disconnect', arg: 'auto');
          out = '${r.stdout}\n${r.stderr}';
        }

        // Confirm release; if keyboard raced back in, untrust+Disconnect again.
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          final info = await _btctlInfoMap(addr);
          if (!_infoFlagYes(info, 'connected')) {
            break;
          }
          if (isHid) {
            stderr.writeln(
              'bt: Disconnect raced (still connected) — untrust+Disconnect again',
            );
            await _btctlUntrust(addr);
            await _busctlDeviceCall(addr, 'Disconnect', arg: addrType);
          }
        }

        final live = _findLiveDevice(addr);
        if (live != null) {
          _upsertDevice(live);
          _lastConnectedByAddr[addr] = live.connected;
        } else {
          final prev = _deviceMap[addr];
          if (prev != null) {
            _deviceMap[addr] = prev.copyWith(
              connected: false,
              trusted: isHid ? false : prev.trusted,
            );
            _emitDevices();
          }
          _lastConnectedByAddr[addr] = false;
        }

        final after = await _btctlInfoMap(addr);
        if (_infoFlagYes(after, 'connected')) {
          throw BluetoothOperationException(
            'Disconnect did not hold (device still connected). '
            'Try Remove, or toggle Bluetooth off/on.',
            address: addr,
          );
        }
        _setHidInputReady(addr, false);
        stderr.writeln(
          'bt: Disconnect held connected=false trusted=${after['trusted']}',
        );
        } finally {
          await _setHidHealHold(false);
        }
      });

  @override
  Future<void> removeRemote(String address) => _serialized(() async {
        final addr = BluetoothctlParse.normalizeAddress(address);
        final a = _adapter;
        if (a == null) {
          throw BluetoothOperationException('No Bluetooth adapter');
        }
        await _setHidHealHold(true);
        try {
        _userDisconnectedHid.remove(addr);
        _hidInputReadyByAddr.remove(addr);
        _lastConnectedByAddr.remove(addr);
        _ctlBondedAddrs.remove(addr);
        await _clearOsHidStatus(addr);

        // Untrust + Disconnect first so LE inbound does not recreate the object
        // while RemoveDevice runs.
        await _btctlUntrust(addr);
        final addrType = await _rockchipAddrType(addr);
        await _busctlDeviceCall(addr, 'Disconnect', arg: addrType);
        await Future<void>.delayed(const Duration(milliseconds: 400));

        for (final d in _client.devices) {
          if (BluetoothctlParse.normalizeAddress(d.address) == addr) {
            await a.removeDevice(d);
            _removeDeviceAddress(addr);
            await _run(['bluetoothctl', 'remove', addr]);
            return;
          }
        }
        // Device1 may be gone from Dart cache but still in bluetoothd.
        await _forceRemoveCorruptDevice(addr);
        } finally {
          await _setHidHealHold(false);
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
