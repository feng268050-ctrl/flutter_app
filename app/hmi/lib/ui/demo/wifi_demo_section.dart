import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/wifi/wifi_ap_list.dart';
import 'package:lws_hmi/platform/wifi/wifi_controller.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';
import 'package:lws_hmi/ui/demo/demo_scroll_interaction.dart';
import 'package:lws_hmi/ui/wifi/wifi_network_views.dart';

/// P2.1 Demo: Wi-Fi management (visible + hidden, DHCP/static).
class WifiDemoSection extends StatefulWidget {
  const WifiDemoSection({super.key, required this.controller});

  final WifiController controller;

  @override
  State<WifiDemoSection> createState() => _WifiDemoSectionState();
}

class _WifiDemoSectionState extends State<WifiDemoSection>
    with AutomaticKeepAliveClientMixin {
  late WifiRadioState _radio = widget.controller.currentRadio;
  late WifiConnectionState _conn = widget.controller.currentConnection;
  List<WifiAccessPoint> _scanned = const [];
  WlanIpv4Config _ipv4 = WlanIpv4Config.dhcpDefault;
  String? _busy;
  String? _error;

  final _hiddenSsid = TextEditingController();
  final _hiddenPsk = TextEditingController();
  final _staticAddr = TextEditingController();
  final _staticPrefix = TextEditingController(text: '24');
  final _staticGw = TextEditingController();
  final _staticDns = TextEditingController();
  final _connectPsk = TextEditingController();

  StreamSubscription<WifiRadioState>? _radioSub;
  StreamSubscription<WifiConnectionState>? _connSub;

  List<WifiAccessPoint> get _available => WifiApList.available(
        scanned: _scanned,
        connectedSsid: _radio == WifiRadioState.on && _conn.isAssociated
            ? _conn.ssid
            : null,
      );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _radio = widget.controller.currentRadio;
    _conn = widget.controller.currentConnection;
    _radioSub = widget.controller.radio.listen((s) {
      if (mounted) {
        setState(() => _radio = s);
      }
    });
    _connSub = widget.controller.connection.listen((s) {
      if (mounted) {
        setState(() => _conn = s);
      }
    });
    unawaited(_loadIpv4());
  }

  Future<void> _loadIpv4() async {
    try {
      final c = await widget.controller.getIpv4Config();
      if (!mounted) {
        return;
      }
      setState(() {
        _ipv4 = c;
        _staticAddr.text = c.address;
        _staticPrefix.text = '${c.prefixLength}';
        _staticGw.text = c.gateway;
        _staticDns.text = c.dns;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    }
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

  @override
  void dispose() {
    unawaited(_radioSub?.cancel() ?? Future<void>.value());
    unawaited(_connSub?.cancel() ?? Future<void>.value());
    _hiddenSsid.dispose();
    _hiddenPsk.dispose();
    _staticAddr.dispose();
    _staticPrefix.dispose();
    _staticGw.dispose();
    _staticDns.dispose();
    _connectPsk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final radioOn = _radio == WifiRadioState.on;
    final showConnected = radioOn &&
        (_conn.isAssociated || _conn.phase == WifiConnectionPhase.failed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wi-Fi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Radio: ${_radio.name}',
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
        ),
        if (_busy != null)
          Text('Busy: $_busy', style: const TextStyle(color: Colors.amber)),
        if (_error != null)
          Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Radio', style: TextStyle(color: Colors.white)),
          value: radioOn || _radio == WifiRadioState.starting,
          onChanged: _busy != null
              ? null
              : (v) {
                  // Scroll drag starting on the Switch must not power the radio.
                  if (DemoScrollInteraction.isScrollingOf(context)) {
                    return;
                  }
                  unawaited(
                    _guard('radio', () => widget.controller.setRadioEnabled(v)),
                  );
                },
        ),
        if (showConnected) ...[
          const Text(
            'Connected',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 4),
          WifiConnectedPanel(
            connection: _conn,
            onDisconnect: !radioOn || _busy != null
                ? null
                : () => unawaited(
                      _guard('disconnect', widget.controller.disconnect),
                    ),
            onForget: !radioOn ||
                    _busy != null ||
                    _conn.ssid == null ||
                    _conn.ssid!.isEmpty
                ? null
                : () => unawaited(
                      _guard(
                        'forget',
                        () => widget.controller.forget(_conn.ssid!),
                      ),
                    ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            const Text(
              'Available',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const Spacer(),
            FilledButton(
              onPressed: !radioOn || _busy != null
                  ? null
                  : () => unawaited(_guard('scan', () async {
                        final aps = await widget.controller.scan();
                        if (mounted) {
                          setState(() => _scanned = aps);
                        }
                      })),
              child: const Text('Scan'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        WifiAvailableList(
          accessPoints: _available.take(16).toList(),
          onConnect: _busy != null ? null : _connectVisible,
        ),
        const SizedBox(height: 12),
        const Text(
          'Hidden network',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        _field(_hiddenSsid, 'SSID'),
        _field(_hiddenPsk, 'Password', obscure: true),
        FilledButton(
          onPressed: !radioOn || _busy != null
              ? null
              : () => unawaited(_guard('hidden', () async {
                    await widget.controller.connect(
                      ssid: _hiddenSsid.text.trim(),
                      psk: _hiddenPsk.text,
                      hidden: true,
                    );
                  })),
          child: const Text('Connect hidden'),
        ),
        const SizedBox(height: 16),
        const Text(
          'IPv4 mode (wlan0)',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        SegmentedButton<WlanIpv4Mode>(
          segments: const [
            ButtonSegment(value: WlanIpv4Mode.dhcp, label: Text('DHCP')),
            ButtonSegment(
              value: WlanIpv4Mode.staticMode,
              label: Text('Static'),
            ),
          ],
          selected: {_ipv4.mode},
          onSelectionChanged: (set) {
            if (set.isEmpty || DemoScrollInteraction.isScrollingOf(context)) {
              return;
            }
            setState(() => _ipv4 = _ipv4.copyWith(mode: set.first));
          },
        ),
        if (_ipv4.mode == WlanIpv4Mode.staticMode) ...[
          _field(_staticAddr, 'Address'),
          _field(_staticPrefix, 'Prefix'),
          _field(_staticGw, 'Gateway'),
          _field(_staticDns, 'DNS'),
        ],
        FilledButton(
          onPressed: _busy != null
              ? null
              : () => unawaited(_guard('ipv4', () async {
                    final cfg = _ipv4.mode == WlanIpv4Mode.dhcp
                        ? WlanIpv4Config.dhcpDefault
                        : WlanIpv4Config(
                            mode: WlanIpv4Mode.staticMode,
                            address: _staticAddr.text.trim(),
                            prefixLength:
                                int.tryParse(_staticPrefix.text.trim()) ?? 24,
                            gateway: _staticGw.text.trim(),
                            dns: _staticDns.text.trim(),
                          );
                    await widget.controller.setIpv4Config(cfg);
                    setState(() => _ipv4 = cfg);
                  })),
          child: const Text('Apply IPv4'),
        ),
      ],
    );
  }

  Future<void> _connectVisible(WifiAccessPoint ap) async {
    var psk = '';
    if (!ap.isOpen) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Password for ${ap.ssid}'),
          content: TextField(
            controller: _connectPsk,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'PSK'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Connect'),
            ),
          ],
        ),
      );
      if (ok != true) {
        return;
      }
      psk = _connectPsk.text;
    }
    await _guard('connect', () async {
      await widget.controller.connect(
        ssid: ap.ssid,
        psk: psk.isEmpty ? null : psk,
      );
    });
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: c,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
        ),
      ),
    );
  }
}
