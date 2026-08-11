import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/chrome/settings_ipv4_dns_groups.dart';
import 'package:os_settings/l10n/app_localizations.dart';
import 'package:os_settings/ui/cyber_ime_input_dialog.dart';
import 'package:os_settings/util/os_settings_labels.dart';

/// Ethernet — toggle + cable link, then shared IPv4 / DNS groups (Wi‑Fi style).
class EthernetPage extends StatefulWidget {
  const EthernetPage({super.key});

  @override
  State<EthernetPage> createState() => _EthernetPageState();
}

class _EthernetPageState extends State<EthernetPage> {
  static const _maxDnsServers = 3;

  late EthAdminState _admin = OsSettingsScope.of(context).ethernet().currentAdmin;
  late EthLinkState _link = OsSettingsScope.of(context).ethernet().currentLink;
  EthIpv4Config _ipv4 = EthIpv4Config.dhcpDefault;
  String? _error;
  bool _busy = false;

  StreamSubscription<EthAdminState>? _adminSub;
  StreamSubscription<EthLinkState>? _linkSub;

  EthernetController get _eth => OsSettingsScope.of(context).ethernet();

  @override
  void initState() {
    super.initState();
    final eth = OsSettingsScope.of(context).ethernet();
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
      final c = await _eth.getIpv4Config();
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
      try {
        final link = await _eth.linkDetails();
        if (mounted) setState(() => _link = link);
      } catch (_) {}
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

  String _dash(String? value) {
    if (value == null || value.isEmpty) return '—';
    return value;
  }

  String _ipAddressDisplay() {
    if (_ipv4.mode == EthIpv4Mode.staticMode && _ipv4.address.isNotEmpty) {
      return _ipv4.address;
    }
    return _dash(_link.ipv4);
  }

  String _ipAddressEditValue() {
    if (_ipv4.address.isNotEmpty) return _ipv4.address;
    return _link.ipv4 ?? '';
  }

  String _subnetMaskDisplay() {
    if (_ipv4.mode == EthIpv4Mode.staticMode && _ipv4.prefixLength >= 0) {
      return WifiLinkParse.ipv4PrefixToSubnetMask(_ipv4.prefixLength) ??
          '${_ipv4.prefixLength}';
    }
    final mask = WifiLinkParse.ipv4PrefixToSubnetMask(_link.prefixLength);
    if (mask == null || mask.isEmpty) {
      return '—';
    }
    return mask;
  }

  String _subnetMaskEditValue() {
    final prefix = _ipv4.mode == EthIpv4Mode.staticMode
        ? _ipv4.prefixLength
        : (_link.prefixLength ?? _ipv4.prefixLength);
    return WifiLinkParse.ipv4PrefixToSubnetMask(prefix) ?? '$prefix';
  }

  String _gatewayDisplay() {
    if (_ipv4.mode == EthIpv4Mode.staticMode && _ipv4.gateway.isNotEmpty) {
      return _ipv4.gateway;
    }
    return _dash(_link.gateway);
  }

  String _gatewayEditValue() {
    if (_ipv4.gateway.isNotEmpty) return _ipv4.gateway;
    return _link.gateway ?? '';
  }

  Future<void> _setIpMode({required bool automatic}) async {
    await _run(() async {
      final mode = automatic ? EthIpv4Mode.dhcp : EthIpv4Mode.staticMode;
      var next = _ipv4.copyWith(mode: mode);
      if (mode == EthIpv4Mode.staticMode) {
        final liveAddr = _link.ipv4 ?? '';
        final liveGw = _link.gateway ?? '';
        final livePrefix = _link.prefixLength;
        final seeding = next.address.isEmpty;
        next = next.copyWith(
          address: seeding ? liveAddr : next.address,
          gateway: next.gateway.isNotEmpty ? next.gateway : liveGw,
          prefixLength: seeding
              ? (livePrefix ?? next.prefixLength)
              : next.prefixLength,
        );
      }
      await _eth.setIpv4Config(next);
    });
  }

  Future<void> _setDnsMode({required bool automatic}) async {
    await _run(() async {
      final next = _ipv4.copyWith(
        dnsMode: automatic ? EthDnsMode.automatic : EthDnsMode.manual,
        dnsServers:
            automatic ? const <String>[] : _ipv4.dnsServers,
      );
      await _eth.setIpv4Config(next);
    });
  }

  Future<void> _editField({
    required String title,
    required String current,
    required Future<void> Function(String value) onSave,
    CyberImeFieldType fieldType = CyberImeFieldType.text,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final next = await showCyberImeInputDialog(
      context: context,
      title: title,
      fieldType: fieldType,
      label: title,
      initial: current,
      confirmLabel: l10n.confirmText,
    );
    if (next == null || !mounted) return;
    await _run(() => onSave(next.trim()));
  }

  Future<void> _applyStaticFields({
    String? address,
    int? prefixLength,
    String? gateway,
  }) async {
    final next = _ipv4.copyWith(
      mode: EthIpv4Mode.staticMode,
      address: address ?? _ipv4.address,
      prefixLength: prefixLength ?? _ipv4.prefixLength,
      gateway: gateway ?? _ipv4.gateway,
    );
    await _eth.setIpv4Config(next);
  }

  Future<void> _addDnsServer() async {
    final l10n = AppLocalizations.of(context)!;
    if (_ipv4.dnsServers.length >= _maxDnsServers) {
      setState(() => _error = l10n.wifiDnsLimit);
      return;
    }
    final next = await showCyberImeInputDialog(
      context: context,
      title: l10n.wifiAddDns,
      fieldType: CyberImeFieldType.text,
      label: l10n.wifiDnsServers,
      confirmLabel: l10n.confirmText,
    );
    if (next == null || !mounted) return;
    final server = next.trim();
    if (server.isEmpty) return;
    await _run(() async {
      final servers = [..._ipv4.dnsServers, server];
      await _eth.setIpv4Config(
        _ipv4.copyWith(
          dnsMode: EthDnsMode.manual,
          dnsServers: servers,
        ),
      );
    });
  }

  Future<void> _editDnsServer(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final current = _ipv4.dnsServers[index];
    final next = await showCyberImeInputDialog(
      context: context,
      title: '${l10n.wifiDns} ${index + 1}',
      fieldType: CyberImeFieldType.text,
      label: l10n.wifiDnsServers,
      initial: current,
      confirmLabel: l10n.confirmText,
    );
    if (next == null || !mounted) return;
    final server = next.trim();
    if (server.isEmpty) {
      await _removeDnsServer(index);
      return;
    }
    await _run(() async {
      final servers = [..._ipv4.dnsServers];
      servers[index] = server;
      await _eth.setIpv4Config(
        _ipv4.copyWith(
          dnsMode: EthDnsMode.manual,
          dnsServers: servers,
        ),
      );
    });
  }

  Future<void> _removeDnsServer(int index) async {
    await _run(() async {
      final servers = [..._ipv4.dnsServers]..removeAt(index);
      await _eth.setIpv4Config(
        _ipv4.copyWith(
          dnsMode: EthDnsMode.manual,
          dnsServers: servers,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final on = _admin == EthAdminState.on || _admin == EthAdminState.starting;
    final manualIp = _ipv4.mode == EthIpv4Mode.staticMode;
    final manualDns = _ipv4.dnsMode == EthDnsMode.manual;
    final liveDns = (_link.dns == null || _link.dns!.isEmpty)
        ? null
        : EthIpv4Config.splitDnsServers(_link.dns!);

    return SettingsScaffold(
      title: l10n.ethernetText,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsSwitchRow(
                title: l10n.ethernetText,
                value: on,
                onChanged: _busy
                    ? null
                    : (v) => unawaited(
                          _run(() => _eth.setInterfaceEnabled(v)),
                        ),
              ),
              if (on)
                SettingsValueRow(
                  title: l10n.ethernetCableLink,
                  value: ethernetLinkPhaseLabel(l10n, _link.phase),
                ),
            ],
          ),
          if (on) ...[
            SettingsIpv4DnsGroups(
              busy: _busy,
              manualIp: manualIp,
              manualDns: manualDns,
              ipv4SectionTitle: l10n.wifiIpv4AddressSection,
              configureIpTitle: l10n.wifiConfigureIp,
              configureDnsTitle: l10n.wifiConfigureDns,
              dnsSectionTitle: l10n.wifiDns,
              automaticLabel: l10n.wifiAutomatic,
              manualLabel: l10n.wifiManual,
              ipAddressTitle: l10n.wifiIpAddress,
              subnetMaskTitle: l10n.wifiSubnetMask,
              gatewayTitle: l10n.wifiGateway,
              dnsServersTitle: l10n.wifiDnsServers,
              dnsServerTitle: l10n.wifiDns,
              addDnsTooltip: l10n.wifiAddDns,
              unavailable: '—',
              ipAddress: _ipAddressDisplay(),
              subnetMask: _subnetMaskDisplay(),
              gateway: _gatewayDisplay(),
              automaticDnsDisplay: (liveDns == null || liveDns.isEmpty)
                  ? '—'
                  : liveDns.join(', '),
              manualDnsServers: _ipv4.dnsServers,
              onIpModeChanged: (automatic) =>
                  unawaited(_setIpMode(automatic: automatic)),
              onDnsModeChanged: (automatic) =>
                  unawaited(_setDnsMode(automatic: automatic)),
              onEditIpAddress: () => unawaited(
                    _editField(
                      title: l10n.wifiIpAddress,
                      current: _ipAddressEditValue(),
                      onSave: (v) => _applyStaticFields(address: v),
                    ),
                  ),
              onEditSubnetMask: () => unawaited(
                    _editField(
                      title: l10n.wifiSubnetMask,
                      current: _subnetMaskEditValue(),
                      onSave: (v) async {
                        final p = parseIpv4PrefixLength(v);
                        if (p == null) {
                          throw ArgumentError('invalid prefix');
                        }
                        await _applyStaticFields(prefixLength: p);
                      },
                    ),
                  ),
              onEditGateway: () => unawaited(
                    _editField(
                      title: l10n.wifiGateway,
                      current: _gatewayEditValue(),
                      onSave: (v) => _applyStaticFields(gateway: v),
                    ),
                  ),
              onAddDnsServer: () => unawaited(_addDnsServer()),
              onEditDnsServer: (i) => unawaited(_editDnsServer(i)),
            ),
            SettingsSectionHeader(l10n.wifiOthersSection),
            SettingsGroup(
              borderGradientCenter:
                  CyberBorderGradientCenter.bottomLeftTopRight,
              bottomInset: 0,
              children: [
                SettingsValueRow(
                  title: l10n.wifiMacAddress,
                  value: _dash(_link.mac),
                ),
                SettingsValueRow(
                  title: l10n.wifiLinkSpeed,
                  value: _link.speedMbps == null
                      ? '—'
                      : l10n.ethernetSpeedMbps(_link.speedMbps!),
                ),
              ],
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }
}
