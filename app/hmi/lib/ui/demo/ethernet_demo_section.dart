import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/ethernet/ethernet_controller.dart';
import 'package:lws_hmi/platform/ethernet/ethernet_models.dart';
import 'package:lws_hmi/ui/demo/demo_scroll_interaction.dart';

/// P2.1 Demo: Ethernet RJ45 (eth0) link + DHCP/static.
class EthernetDemoSection extends StatefulWidget {
  const EthernetDemoSection({super.key, required this.controller});

  final EthernetController controller;

  @override
  State<EthernetDemoSection> createState() => _EthernetDemoSectionState();
}

class _EthernetDemoSectionState extends State<EthernetDemoSection>
    with AutomaticKeepAliveClientMixin {
  late EthAdminState _admin = widget.controller.currentAdmin;
  late EthLinkState _link = widget.controller.currentLink;
  EthIpv4Config _ipv4 = EthIpv4Config.dhcpDefault;
  String? _busy;
  String? _error;

  final _staticAddr = TextEditingController();
  final _staticPrefix = TextEditingController(text: '24');
  final _staticGw = TextEditingController();
  final _staticDns = TextEditingController();

  StreamSubscription<EthAdminState>? _adminSub;
  StreamSubscription<EthLinkState>? _linkSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _admin = widget.controller.currentAdmin;
    _link = widget.controller.currentLink;
    _adminSub = widget.controller.admin.listen((s) {
      if (mounted) {
        setState(() => _admin = s);
      }
    });
    _linkSub = widget.controller.link.listen((s) {
      if (mounted) {
        setState(() => _link = s);
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
    unawaited(_adminSub?.cancel() ?? Future<void>.value());
    unawaited(_linkSub?.cancel() ?? Future<void>.value());
    _staticAddr.dispose();
    _staticPrefix.dispose();
    _staticGw.dispose();
    _staticDns.dispose();
    super.dispose();
  }

  String _statusLine() {
    final parts = <String>[_link.phase.name];
    if (_link.ipv4 != null && _link.ipv4!.isNotEmpty) {
      final pref = _link.prefixLength != null ? '/${_link.prefixLength}' : '';
      parts.add('${_link.ipv4}$pref');
    }
    if (_link.mac != null && _link.mac!.isNotEmpty) {
      parts.add(_link.mac!);
    }
    if (_link.speedMbps != null && _link.speedMbps! > 0) {
      parts.add('${_link.speedMbps} Mbps');
    }
    if (_link.message != null && _link.message!.isNotEmpty) {
      parts.add(_link.message!);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ifaceOn = _admin == EthAdminState.on;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ethernet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'RJ45 / ${widget.controller.interfaceName} bring-up (IPC camera addressing is P5.1)',
          style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'Admin: ${_admin.name}',
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
        ),
        Text(
          'Link: ${_statusLine()}',
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
        ),
        if (_busy != null)
          Text('Busy: $_busy', style: const TextStyle(color: Colors.amber)),
        if (_error != null)
          Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Interface', style: TextStyle(color: Colors.white)),
          value: ifaceOn || _admin == EthAdminState.starting,
          onChanged: _busy != null
              ? null
              : (v) {
                  if (DemoScrollInteraction.isScrollingOf(context)) {
                    return;
                  }
                  unawaited(
                    _guard(
                      'iface',
                      () => widget.controller.setInterfaceEnabled(v),
                    ),
                  );
                },
        ),
        const SizedBox(height: 8),
        const Text(
          'IPv4 mode (eth0)',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        SegmentedButton<EthIpv4Mode>(
          segments: const [
            ButtonSegment(value: EthIpv4Mode.dhcp, label: Text('DHCP')),
            ButtonSegment(
              value: EthIpv4Mode.staticMode,
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
        if (_ipv4.mode == EthIpv4Mode.staticMode) ...[
          _field(_staticAddr, 'Address'),
          _field(_staticPrefix, 'Prefix'),
          _field(_staticGw, 'Gateway'),
          _field(_staticDns, 'DNS'),
        ],
        FilledButton(
          onPressed: _busy != null
              ? null
              : () => unawaited(_guard('ipv4', () async {
                    final cfg = _ipv4.mode == EthIpv4Mode.dhcp
                        ? EthIpv4Config.dhcpDefault
                        : EthIpv4Config(
                            mode: EthIpv4Mode.staticMode,
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

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: c,
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
