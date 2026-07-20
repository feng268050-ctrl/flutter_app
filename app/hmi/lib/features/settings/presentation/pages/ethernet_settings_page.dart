import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

/// Ethernet — phone-style settings (not Demo forms).
class EthernetSettingsPage extends StatefulWidget {
  const EthernetSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<EthernetSettingsPage> createState() => _EthernetSettingsPageState();
}

class _EthernetSettingsPageState extends State<EthernetSettingsPage> {
  late EthAdminState _admin = widget.services.ethernet.currentAdmin;
  late EthLinkState _link = widget.services.ethernet.currentLink;
  EthIpv4Config _ipv4 = EthIpv4Config.dhcpDefault;
  String? _error;
  bool _busy = false;

  StreamSubscription<EthAdminState>? _adminSub;
  StreamSubscription<EthLinkState>? _linkSub;

  @override
  void initState() {
    super.initState();
    final eth = widget.services.ethernet;
    _adminSub = eth.admin.listen((s) {
      if (mounted) setState(() => _admin = s);
    });
    _linkSub = eth.link.listen((s) {
      if (mounted) setState(() => _link = s);
    });
    unawaited(eth.syncFromSystem());
    unawaited(_loadIpv4());
  }

  Future<void> _loadIpv4() async {
    try {
      final c = await widget.services.ethernet.getIpv4Config();
      if (mounted) setState(() => _ipv4 = c);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
      await _loadIpv4();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_adminSub?.cancel() ?? Future<void>.value());
    unawaited(_linkSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = _admin == EthAdminState.on || _admin == EthAdminState.starting;
    return SettingsScaffold(
      title: 'Ethernet',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Ethernet'),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: 'Ethernet',
                value: on,
                onChanged: _busy
                    ? null
                    : (v) => unawaited(
                          _run(
                            () => widget.services.ethernet
                                .setInterfaceEnabled(v),
                          ),
                        ),
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: const Text('Link'),
                trailing: Text(
                  _link.phase.name,
                  style: TextStyle(color: Colors.white.withOpacity(0.55)),
                ),
              ),
              if (_ipv4.address.isNotEmpty)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  title: const Text('IP Address'),
                  trailing: Text(
                    _ipv4.address,
                    style: TextStyle(color: Colors.white.withOpacity(0.55)),
                  ),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SettingsSectionHeader('Configure IP'),
          SettingsGroup(
            children: [
              SettingsNavRow(
                title: 'DHCP',
                value: _ipv4.mode == EthIpv4Mode.dhcp ? 'Selected' : null,
                onTap: _busy
                    ? null
                    : () => unawaited(
                          _run(
                            () => widget.services.ethernet
                                .setIpv4Config(EthIpv4Config.dhcpDefault),
                          ),
                        ),
              ),
              SettingsNavRow(
                title: 'Manual',
                value:
                    _ipv4.mode == EthIpv4Mode.staticMode ? 'Selected' : null,
                onTap: _busy ? null : _editStatic,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editStatic() async {
    final addr = TextEditingController(text: _ipv4.address);
    final prefix = TextEditingController(text: '${_ipv4.prefixLength}');
    final gw = TextEditingController(text: _ipv4.gateway);
    final dns = TextEditingController(text: _ipv4.dns);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual IP'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: addr,
                decoration: const InputDecoration(labelText: 'IP Address'),
              ),
              TextField(
                controller: prefix,
                decoration: const InputDecoration(labelText: 'Prefix'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: gw,
                decoration: const InputDecoration(labelText: 'Router'),
              ),
              TextField(
                controller: dns,
                decoration: const InputDecoration(labelText: 'DNS'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              CyberClickSoundRegistry.playClick();
              Navigator.pop(ctx, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              CyberClickSoundRegistry.playClick();
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final p = int.tryParse(prefix.text.trim()) ?? 24;
    await _run(
      () => widget.services.ethernet.setIpv4Config(
        EthIpv4Config(
          mode: EthIpv4Mode.staticMode,
          address: addr.text.trim(),
          prefixLength: p,
          gateway: gw.text.trim(),
          dns: dns.text.trim(),
        ),
      ),
    );
  }
}
