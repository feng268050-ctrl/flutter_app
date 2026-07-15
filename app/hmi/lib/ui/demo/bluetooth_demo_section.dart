import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/ui/demo/demo_scroll_interaction.dart';

/// P2.1 Demo: HMI discoverable so phones/PCs can find and connect to us.
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
  late List<BluetoothRemoteDevice> _devices =
      widget.controller.currentIncomingDevices;
  late bool _a2dp = widget.controller.currentA2dpSinkEnabled;
  String? _busy;
  String? _error;

  StreamSubscription<BluetoothAdapterState>? _stateSub;
  StreamSubscription<BluetoothAdapterInfo>? _infoSub;
  StreamSubscription<List<BluetoothRemoteDevice>>? _devSub;
  StreamSubscription<bool>? _a2dpSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.currentAdapterState;
    _info = widget.controller.currentAdapterInfo;
    _devices = widget.controller.currentIncomingDevices;
    _a2dp = widget.controller.currentA2dpSinkEnabled;
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
    _devSub = widget.controller.incomingDevices.listen((d) {
      if (mounted) {
        setState(() => _devices = d);
      }
    });
    _a2dpSub = widget.controller.a2dpSinkEnabled.listen((v) {
      if (mounted) {
        setState(() => _a2dp = v);
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
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  bool get _scrollBlocked => DemoScrollInteraction.isScrollingOf(context);

  @override
  void dispose() {
    unawaited(_stateSub?.cancel() ?? Future<void>.value());
    unawaited(_infoSub?.cancel() ?? Future<void>.value());
    unawaited(_devSub?.cancel() ?? Future<void>.value());
    unawaited(_a2dpSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final on = _state == BluetoothAdapterState.on;
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
          'Phone/PC can discover and pair to this HMI.\n'
          'Optional “BT speaker” (A2DP Sink) plays phone music on the onboard amp — '
          'off by default. BLE/GATT provisioning later can coexist.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'Adapter: ${_state.name}'
          '${_info.name.isNotEmpty ? ' · ${_info.name}' : ''}'
          '${_info.address.isNotEmpty ? ' · ${_info.address}' : ''}',
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
        ),
        if (_state == BluetoothAdapterState.error &&
            (widget.controller.lastError ?? '').isNotEmpty)
          Text(
            widget.controller.lastError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        if (_busy != null)
          Text('Busy: $_busy', style: const TextStyle(color: Colors.amber)),
        if (_error != null)
          Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
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
        const Text(
          'Incoming peers',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        if (!on || _devices.isEmpty)
          Text(
            on
                ? '(none yet — enable Pairable or Discoverable, then pair from phone)'
                : '(adapter off)',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        if (on)
          ..._devices.map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                d.name.isEmpty ? d.address : d.name,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${d.address} · paired=${d.paired} · trusted=${d.trusted} · connected=${d.connected}',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: _busy != null
                        ? null
                        : () => unawaited(
                              _guard(
                                'disconnect',
                                () => widget.controller.disconnectRemote(
                                  d.address,
                                ),
                              ),
                            ),
                    child: const Text('Disconnect'),
                  ),
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
            ),
          ),
      ],
    );
  }
}
