import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/bluetooth/bluetoothctl_parse.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// BlueZ via helpers + `bluetoothctl` (discoverable peer, not central scan).
class LinuxBluezBluetoothController implements BluetoothController {
  LinuxBluezBluetoothController({
    this.stackUp = const ['/usr/lib/lws-hmi/bt-stack-up.sh'],
    this.stackDown = const ['/usr/lib/lws-hmi/bt-stack-down.sh'],
    this.a2dpUp = const ['/usr/lib/lws-hmi/bt-a2dp-sink-up.sh'],
    this.a2dpDown = const ['/usr/lib/lws-hmi/bt-a2dp-sink-down.sh'],
    this.a2dpPrefPath = '/var/lib/lws-hmi/bt-a2dp-sink',
    this.bluetoothctlBin = 'bluetoothctl',
  }) {
    unawaited(_loadA2dpPref());
  }

  final List<String> stackUp;
  final List<String> stackDown;
  final List<String> a2dpUp;
  final List<String> a2dpDown;
  final String a2dpPrefPath;
  final String bluetoothctlBin;

  final _stateCtrl = StreamController<BluetoothAdapterState>.broadcast();
  final _infoCtrl = StreamController<BluetoothAdapterInfo>.broadcast();
  final _devicesCtrl =
      StreamController<List<BluetoothRemoteDevice>>.broadcast();
  final _a2dpCtrl = StreamController<bool>.broadcast();

  BluetoothAdapterState _state = BluetoothAdapterState.off;
  BluetoothAdapterInfo _info = const BluetoothAdapterInfo();
  List<BluetoothRemoteDevice> _devices = const [];
  bool _a2dpSinkEnabled = false;
  String? _lastError;
  Timer? _poll;

  @override
  String? get lastError => _lastError;

  @override
  BluetoothAdapterState get currentAdapterState => _state;

  @override
  BluetoothAdapterInfo get currentAdapterInfo => _info;

  @override
  List<BluetoothRemoteDevice> get currentIncomingDevices => _devices;

  @override
  bool get currentA2dpSinkEnabled => _a2dpSinkEnabled;

  @override
  Stream<BluetoothAdapterState> get adapterState => _stateCtrl.stream;

  @override
  Stream<BluetoothAdapterInfo> get adapterInfo => _infoCtrl.stream;

  @override
  Stream<List<BluetoothRemoteDevice>> get incomingDevices =>
      _devicesCtrl.stream;

  @override
  Stream<bool> get a2dpSinkEnabled => _a2dpCtrl.stream;

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

  void _emitDevices(List<BluetoothRemoteDevice> devices) {
    _devices = devices;
    if (!_devicesCtrl.isClosed) {
      _devicesCtrl.add(devices);
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

  Future<String> _ctl(List<String> args) async {
    final r = await _run([bluetoothctlBin, ...args]);
    return (r.stdout as String? ?? '').trim();
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

  Future<bool> _bluealsaActive() async {
    try {
      final r = await _run(const ['systemctl', 'is-active', 'bluealsa.service']);
      return (r.stdout as String? ?? '').trim() == 'active';
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshA2dp() async {
    if (_state != BluetoothAdapterState.on) {
      // Keep preference for UI while adapter is off; runtime is stopped.
      await _loadA2dpPref();
      return;
    }
    final active = await _bluealsaActive();
    _emitA2dp(active);
  }

  @override
  Future<void> setAdapterEnabled(bool enabled) async {
    if (enabled) {
      _emitState(BluetoothAdapterState.starting);
      final r = await _run(stackUp);
      if (r.exitCode != 0) {
        final err = (r.stderr as String? ?? '').trim();
        final out = (r.stdout as String? ?? '').trim();
        _lastError = err.isNotEmpty
            ? err
            : (out.isNotEmpty ? out : 'bt-stack-up failed (exit ${r.exitCode})');
        debugPrint('bt: $_lastError');
        _emitState(BluetoothAdapterState.error);
        return;
      }
      _lastError = null;
      _emitState(BluetoothAdapterState.on);
      _startPoll();
      await _run(const ['/usr/lib/lws-hmi/bt-ensure-agent.sh']);
      await _run(const ['/usr/lib/lws-hmi/bt-set-alias.sh']);
      await _refresh();
      await _refreshA2dp();
    } else {
      _poll?.cancel();
      _poll = null;
      _lastError = null;
      await _run(stackDown);
      _emitState(BluetoothAdapterState.off);
      _emitInfo(const BluetoothAdapterInfo());
      _emitDevices(const []);
      // Runtime stopped with stack; keep pref (reload wanted state).
      await _loadA2dpPref();
    }
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (_state != BluetoothAdapterState.on) {
      return;
    }
    try {
      final show = await _ctl(const ['show']);
      final info = BluetoothctlParse.parseShow(show);
      _emitInfo(info);
      final devicesRaw = await _ctl(const ['devices']);
      final base = BluetoothctlParse.parseDevices(devicesRaw);
      final enriched = <BluetoothRemoteDevice>[];
      var needTrust = false;
      for (final d in base) {
        final infoText = await _ctl(['info', d.address]);
        final m = BluetoothctlParse.mergeInfo(d, infoText);
        enriched.add(m);
        if (m.paired && !m.trusted) {
          needTrust = true;
        }
      }
      if (needTrust) {
        await _run(const ['/usr/lib/lws-hmi/bt-trust-paired.sh']);
        // Re-read after trust.
        enriched.clear();
        for (final d in base) {
          final infoText = await _ctl(['info', d.address]);
          enriched.add(BluetoothctlParse.mergeInfo(d, infoText));
        }
      }
      // Do not bluetoothctl-connect unpaired remotes — initiator SDP ENOSYS on AIC.
      _emitDevices(enriched);
      await _refreshA2dp();
    } catch (e) {
      lwsTrace('bt: refresh failed: $e');
    }
  }

  @override
  Future<void> setDiscoverable(bool enabled) async {
    await _run(const ['/usr/lib/lws-hmi/bt-ensure-agent.sh']);
    await _run(const ['/usr/lib/lws-hmi/bt-set-alias.sh']);
    if (enabled) {
      await _ctl(const ['discoverable-timeout', '180']);
    }
    await _ctl(['discoverable', enabled ? 'on' : 'off']);
    await _refresh();
  }

  @override
  Future<void> setPairable(bool enabled) async {
    await _run(const ['/usr/lib/lws-hmi/bt-ensure-agent.sh']);
    await _run(const ['/usr/lib/lws-hmi/bt-set-alias.sh']);
    await _ctl(['pairable', enabled ? 'on' : 'off']);
    // Classic BT: phones only find the HMI while Discoverable (inquiry scan).
    // Pairable alone accepts a bond after discovery — enable Discoverable with
    // Pairable so Demo “pairing mode” matches user expectation.
    if (enabled) {
      await _ctl(const ['discoverable-timeout', '180']);
      await _ctl(const ['discoverable', 'on']);
    }
    await _refresh();
  }

  @override
  Future<void> setA2dpSinkEnabled(bool enabled) async {
    if (enabled) {
      if (_state != BluetoothAdapterState.on) {
        throw StateError('Enable Bluetooth adapter before A2DP Sink');
      }
      final r = await _run(a2dpUp);
      if (r.exitCode != 0) {
        final err = (r.stderr as String? ?? '').trim();
        throw StateError(
          err.isNotEmpty ? err : 'bt-a2dp-sink-up failed (exit ${r.exitCode})',
        );
      }
      _emitA2dp(true);
    } else {
      await _run(a2dpDown);
      _emitA2dp(false);
    }
  }

  @override
  Future<void> disconnectRemote(String address) async {
    final addr = BluetoothctlParse.normalizeAddress(address);
    await _ctl(['disconnect', addr]);
    await _refresh();
  }

  @override
  Future<void> removeRemote(String address) async {
    final addr = BluetoothctlParse.normalizeAddress(address);
    await _ctl(['remove', addr]);
    await _refresh();
  }

  @override
  Future<void> dispose() async {
    _poll?.cancel();
    await _stateCtrl.close();
    await _infoCtrl.close();
    await _devicesCtrl.close();
    await _a2dpCtrl.close();
  }
}
