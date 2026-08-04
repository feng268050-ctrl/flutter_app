import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

/// Wi‑Fi Details — Auto Join / IPv4 / DNS / others (inline edit).
class WifiDetailsPage extends StatefulWidget {
  const WifiDetailsPage({super.key, required this.services});

  final AppServices services;

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

  String _dash(AppLocalizations l10n, String? value) {
    if (value == null || value.isEmpty) return l10n.unavailable;
    return value;
  }

  String _subnetMaskDisplay(AppLocalizations l10n) {
    if (_ipv4.mode == WlanIpv4Mode.staticMode && _ipv4.prefixLength >= 0) {
      return WifiLinkParse.ipv4PrefixToSubnetMask(_ipv4.prefixLength) ??
          '${_ipv4.prefixLength}';
    }
    final mask = WifiLinkParse.ipv4PrefixToSubnetMask(_conn.prefixLength);
    if (mask == null || mask.isEmpty) {
      return l10n.unavailable;
    }
    return mask;
  }

  String _ipAddressDisplay(AppLocalizations l10n) {
    if (_ipv4.mode == WlanIpv4Mode.staticMode && _ipv4.address.isNotEmpty) {
      return _ipv4.address;
    }
    return _dash(l10n, _conn.ipv4);
  }

  /// Prefill for Manual IP edit: saved static value, else live link.
  String _ipAddressEditValue() {
    if (_ipv4.address.isNotEmpty) return _ipv4.address;
    return _conn.ipv4 ?? '';
  }

  String _gatewayDisplay(AppLocalizations l10n) {
    if (_ipv4.mode == WlanIpv4Mode.staticMode && _ipv4.gateway.isNotEmpty) {
      return _ipv4.gateway;
    }
    return _dash(l10n, _conn.gateway);
  }

  String _gatewayEditValue() {
    if (_ipv4.gateway.isNotEmpty) return _ipv4.gateway;
    return _conn.gateway ?? '';
  }

  /// Dotted mask matching the row, so the IME dialog shows the same value.
  String _subnetMaskEditValue() {
    final prefix = _ipv4.mode == WlanIpv4Mode.staticMode
        ? _ipv4.prefixLength
        : (_conn.prefixLength ?? _ipv4.prefixLength);
    return WifiLinkParse.ipv4PrefixToSubnetMask(prefix) ?? '$prefix';
  }

  int? _parsePrefixLength(String raw) {
    final t = raw.trim();
    final asInt = int.tryParse(t);
    if (asInt != null && asInt >= 0 && asInt <= 32) return asInt;
    final parts = t.split('.');
    if (parts.length != 4) return null;
    final octets = <int>[];
    for (final p in parts) {
      final o = int.tryParse(p);
      if (o == null || o < 0 || o > 255) return null;
      octets.add(o);
    }
    var mask = 0;
    for (final o in octets) {
      mask = (mask << 8) | o;
    }
    mask &= 0xFFFFFFFF;
    var prefix = 0;
    var bit = 0x80000000;
    while (prefix < 32 && (mask & bit) != 0) {
      prefix++;
      bit >>= 1;
    }
    // Reject non-contiguous masks (e.g. 255.0.255.0).
    final expected = prefix == 0
        ? 0
        : prefix == 32
            ? 0xFFFFFFFF
            : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    if (mask != expected) return null;
    return prefix;
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

  Future<void> _setIpMode(WlanIpv4Mode mode) async {
    await _run(() async {
      var next = _ipv4.copyWith(mode: mode);
      // Switching DHCP → Manual: seed empty static fields from the live link
      // so editors open with the values operators already see on the rows.
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

  Future<void> _setDnsMode(WlanDnsMode mode) async {
    await _run(() async {
      final next = _ipv4.copyWith(
        dnsMode: mode,
        dnsServers: mode == WlanDnsMode.automatic ? const [] : _ipv4.dnsServers,
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
    final next = await showCyberImeInputDialog(
      context: context,
      title: title,
      fieldType: fieldType,
      label: title,
      initial: current,
      confirmLabel: AppLocalizations.of(context)!.confirmText,
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

  Future<void> _addDnsServer(AppLocalizations l10n) async {
    if (_ipv4.dnsServers.length >= _maxDnsServers) {
      setState(() => _error = l10n.wifiMaxDnsServers);
      return;
    }
    final next = await showCyberImeInputDialog(
      context: context,
      title: l10n.wifiAddDnsServer,
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

  Future<void> _editDnsServer(int index, AppLocalizations l10n) async {
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
                fontSize: AppTypography.controlSize,
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
    final manualIp = _ipv4.mode == WlanIpv4Mode.staticMode;
    final manualDns = _ipv4.dnsMode == WlanDnsMode.manual;
    final liveDns = (_conn.dns == null || _conn.dns!.isEmpty)
        ? null
        : WlanIpv4Config.splitDnsServers(_conn.dns!);

    return SettingsScaffold(
      title: title,
      body: SettingsScrollView(
        children: [
          // Auto Join — no section header.
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
          SettingsSectionHeader(l10n.wifiIpv4AddressSection),
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              SettingsControlRow(
                title: l10n.wifiConfigureIp,
                control: CyberSegmentedControl<WlanIpv4Mode>(
                  segments: [
                    ButtonSegment(
                      value: WlanIpv4Mode.dhcp,
                      label: Text(l10n.wifiAutomatic),
                    ),
                    ButtonSegment(
                      value: WlanIpv4Mode.staticMode,
                      label: Text(l10n.wifiManual),
                    ),
                  ],
                  selected: {_ipv4.mode},
                  onSelectionChanged: _busy
                      ? (_) {}
                      : (s) {
                          if (s.isEmpty) return;
                          unawaited(_setIpMode(s.first));
                        },
                ),
              ),
              if (manualIp) ...[
                SettingsNavRow(
                  title: l10n.wifiIpAddress,
                  value: _ipAddressDisplay(l10n),
                  onTap: _busy
                      ? null
                      : () => unawaited(
                            _editField(
                              title: l10n.wifiIpAddress,
                              current: _ipAddressEditValue(),
                              onSave: (v) => _applyStaticFields(address: v),
                            ),
                          ),
                ),
                SettingsNavRow(
                  title: l10n.wifiSubnetMask,
                  value: _subnetMaskDisplay(l10n),
                  onTap: _busy
                      ? null
                      : () => unawaited(
                            _editField(
                              title: l10n.wifiSubnetMask,
                              current: _subnetMaskEditValue(),
                              onSave: (v) async {
                                final p = _parsePrefixLength(v);
                                if (p == null) {
                                  throw ArgumentError('invalid prefix');
                                }
                                await _applyStaticFields(prefixLength: p);
                              },
                            ),
                          ),
                ),
                SettingsNavRow(
                  title: l10n.wifiGateway,
                  value: _gatewayDisplay(l10n),
                  onTap: _busy
                      ? null
                      : () => unawaited(
                            _editField(
                              title: l10n.wifiGateway,
                              current: _gatewayEditValue(),
                              onSave: (v) => _applyStaticFields(gateway: v),
                            ),
                          ),
                ),
              ] else ...[
                SettingsValueRow(
                  title: l10n.wifiIpAddress,
                  value: _ipAddressDisplay(l10n),
                ),
                SettingsValueRow(
                  title: l10n.wifiSubnetMask,
                  value: _subnetMaskDisplay(l10n),
                ),
                SettingsValueRow(
                  title: l10n.wifiGateway,
                  value: _gatewayDisplay(l10n),
                ),
              ],
            ],
          ),
          SettingsSectionHeader(l10n.wifiDns),
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsControlRow(
                title: l10n.wifiConfigureDns,
                control: CyberSegmentedControl<WlanDnsMode>(
                  segments: [
                    ButtonSegment(
                      value: WlanDnsMode.automatic,
                      label: Text(l10n.wifiAutomatic),
                    ),
                    ButtonSegment(
                      value: WlanDnsMode.manual,
                      label: Text(l10n.wifiManual),
                    ),
                  ],
                  selected: {_ipv4.dnsMode},
                  onSelectionChanged: _busy
                      ? (_) {}
                      : (s) {
                          if (s.isEmpty) return;
                          unawaited(_setDnsMode(s.first));
                        },
                ),
              ),
              if (manualDns) ...[
                if (_ipv4.dnsServers.isEmpty)
                  SettingsValueRow(
                    title: l10n.wifiDnsServers,
                    value: l10n.unavailable,
                  )
                else
                  for (var i = 0; i < _ipv4.dnsServers.length; i++)
                    SettingsNavRow(
                      title: '${l10n.wifiDns} ${i + 1}',
                      value: _ipv4.dnsServers[i],
                      onTap: _busy
                          ? null
                          : () => unawaited(_editDnsServer(i, l10n)),
                    ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: IconButton(
                      tooltip: l10n.wifiAddDnsServer,
                      onPressed: _busy
                          ? null
                          : () => unawaited(_addDnsServer(l10n)),
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: CyberColors.buttonPrimaryAccent,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SettingsValueRow(
                  title: l10n.wifiDnsServers,
                  value: (liveDns == null || liveDns.isEmpty)
                      ? l10n.unavailable
                      : liveDns.join(', '),
                ),
              ],
            ],
          ),
          SettingsSectionHeader(l10n.wifiOthersSection),
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              SettingsValueRow(
                title: l10n.wifiSecurity,
                value: _security(l10n),
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
                title: l10n.wifiFrequency,
                value: _frequency(l10n),
              ),
              SettingsValueRow(
                title: l10n.wifiMacAddress,
                value: _dash(l10n, _conn.macAddress),
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
              stretch: true,
              variant: CyberButtonVariant.secondary,
              onPressed: _busy ? null : () => unawaited(_forget(l10n)),
              child: Text(l10n.wifiForgetNetwork),
            ),
          ),
        ],
      ),
    );
  }
}
