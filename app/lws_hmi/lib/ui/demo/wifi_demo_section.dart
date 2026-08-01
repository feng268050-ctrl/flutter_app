import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:flutter/material.dart';
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

  StreamSubscription<WifiRadioState>? _radioSub;
  StreamSubscription<WifiConnectionState>? _connSub;

  List<WifiAccessPoint> get _available => WifiApList.available(
        scanned: _scanned,
        connectedSsid: _radio == WifiRadioState.on && _conn.isAssociated
            ? _conn.ssid
            : null,
      );

  /// Session strip: associating / obtainingIp / connected / failed with SSID.
  bool get _showSessionPanel {
    if (_radio != WifiRadioState.on) {
      return false;
    }
    final ssid = _conn.ssid;
    if (ssid == null || ssid.isEmpty) {
      return false;
    }
    switch (_conn.phase) {
      case WifiConnectionPhase.associating:
      case WifiConnectionPhase.obtainingIp:
      case WifiConnectionPhase.connected:
      case WifiConnectionPhase.failed:
        return true;
      case WifiConnectionPhase.disconnected:
        return false;
    }
  }

  bool get _canApplyIpv4 =>
      _busy == null &&
      _radio == WifiRadioState.on &&
      (_conn.phase == WifiConnectionPhase.connected ||
          _conn.phase == WifiConnectionPhase.obtainingIp);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _radio = widget.controller.currentRadio;
    _conn = widget.controller.currentConnection;
    _radioSub = widget.controller.radio.listen((s) {
      if (!mounted) {
        return;
      }
      setState(() {
        _radio = s;
        // Stale scan rows after radio-off confuse reconnect UX.
        if (s != WifiRadioState.on && s != WifiRadioState.starting) {
          _scanned = const [];
        }
      });
    });
    _connSub = widget.controller.connection.listen((s) {
      if (mounted) {
        setState(() => _conn = s);
      }
    });
    unawaited(_loadIpv4());
    unawaited(widget.controller.syncFromSystem());
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

  static void _validateStaticIpv4({
    required String address,
    required String prefixText,
  }) {
    if (address.isEmpty) {
      throw StateError('static address is empty');
    }
    final p = int.tryParse(prefixText.trim());
    if (p == null || p < 0 || p > 32) {
      throw StateError('prefix must be 0–32');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final radioOn = _radio == WifiRadioState.on;
    final canForget = radioOn &&
        _busy == null &&
        _conn.ssid != null &&
        _conn.ssid!.isNotEmpty &&
        (_conn.isAssociated || _conn.phase == WifiConnectionPhase.failed);
    final canDisconnect = radioOn && _busy == null && _conn.isAssociated;
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
        if (_showSessionPanel) ...[
          Text(
            _conn.phase == WifiConnectionPhase.failed
                ? 'Session'
                : _conn.isAssociated
                    ? 'Connected'
                    : 'Connecting',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 4),
          WifiConnectedPanel(
            connection: _conn,
            onDisconnect: !canDisconnect
                ? null
                : () => unawaited(
                      _guard('disconnect', widget.controller.disconnect),
                    ),
            onForget: !canForget
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
          accessPoints: radioOn ? _available.take(16).toList() : const [],
          onConnect: !radioOn || _busy != null ? null : _connectVisible,
          emptyLabel: radioOn ? '(no networks — Scan)' : '(radio off)',
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
                    final ssid = _hiddenSsid.text.trim();
                    if (ssid.isEmpty) {
                      throw StateError('hidden SSID is empty');
                    }
                    final psk = _hiddenPsk.text;
                    // Open hidden (empty PSK) is allowed; PSK path when typed.
                    await widget.controller.connect(
                      ssid: ssid,
                      psk: psk.isEmpty ? null : psk,
                      hidden: true,
                    );
                  })),
          child: const Text('Connect hidden'),
        ),
        const SizedBox(height: 16),
        Text(
          'IPv4 mode (${widget.controller.interfaceName})',
          style: const TextStyle(color: Colors.white, fontSize: 18),
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
        if (!_canApplyIpv4)
          Text(
            'Connect to a network before Apply IPv4 takes effect on the link.',
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
          ),
        FilledButton(
          onPressed: !_canApplyIpv4
              ? null
              : () => unawaited(_guard('ipv4', () async {
                    final cfg = _ipv4.mode == WlanIpv4Mode.dhcp
                        ? WlanIpv4Config.dhcpDefault
                        : () {
                            final addr = _staticAddr.text.trim();
                            final prefixText = _staticPrefix.text.trim();
                            _validateStaticIpv4(
                              address: addr,
                              prefixText: prefixText,
                            );
                            return WlanIpv4Config(
                              mode: WlanIpv4Mode.staticMode,
                              address: addr,
                              prefixLength: int.parse(prefixText),
                              gateway: _staticGw.text.trim(),
                              dnsMode: WlanDnsMode.manual,
                              dnsServers: WlanIpv4Config.splitDnsServers(
                                _staticDns.text.trim(),
                              ),
                            );
                          }();
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
      // Fresh controller per dialog — never reuse prior network's PSK text.
      final pskCtrl = TextEditingController();
      try {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Password for ${ap.ssid}'),
            content: TextField(
              controller: pskCtrl,
              obscureText: true,
              autofocus: true,
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
        psk = pskCtrl.text;
      } finally {
        pskCtrl.dispose();
      }
      if (psk.isEmpty) {
        if (mounted) {
          setState(() => _error = 'password required for ${ap.ssid}');
        }
        return;
      }
    }
    await _guard('connect', () async {
      // Do not pin BSSID — same SSID may roam across APs.
      await widget.controller.connect(
        ssid: ap.ssid,
        psk: psk.isEmpty ? null : psk,
        requiresPsk: !ap.isOpen,
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
