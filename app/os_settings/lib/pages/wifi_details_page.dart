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

/// Wi‑Fi Details — Auto Join / IPv4 / DNS / others (inline edit).
class WifiDetailsPage extends StatefulWidget {
  const WifiDetailsPage({super.key});

  @override
  State<WifiDetailsPage> createState() => _WifiDetailsPageState();
}

class _WifiDetailsPageState extends State<WifiDetailsPage> {
  static const _maxDnsServers = 3;

  WifiConnectionState _conn = WifiConnectionState.disconnected;
  WlanIpv4Config _ipv4 = WlanIpv4Config.dhcpDefault;
  bool _autoJoin = true;
  bool _busy = false;
  String? _error;
  StreamSubscription<WifiConnectionState>? _sub;

  WifiController get _wifi => OsSettingsScope.of(context).wifi();

  @override
  void initState() {
    super.initState();
    _conn = _wifi.currentConnection;
    _sub = _wifi.connection.listen((c) {
      if (mounted) setState(() => _conn = c);
    });
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final details = await _wifi.linkDetails();
      final cfg = await _wifi.getIpv4Config();
      var autoJoin = true;
      final ssid = details.ssid;
      if (ssid != null && ssid.isNotEmpty) {
        try {
          final saved = await _wifi.savedNetworks();
          final match = saved.where((n) => n.ssid == ssid);
          if (match.isNotEmpty) {
            autoJoin = match.first.autoJoin;
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _conn = details;
        _ipv4 = cfg;
        _autoJoin = autoJoin;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  String _dash(String? value) {
    if (value == null || value.isEmpty) return '—';
    return value;
  }

  String _subnetMaskDisplay() {
    if (_ipv4.mode == WlanIpv4Mode.staticMode && _ipv4.prefixLength >= 0) {
      return WifiLinkParse.ipv4PrefixToSubnetMask(_ipv4.prefixLength) ??
          '${_ipv4.prefixLength}';
    }
    final mask = WifiLinkParse.ipv4PrefixToSubnetMask(_conn.prefixLength);
    if (mask == null || mask.isEmpty) {
      return '—';
    }
    return mask;
  }

  String _ipAddressDisplay() {
    if (_ipv4.mode == WlanIpv4Mode.staticMode && _ipv4.address.isNotEmpty) {
      return _ipv4.address;
    }
    return _dash(_conn.ipv4);
  }

  String _ipAddressEditValue() {
    if (_ipv4.address.isNotEmpty) return _ipv4.address;
    return _conn.ipv4 ?? '';
  }

  String _gatewayDisplay() {
    if (_ipv4.mode == WlanIpv4Mode.staticMode && _ipv4.gateway.isNotEmpty) {
      return _ipv4.gateway;
    }
    return _dash(_conn.gateway);
  }

  String _gatewayEditValue() {
    if (_ipv4.gateway.isNotEmpty) return _ipv4.gateway;
    return _conn.gateway ?? '';
  }

  String _subnetMaskEditValue() {
    final prefix = _ipv4.mode == WlanIpv4Mode.staticMode
        ? _ipv4.prefixLength
        : (_conn.prefixLength ?? _ipv4.prefixLength);
    return WifiLinkParse.ipv4PrefixToSubnetMask(prefix) ?? '$prefix';
  }

  String _signal() {
    final dbm = _conn.signalDbm;
    if (dbm == null) return '—';
    return '$dbm dBm';
  }

  String _frequency() {
    final mhz = _conn.frequencyMhz;
    if (mhz == null) return '—';
    final band = mhz >= 5000 ? '5 GHz' : '2.4 GHz';
    return '$mhz MHz ($band)';
  }

  String _linkSpeed() {
    final speed = _conn.linkSpeedMbps;
    if (speed == null) return '—';
    return '$speed Mbps';
  }

  String _security() {
    final s = _conn.security;
    if (s == null || s.isEmpty) return '—';
    return s;
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAutoJoin(bool enabled) async {
    final ssid = _conn.ssid;
    if (ssid == null || ssid.isEmpty) return;
    await _run(() => _wifi.setAutoJoin(ssid, enabled: enabled));
  }

  Future<void> _setIpMode({required bool automatic}) async {
    await _run(() async {
      final mode = automatic ? WlanIpv4Mode.dhcp : WlanIpv4Mode.staticMode;
      var next = _ipv4.copyWith(mode: mode);
      if (mode == WlanIpv4Mode.staticMode) {
        final liveAddr = _conn.ipv4 ?? '';
        final liveGw = _conn.gateway ?? '';
        final livePrefix = _conn.prefixLength;
        final seeding = next.address.isEmpty;
        next = next.copyWith(
          address: seeding ? liveAddr : next.address,
          gateway: next.gateway.isNotEmpty ? next.gateway : liveGw,
          prefixLength: seeding
              ? (livePrefix ?? next.prefixLength)
              : next.prefixLength,
        );
      }
      await _wifi.setIpv4Config(next);
    });
  }

  Future<void> _setDnsMode({required bool automatic}) async {
    await _run(() async {
      final next = _ipv4.copyWith(
        dnsMode: automatic ? WlanDnsMode.automatic : WlanDnsMode.manual,
        dnsServers: automatic ? const [] : _ipv4.dnsServers,
      );
      await _wifi.setIpv4Config(next);
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
      mode: WlanIpv4Mode.staticMode,
      address: address ?? _ipv4.address,
      prefixLength: prefixLength ?? _ipv4.prefixLength,
      gateway: gateway ?? _ipv4.gateway,
    );
    await _wifi.setIpv4Config(next);
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
      await _wifi.setIpv4Config(
        _ipv4.copyWith(
          dnsMode: WlanDnsMode.manual,
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
      await _wifi.setIpv4Config(
        _ipv4.copyWith(
          dnsMode: WlanDnsMode.manual,
          dnsServers: servers,
        ),
      );
    });
  }

  Future<void> _removeDnsServer(int index) async {
    await _run(() async {
      final servers = [..._ipv4.dnsServers]..removeAt(index);
      await _wifi.setIpv4Config(
        _ipv4.copyWith(
          dnsMode: WlanDnsMode.manual,
          dnsServers: servers,
        ),
      );
    });
  }

  Future<void> _forget() async {
    final l10n = AppLocalizations.of(context)!;
    final ssid = _conn.ssid;
    if (ssid == null || ssid.isEmpty) return;
    final ok = await showCyberDialog<bool>(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.wifiForgetNetwork,
              style: const TextStyle(color: CyberColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.wifiForgetConfirm,
              style: const TextStyle(color: CyberColors.textSecondary),
            ),
            const SizedBox(height: 20),
            CyberButton(
              child: Text(l10n.wifiForgetNetwork),
              size: CyberButtonSize.medium,
              stretch: true,
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 8),
            CyberButton(
              child: Text(l10n.cancelText),
              size: CyberButtonSize.medium,
              stretch: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await _wifi.forget(ssid);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = (_conn.ssid != null && _conn.ssid!.isNotEmpty)
        ? _conn.ssid!
        : l10n.wifiDetails;
    final manualIp = _ipv4.mode == WlanIpv4Mode.staticMode;
    final manualDns = _ipv4.dnsMode == WlanDnsMode.manual;
    final liveDns = (_conn.dns == null || _conn.dns!.isEmpty)
        ? null
        : WlanIpv4Config.splitDnsServers(_conn.dns!);

    return SettingsScaffold(
      title: title,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsSwitchRow(
                title: l10n.wifiAutoJoin,
                value: _autoJoin,
                onChanged: _busy
                    ? null
                    : (v) => unawaited(_setAutoJoin(v)),
              ),
            ],
          ),
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
            children: [
              SettingsValueRow(
                title: 'Security',
                value: _security(),
              ),
              SettingsValueRow(
                title: 'Signal Strength',
                value: _signal(),
              ),
              SettingsValueRow(
                title: l10n.wifiLinkSpeed,
                value: _linkSpeed(),
              ),
              SettingsValueRow(
                title: 'Frequency',
                value: _frequency(),
              ),
              SettingsValueRow(
                title: l10n.wifiMacAddress,
                value: _dash(_conn.macAddress),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: CyberButton(
              key: const Key('wifi-forget-network'),
              child: Text(l10n.wifiForgetNetwork),
              size: CyberButtonSize.medium,
              stretch: true,
              variant: CyberButtonVariant.secondary,
              onPressed: _busy ? null : () => unawaited(_forget()),
            ),
          ),
        ],
      ),
    );
  }
}
