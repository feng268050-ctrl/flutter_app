import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';

/// Wi‑Fi IP Settings — DHCP / Static (lws-ui WifiIpSettings parity).
class WifiIpSettingsPage extends StatefulWidget {
  const WifiIpSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<WifiIpSettingsPage> createState() => _WifiIpSettingsPageState();
}

class _WifiIpSettingsPageState extends State<WifiIpSettingsPage> {
  WlanIpv4Mode _mode = WlanIpv4Mode.dhcp;
  String _address = '';
  int _prefix = 24;
  String _gateway = '';
  String _dns = '';
  bool _busy = false;
  String? _error;

  WifiController get _wifi => widget.services.wifi;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final cfg = await _wifi.getIpv4Config();
      if (!mounted) return;
      setState(() {
        _mode = cfg.mode;
        _address = cfg.address;
        _prefix = cfg.prefixLength;
        _gateway = cfg.gateway;
        _dns = cfg.dns;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<String?> _editField({
    required String title,
    required String current,
    required ValueChanged<String> onSave,
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
    if (next == null || !mounted) return null;
    setState(() => onSave(next.trim()));
    return next;
  }

  Future<void> _apply(AppLocalizations l10n) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cfg = WlanIpv4Config(
        mode: _mode,
        address: _address,
        prefixLength: _prefix,
        gateway: _gateway,
        dns: _dns,
      );
      await _wifi.setIpv4Config(cfg);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _maskDisplay {
    return WifiLinkParse.ipv4PrefixToSubnetMask(_prefix) ?? '$_prefix';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final staticMode = _mode == WlanIpv4Mode.staticMode;

    return SettingsScaffold(
      title: l10n.wifiIpSettings,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            children: [
              SettingsControlRow(
                title: l10n.wifiIpMode,
                control: CyberSegmentedControl<WlanIpv4Mode>(
                  segments: [
                    ButtonSegment(
                      value: WlanIpv4Mode.dhcp,
                      label: Text(l10n.wifiIpModeDhcp),
                    ),
                    ButtonSegment(
                      value: WlanIpv4Mode.staticMode,
                      label: Text(l10n.wifiIpModeStatic),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _busy
                      ? (_) {}
                      : (s) {
                          if (s.isEmpty) return;
                          setState(() => _mode = s.first);
                        },
                ),
              ),
              if (staticMode) ...[
                SettingsNavRow(
                  title: l10n.wifiIpAddress,
                  value: _address.isEmpty ? l10n.unavailable : _address,
                  onTap: _busy
                      ? null
                      : () => unawaited(
                            _editField(
                              title: l10n.wifiIpAddress,
                              current: _address,
                              onSave: (v) => _address = v,
                            ),
                          ),
                ),
                SettingsNavRow(
                  title: l10n.wifiSubnetMask,
                  value: _maskDisplay,
                  onTap: _busy
                      ? null
                      : () => unawaited(
                            _editField(
                              title: l10n.wifiSubnetMask,
                              current: '$_prefix',
                              fieldType: CyberImeFieldType.number,
                              onSave: (v) {
                                final p = int.tryParse(v);
                                if (p != null && p >= 0 && p <= 32) {
                                  _prefix = p;
                                }
                              },
                            ),
                          ),
                ),
                SettingsNavRow(
                  title: l10n.wifiGateway,
                  value: _gateway.isEmpty ? l10n.unavailable : _gateway,
                  onTap: _busy
                      ? null
                      : () => unawaited(
                            _editField(
                              title: l10n.wifiGateway,
                              current: _gateway,
                              onSave: (v) => _gateway = v,
                            ),
                          ),
                ),
                SettingsNavRow(
                  title: l10n.wifiDns,
                  value: _dns.isEmpty ? l10n.unavailable : _dns,
                  onTap: _busy
                      ? null
                      : () => unawaited(
                            _editField(
                              title: l10n.wifiDns,
                              current: _dns,
                              onSave: (v) => _dns = v,
                            ),
                          ),
                ),
              ],
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: CyberButton(
              stretch: true,
              variant: CyberButtonVariant.primary,
              onPressed: _busy ? null : () => unawaited(_apply(l10n)),
              child: Text(l10n.confirmText),
            ),
          ),
        ],
      ),
    );
  }
}
