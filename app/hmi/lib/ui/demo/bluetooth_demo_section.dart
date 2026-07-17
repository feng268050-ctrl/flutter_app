import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/ui/demo/demo_scroll_interaction.dart';

/// Demo: discoverable peer + A2DP + central scan/pair for HID peripherals.
class BluetoothDemoSection extends StatefulWidget {
  const BluetoothDemoSection({super.key, required this.controller});

  final BluetoothController controller;

  @override
  State<BluetoothDemoSection> createState() => _BluetoothDemoSectionState();
}

class _BluetoothDemoSectionState extends State<BluetoothDemoSection>
    with AutomaticKeepAliveClientMixin {
  late BluetoothAdapterState _state = widget.controller.currentAdapterState;
  late BluetoothAdapterInfo _info = widget.controller.currentAdapterInfo;
  late List<BluetoothRemoteDevice> _devices = widget.controller.currentDevices;
  late bool _a2dp = widget.controller.currentA2dpSinkEnabled;
  late bool _scanning = widget.controller.currentScanning;
  BluetoothPairingChallenge? _challenge;
  String? _busy;
  String? _error;
  final _passkeyCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  StreamSubscription<BluetoothAdapterState>? _stateSub;
  StreamSubscription<BluetoothAdapterInfo>? _infoSub;
  StreamSubscription<List<BluetoothRemoteDevice>>? _devSub;
  StreamSubscription<bool>? _a2dpSub;
  StreamSubscription<bool>? _scanSub;
  StreamSubscription<BluetoothPairingChallenge?>? _challengeSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.currentAdapterState;
    _info = widget.controller.currentAdapterInfo;
    _devices = widget.controller.currentDevices;
    _a2dp = widget.controller.currentA2dpSinkEnabled;
    _scanning = widget.controller.currentScanning;
    _challenge = widget.controller.currentPairingChallenge;
    _stateSub = widget.controller.adapterState.listen((s) {
      if (mounted) {
        setState(() => _state = s);
      }
    });
    _infoSub = widget.controller.adapterInfo.listen((i) {
      if (mounted) {
        setState(() => _info = i);
      }
    });
    _devSub = widget.controller.devices.listen((d) {
      if (mounted) {
        setState(() => _devices = d);
      }
    });
    _a2dpSub = widget.controller.a2dpSinkEnabled.listen((v) {
      if (mounted) {
        setState(() => _a2dp = v);
      }
    });
    _scanSub = widget.controller.scanning.listen((v) {
      if (mounted) {
        setState(() => _scanning = v);
      }
    });
    _challengeSub = widget.controller.pairingChallenge.listen((c) {
      if (mounted) {
        setState(() {
          _challenge = c;
          if (c == null) {
            _passkeyCtrl.clear();
            _pinCtrl.clear();
          }
        });
      }
    });
    unawaited(widget.controller.syncFromSystem());
  }

  Future<void> _guard(String label, Future<void> Function() fn) async {
    setState(() {
      _busy = label;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        var msg = '$e';
        msg = msg.replaceAll(
          RegExp(r'org\.freedesktop\.DBus\.Error\.\w+:\s*'),
          '',
        );
        if (msg.length > 220) {
          msg = '${msg.substring(0, 220)}…';
        }
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  bool get _scrollBlocked => DemoScrollInteraction.isScrollingOf(context);

  List<BluetoothRemoteDevice> get _bonded => _devices
      .where((d) => d.paired || d.trusted || d.connected)
      .toList(growable: false);

  List<BluetoothRemoteDevice> get _nearby {
    final rows = _devices
        .where(
          (d) =>
              d.discovered &&
              !d.paired &&
              !d.connected &&
              isBluetoothNearbyCandidate(d),
        )
        .toList(growable: true);
    rows.sort((a, b) {
      final ar = a.rssi ?? -999;
      final br = b.rssi ?? -999;
      if (ar != br) {
        return br.compareTo(ar);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return rows;
  }

  String _kindLabel(BluetoothDeviceKind k) {
    switch (k) {
      case BluetoothDeviceKind.keyboard:
        return 'keyboard';
      case BluetoothDeviceKind.mouse:
        return 'mouse';
      case BluetoothDeviceKind.phone:
        return 'phone';
      case BluetoothDeviceKind.computer:
        return 'computer';
      case BluetoothDeviceKind.audio:
        return 'audio';
      case BluetoothDeviceKind.other:
        return 'other';
      case BluetoothDeviceKind.unknown:
        return 'unknown';
    }
  }

  @override
  void dispose() {
    unawaited(_stateSub?.cancel() ?? Future<void>.value());
    unawaited(_infoSub?.cancel() ?? Future<void>.value());
    unawaited(_devSub?.cancel() ?? Future<void>.value());
    unawaited(_a2dpSub?.cancel() ?? Future<void>.value());
    unawaited(_scanSub?.cancel() ?? Future<void>.value());
    unawaited(_challengeSub?.cancel() ?? Future<void>.value());
    _passkeyCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Widget _deviceTile(
    BluetoothRemoteDevice d, {
    required bool showPair,
  }) {
    final title = d.name.isEmpty ? d.address : d.name;
    final rssi = d.rssi != null ? ' · rssi=${d.rssi}' : '';
    final inputNote = d.inputReady == null
        ? ''
        : d.inputReady!
            ? ' · input=ok'
            : ' · input=missing';
    final staleLink = d.connected && d.inputReady == false;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        '${d.address} · ${_kindLabel(d.kind)} · paired=${d.paired} · '
        'trusted=${d.trusted} · connected=${d.connected}$inputNote$rssi'
        '${staleLink ? '\nKeyboard/mouse link up but input is down — tap Connect or wait for auto-reconnect' : ''}',
        style: TextStyle(
          color: staleLink
              ? Colors.amber.withOpacity(0.85)
              : Colors.white.withOpacity(0.6),
        ),
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (showPair)
            TextButton(
              onPressed: _busy != null
                  ? null
                  : () => unawaited(
                        _guard(
                          'pair ${d.address}',
                          () => widget.controller.pairAndConnect(d.address),
                        ),
                      ),
              child: Text(d.paired ? 'Connect' : 'Pair'),
            ),
          if (d.connected || d.paired)
            TextButton(
              onPressed: _busy != null
                  ? null
                  : () => unawaited(
                        _guard(
                          'disconnect',
                          () => widget.controller.disconnectRemote(d.address),
                        ),
                      ),
              child: const Text('Disconnect'),
            ),
          if (d.paired || d.trusted || d.connected)
            TextButton(
              onPressed: _busy != null
                  ? null
                  : () => unawaited(
                        _guard(
                          'remove',
                          () => widget.controller.removeRemote(d.address),
                        ),
                      ),
              child: const Text('Remove'),
            ),
        ],
      ),
    );
  }

  Widget? _challengePanel() {
    final c = _challenge;
    if (c == null) {
      return null;
    }
    final label = c.name.isEmpty ? c.address : '${c.name} (${c.address})';
    switch (c.kind) {
      case BluetoothPairingChallengeKind.displayPasskey:
        return _challengeBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type this 6-digit passkey on the Bluetooth keyboard, then wait',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                (c.passkey?.toString().padLeft(6, '0') ?? '------'),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              if (c.enteredDigits != null)
                Text(
                  'Entered digits: ${c.enteredDigits}',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              TextButton(
                onPressed: () => unawaited(widget.controller.cancelPairing()),
                child: const Text('Cancel pairing'),
              ),
            ],
          ),
        );
      case BluetoothPairingChallengeKind.displayPinCode:
        return _challengeBox(
          child: Text(
            'PIN for $label: ${c.pinCode ?? ''}',
            style: const TextStyle(color: Colors.amber, fontSize: 18),
          ),
        );
      case BluetoothPairingChallengeKind.confirm:
        return _challengeBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label wants to pair'
                '${c.passkey != null ? ' (code ${c.passkey!.toString().padLeft(6, '0')})' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Accept to pair, like on iPhone/iPad',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => unawaited(
                      widget.controller.respondToPairingChallenge(
                        c.id,
                        accept: true,
                      ),
                    ),
                    child: const Text('Accept'),
                  ),
                  TextButton(
                    onPressed: () => unawaited(
                      widget.controller.respondToPairingChallenge(
                        c.id,
                        accept: false,
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ),
        );
      case BluetoothPairingChallengeKind.requestPasskey:
        return _challengeBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter passkey for $label',
                style: const TextStyle(color: Colors.white),
              ),
              TextField(
                controller: _passkeyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '6-digit passkey',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () {
                  final v = int.tryParse(_passkeyCtrl.text.trim());
                  unawaited(
                    widget.controller.respondToPairingChallenge(
                      c.id,
                      accept: v != null,
                      passkey: v,
                    ),
                  );
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      case BluetoothPairingChallengeKind.requestPinCode:
        return _challengeBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter PIN for $label',
                style: const TextStyle(color: Colors.white),
              ),
              TextField(
                controller: _pinCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'PIN',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () {
                  final pin = _pinCtrl.text.trim();
                  unawaited(
                    widget.controller.respondToPairingChallenge(
                      c.id,
                      accept: pin.isNotEmpty,
                      pinCode: pin,
                    ),
                  );
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      case BluetoothPairingChallengeKind.authorizeService:
      case BluetoothPairingChallengeKind.requestAuthorization:
        return _challengeBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.kind == BluetoothPairingChallengeKind.authorizeService
                    ? 'Allow ${c.serviceUuid ?? 'service'} for $label?'
                    : '$label wants to pair with this device',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Accept to pair, like on iPhone/iPad',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => unawaited(
                      widget.controller.respondToPairingChallenge(
                        c.id,
                        accept: true,
                      ),
                    ),
                    child: const Text('Accept'),
                  ),
                  TextButton(
                    onPressed: () => unawaited(
                      widget.controller.respondToPairingChallenge(
                        c.id,
                        accept: false,
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _challengeBox({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final on = _state == BluetoothAdapterState.on;
    final challenge = _challengePanel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bluetooth',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Phone/PC can discover this HMI; optional A2DP Sink plays phone music.\n'
          'Scan lists Settings-style pairing targets (HID / phone / audio) — not every LE beacon.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'Adapter: ${_state.name}'
          '${_info.name.isNotEmpty ? ' · ${_info.name}' : ''}'
          '${_info.address.isNotEmpty ? ' · ${_info.address}' : ''}'
          '${_scanning ? ' · scanning' : ''}',
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
        ),
        if (_state == BluetoothAdapterState.error &&
            (widget.controller.lastError ?? '').isNotEmpty)
          Text(
            widget.controller.lastError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        if (_error != null)
          SelectableText(
            'Error: $_error',
            style: const TextStyle(color: Colors.redAccent),
          ),
        if (challenge != null) challenge,
        if (_busy != null) ...[
          Text('Busy: $_busy', style: const TextStyle(color: Colors.amber)),
          if (_busy!.startsWith('pair'))
            TextButton(
              onPressed: () => unawaited(widget.controller.cancelPairing()),
              child: const Text('Cancel pairing'),
            ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Adapter', style: TextStyle(color: Colors.white)),
          value: on || _state == BluetoothAdapterState.starting,
          onChanged: _busy != null
              ? null
              : (v) {
                  if (_scrollBlocked) {
                    return;
                  }
                  unawaited(
                    _guard(
                      'adapter',
                      () => widget.controller.setAdapterEnabled(v),
                    ),
                  );
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Discoverable',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Visible in phone BT scan (required for first find)',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          value: on && _info.discoverable,
          onChanged: !on || _busy != null
              ? null
              : (v) {
                  if (_scrollBlocked) {
                    return;
                  }
                  unawaited(
                    _guard(
                      'discoverable',
                      () => widget.controller.setDiscoverable(v),
                    ),
                  );
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pairable', style: TextStyle(color: Colors.white)),
          subtitle: Text(
            'Accept pairing; also turns Discoverable on (180s)',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          value: on && _info.pairable,
          onChanged: !on || _busy != null
              ? null
              : (v) {
                  if (_scrollBlocked) {
                    return;
                  }
                  unawaited(
                    _guard(
                      'pairable',
                      () => widget.controller.setPairable(v),
                    ),
                  );
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'BT speaker (A2DP)',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Off by default. On: phone media connects and plays to speaker',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          value: on && _a2dp,
          onChanged: !on || _busy != null
              ? null
              : (v) {
                  if (_scrollBlocked) {
                    return;
                  }
                  unawaited(
                    _guard(
                      'a2dp',
                      () => widget.controller.setA2dpSinkEnabled(v),
                    ),
                  );
                },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: !on || _busy != null || _scrollBlocked
                  ? null
                  : () => unawaited(
                        _guard(
                          _scanning ? 'stop scan' : 'scan',
                          () => _scanning
                              ? widget.controller.stopScan()
                              : widget.controller.startScan(),
                        ),
                      ),
              child: Text(_scanning ? 'Stop scan' : 'Scan'),
            ),
            const SizedBox(width: 12),
            Text(
              _scanning ? 'Scanning (~15s)…' : 'Scan for nearby devices',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Nearby',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        if (!on || _nearby.isEmpty)
          Text(
            on
                ? (_scanning
                    ? '(scanning for keyboards, mice, phones…)'
                    : '(none — put the keyboard in pairing mode, Scan, then Pair while still scanning)')
                : '(adapter off)',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        if (on) ..._nearby.map((d) => _deviceTile(d, showPair: true)),
        const SizedBox(height: 12),
        const Text(
          'Paired / connected',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        if (!on || _bonded.isEmpty)
          Text(
            on
                ? '(none yet — pair from phone or Scan + Pair a keyboard/mouse)'
                : '(adapter off)',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        if (on)
          ..._bonded.map(
            (d) => _deviceTile(
              d,
              showPair: !d.connected || d.inputReady == false,
            ),
          ),
      ],
    );
  }
}
