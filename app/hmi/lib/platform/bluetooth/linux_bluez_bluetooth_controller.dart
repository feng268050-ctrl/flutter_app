import 'dart:async';
import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/bluetooth/bluetoothctl_parse.dart';
import 'package:lws_hmi/platform/bluetooth/hmi_bluez_agent.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// BlueZ via D-Bus (`bluez` package) + stack/A2DP shell helpers.
class LinuxBluezBluetoothController implements BluetoothController {
  LinuxBluezBluetoothController({
    this.stackUp = const ['/usr/lib/lws-hmi/bt-stack-up.sh'],
    this.stackDown = const ['/usr/lib/lws-hmi/bt-stack-down.sh'],
    this.a2dpUp = const ['/usr/lib/lws-hmi/bt-a2dp-sink-up.sh'],
    this.a2dpDown = const ['/usr/lib/lws-hmi/bt-a2dp-sink-down.sh'],
    this.stopAgent = const ['/usr/lib/lws-hmi/bt-stop-agent.sh'],
    this.ensureAgent = const ['/usr/lib/lws-hmi/bt-ensure-agent.sh'],
    this.setAlias = const ['/usr/lib/lws-hmi/bt-set-alias.sh'],
    this.a2dpPrefPath = '/var/lib/lws-hmi/bt-a2dp-sink',
    this.btWantedPath = '/var/lib/lws-hmi/bt-wanted',
    this.hmiAgentMarkerPath = '/run/lws-hmi/bt-hmi-agent',
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
  final BlueZClient _client;

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
  Future<void> _opChain = Future<void>.value();
  final List<StreamSubscription<dynamic>> _subs = [];
  final Set<String> _devicePropWired = {};
  final Set<String> _adapterPropWired = {};
  HmiBluezAgent? _agent;

  static const _wantedWatchMaxTicks = 120;

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
    final list = _deviceMap.values.toList(growable: false)
      ..sort((a, b) => a.address.compareTo(b.address));
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
    return BluetoothRemoteDevice(
      address: addr,
      name: name,
      paired: d.paired,
      trusted: d.trusted,
      connected: d.connected,
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
    if (markDiscovered) {
      _discoveredAddresses.add(addr);
    }
    _deviceMap[addr] = _mapDevice(d, discovered: markDiscovered ? true : null);
    _emitDevices();
  }

  void _removeDeviceAddress(String address) {
    final addr = BluetoothctlParse.normalizeAddress(address);
    _deviceMap.remove(addr);
    _discoveredAddresses.remove(addr);
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

  void _rebuildDeviceMap({bool markAllDiscovered = false}) {
    _deviceMap.clear();
    for (final d in _client.devices) {
      final addr = BluetoothctlParse.normalizeAddress(d.address);
      if (markAllDiscovered) {
        _discoveredAddresses.add(addr);
      }
      _deviceMap[addr] = _mapDevice(
        d,
        discovered: _discoveredAddresses.contains(addr),
      );
    }
    // Drop discovered flags for addresses no longer known.
    _discoveredAddresses.removeWhere((a) => !_deviceMap.containsKey(a));
    _emitDevices();
  }

  void _wireDeviceProps(BlueZDevice d) {
    final addr = BluetoothctlParse.normalizeAddress(d.address);
    if (_devicePropWired.contains(addr)) {
      return;
    }
    _devicePropWired.add(addr);
    _subs.add(d.propertiesChanged.listen((_) {
      _upsertDevice(d);
    }));
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
      final addr = BluetoothctlParse.normalizeAddress(d.address);
      _devicePropWired.remove(addr);
      _removeDeviceAddress(addr);
    }));
    _subs.add(_client.adapterAdded.listen((adapter) {
      _wireAdapter(adapter);
      _refreshAdapterInfo();
    }));
    _subs.add(_client.adapterRemoved.listen((_) {
      _refreshAdapterInfo();
    }));
    final a = _adapter;
    if (a != null) {
      _wireAdapter(a);
    }
    for (final d in _client.devices) {
      _wireDeviceProps(d);
    }
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
    return _outboundPairActive || _info.pairable;
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
        await _client.unregisterAgent();
        _agentRegistered = false;
      }
      await _client.registerAgent(
        _agent!,
        capability: BlueZAgentCapability.displayYesNo,
      );
      await _client.requestDefaultAgent();
      _agentRegistered = true;
    } catch (e) {
      debugPrint('bt: registerAgent failed: $e');
      await _writeHmiAgentMarker(false);
      await _run(ensureAgent);
      rethrow;
    }
  }

  Future<void> _unregisterHmiAgent({bool restoreShellAgent = false}) async {
    try {
      if (_agentRegistered) {
        await _client.unregisterAgent();
        _agentRegistered = false;
      }
    } catch (e) {
      debugPrint('bt: unregisterAgent: $e');
    }
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
  }

  @override
  Future<void> setAdapterEnabled(bool enabled) => _serialized(() async {
        _stopWantedWatch();
        if (enabled) {
          _emitState(BluetoothAdapterState.starting);
          // Claim Agent1 before stack-up so bt-ensure-agent skips the shell agent.
          await _writeHmiAgentMarker(true);
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
          await _stopScanLocked();
          await _unregisterHmiAgent();
          _lastError = null;
          await _run(stackDown);
          await _writeWanted(false);
          _deviceMap.clear();
          _discoveredAddresses.clear();
          _emitDevices();
          _emitState(BluetoothAdapterState.off);
          _emitInfo(const BluetoothAdapterInfo());
          await _loadA2dpPref();
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
        final a = _adapter;
        if (a == null) {
          throw BluetoothOperationException('No Bluetooth adapter');
        }
        if (_scanning) {
          return;
        }
        try {
          await a.startDiscovery();
          _emitScanning(true);
          _scanTimeout?.cancel();
          _scanTimeout = Timer(timeout, () {
            unawaited(_serialized(_stopScanLocked));
          });
          _rebuildDeviceMap();
        } catch (e) {
          _emitScanning(false);
          throw BluetoothOperationException('Scan failed: $e');
        }
      });

  @override
  Future<void> stopScan() => _serialized(_stopScanLocked);

  @override
  Future<void> pairAndConnect(String address) => _serialized(() async {
        if (_state != BluetoothAdapterState.on) {
          throw BluetoothOperationException('Bluetooth adapter is not on');
        }
        final addr = BluetoothctlParse.normalizeAddress(address);
        await _stopScanLocked();
        BlueZDevice? device;
        for (final d in _client.devices) {
          if (BluetoothctlParse.normalizeAddress(d.address) == addr) {
            device = d;
            break;
          }
        }
        if (device == null) {
          throw BluetoothOperationException(
            'Device not found',
            address: addr,
          );
        }
        _outboundPairActive = true;
        try {
          if (!device.paired) {
            await device.pair();
          }
          if (!device.trusted) {
            await device.setTrusted(true);
          }
          if (!device.connected) {
            await device.connect();
          }
          _upsertDevice(device);
        } catch (e) {
          throw BluetoothOperationException(
            'Pair/connect failed: $e',
            address: addr,
          );
        } finally {
          _outboundPairActive = false;
        }
      });

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
        for (final d in _client.devices) {
          if (BluetoothctlParse.normalizeAddress(d.address) == addr) {
            await d.disconnect();
            _upsertDevice(d);
            return;
          }
        }
        throw BluetoothOperationException('Device not found', address: addr);
      });

  @override
  Future<void> removeRemote(String address) => _serialized(() async {
        final addr = BluetoothctlParse.normalizeAddress(address);
        final a = _adapter;
        if (a == null) {
          throw BluetoothOperationException('No Bluetooth adapter');
        }
        for (final d in _client.devices) {
          if (BluetoothctlParse.normalizeAddress(d.address) == addr) {
            await a.removeDevice(d);
            _removeDeviceAddress(addr);
            return;
          }
        }
        throw BluetoothOperationException('Device not found', address: addr);
      });

  @override
  Future<void> respondToPairingChallenge(
    String challengeId, {
    required bool accept,
    int? passkey,
    String? pinCode,
  }) async {
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
    _scanTimeout?.cancel();
    await _stopScanLocked();
    await _unregisterHmiAgent(restoreShellAgent: _state == BluetoothAdapterState.on);
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    if (_ownedClient && _clientConnected) {
      try {
        await _client.close();
      } catch (_) {}
      _clientConnected = false;
    }
    await _stateCtrl.close();
    await _infoCtrl.close();
    await _devicesCtrl.close();
    await _scanCtrl.close();
    await _challengeCtrl.close();
    await _a2dpCtrl.close();
  }
}
