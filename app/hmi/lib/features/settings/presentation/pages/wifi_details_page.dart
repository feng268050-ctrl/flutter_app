import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/pages/wifi_ip_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Wi‑Fi connected-hotspot Details (lws-ui WifiDetails parity).
class WifiDetailsPage extends StatefulWidget {
  const WifiDetailsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<WifiDetailsPage> createState() => _WifiDetailsPageState();
}

class _WifiDetailsPageState extends State<WifiDetailsPage> {
  WifiConnectionState _conn = WifiConnectionState.disconnected;
  WlanIpv4Config _ipv4 = WlanIpv4Config.dhcpDefault;
  StreamSubscription<WifiConnectionState>? _sub;

  WifiController get _wifi => widget.services.wifi;

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
      if (!mounted) return;
      setState(() {
        _conn = details;
        _ipv4 = cfg;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  String _dash(AppLocalizations l10n, String? value) {
    if (value == null || value.isEmpty) return l10n.unavailable;
    return value;
  }

  String _subnetMask(AppLocalizations l10n) {
    final mask = WifiLinkParse.ipv4PrefixToSubnetMask(_conn.prefixLength);
    if (mask == null || mask.isEmpty) {
      return l10n.unavailable;
    }
    return mask;
  }

  String _ipMode(AppLocalizations l10n) {
    return _ipv4.mode == WlanIpv4Mode.staticMode
        ? l10n.wifiIpModeStatic
        : l10n.wifiIpModeDhcp;
  }

  String _signal(AppLocalizations l10n) {
    final dbm = _conn.signalDbm;
    if (dbm == null) return l10n.unavailable;
    return '$dbm dBm';
  }

  String _frequency(AppLocalizations l10n) {
    final mhz = _conn.frequencyMhz;
    if (mhz == null) return l10n.unavailable;
    final band = mhz >= 5000 ? '5 GHz' : '2.4 GHz';
    return '$mhz MHz ($band)';
  }

  String _linkSpeed(AppLocalizations l10n) {
    final speed = _conn.linkSpeedMbps;
    if (speed == null) return l10n.unavailable;
    return '$speed Mbps';
  }

  String _security(AppLocalizations l10n) {
    final s = _conn.security;
    if (s == null || s.isEmpty) return l10n.unavailable;
    return s;
  }

  String _mac(AppLocalizations l10n) => _dash(l10n, _conn.macAddress);

  Future<void> _forget(AppLocalizations l10n) async {
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
              style: const TextStyle(
                fontSize: 20,
                color: CyberColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.wifiForgetConfirmMessage,
              style: const TextStyle(color: CyberColors.textSecondary),
            ),
            const SizedBox(height: 20),
            CyberButton(
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.wifiForgetNetwork),
            ),
            const SizedBox(height: 8),
            CyberButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancelText),
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
        : l10n.wifiDetailsTitle;

    return SettingsScaffold(
      title: title,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            children: [
              SettingsValueRow(title: l10n.wifiIpMode, value: _ipMode(l10n)),
              SettingsValueRow(
                title: l10n.wifiIpAddress,
                value: _dash(l10n, _conn.ipv4),
              ),
              SettingsValueRow(
                title: l10n.wifiSubnetMask,
                value: _subnetMask(l10n),
              ),
              SettingsValueRow(
                title: l10n.wifiGateway,
                value: _dash(l10n, _conn.gateway),
              ),
              SettingsValueRow(
                title: l10n.wifiDns,
                value: _dash(l10n, _conn.dns),
              ),
              SettingsValueRow(
                title: l10n.wifiSignalStrength,
                value: _signal(l10n),
              ),
              SettingsValueRow(
                title: l10n.wifiLinkSpeed,
                value: _linkSpeed(l10n),
              ),
              SettingsValueRow(
                title: l10n.wifiSecurity,
                value: _security(l10n),
              ),
              SettingsValueRow(
                title: l10n.wifiFrequency,
                value: _frequency(l10n),
              ),
              SettingsValueRow(
                title: l10n.wifiMacAddress,
                value: _mac(l10n),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: CyberButton(
              stretch: true,
              onPressed: () async {
                await pushSettingsPage(
                  context,
                  WifiIpSettingsPage(services: widget.services),
                );
                await _refresh();
              },
              child: Text(l10n.wifiIpSettings),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: CyberButton(
              key: const Key('wifi-forget-network'),
              stretch: true,
              variant: CyberButtonVariant.secondary,
              onPressed: () => unawaited(_forget(l10n)),
              child: Text(l10n.wifiForgetNetwork),
            ),
          ),
        ],
      ),
    );
  }
}
