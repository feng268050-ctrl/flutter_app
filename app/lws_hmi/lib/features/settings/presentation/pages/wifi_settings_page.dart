import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/pages/wifi_details_page.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// Wireless Network — switch + connected + My Networks + Other Networks.
class WifiSettingsPage extends StatefulWidget {
  const WifiSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<WifiSettingsPage> createState() => _WifiSettingsPageState();
}

class _WifiSettingsPageState extends State<WifiSettingsPage> {
  /// Linux has no Android-style scan throttle; refresh often enough for UX.
  static const _scanInterval = Duration(seconds: 15);

  late WifiRadioState _radio = widget.services.wifi.currentRadio;
  late WifiConnectionState _conn = widget.services.wifi.currentConnection;
  List<WifiAccessPoint> _scanned = const [];
  List<WifiSavedNetwork> _saved = const [];
  String? _busy;
  String? _error;
  Timer? _scanTimer;

  StreamSubscription<WifiRadioState>? _radioSub;
  StreamSubscription<WifiConnectionState>? _connSub;

  WifiController get _wifi => widget.services.wifi;

  @override
  void initState() {
    super.initState();
    _radioSub = _wifi.radio.listen((s) {
      if (!mounted) return;
      final prev = _radio;
      setState(() => _radio = s);
      _syncScanTimer();
      if (s != WifiRadioState.on && s != WifiRadioState.starting) {
        setState(() {
          _scanned = const [];
          _saved = const [];
        });
      } else if (s == WifiRadioState.on && prev != WifiRadioState.on) {
        // Covers syncFromSystem / external radio-up (not nested in _guard).
        unawaited(_scan(retries: 3));
      }
    });
    _connSub = _wifi.connection.listen((c) {
      if (mounted) setState(() => _conn = c);
    });
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _wifi.syncFromSystem();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _radio = _wifi.currentRadio;
      _conn = _wifi.currentConnection;
    });
    _syncScanTimer();
    if (_radioOn) {
      unawaited(_scan(retries: 3));
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    unawaited(_radioSub?.cancel() ?? Future<void>.value());
    unawaited(_connSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  void deactivate() {
    // Pause scans while this route is covered or popping — avoids setState /
    // HAL work during the Cupertino exit slide.
    _scanTimer?.cancel();
    _scanTimer = null;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (mounted) {
      _syncScanTimer();
    }
  }

  bool get _radioOn =>
      _radio == WifiRadioState.on || _radio == WifiRadioState.starting;

  void _syncScanTimer() {
    _scanTimer?.cancel();
    _scanTimer = null;
    if (!_radioOn) return;
    _scanTimer = Timer.periodic(_scanInterval, (_) {
      if (mounted && _busy == null) unawaited(_scan());
    });
  }

  Future<void> _guard(Future<void> Function() fn) async {
    setState(() {
      _busy = '…';
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _scan({int retries = 1, bool managed = true}) async {
    if (managed) {
      if (_busy != null) return;
      await _guard(() => _scanBody(retries: retries));
    } else {
      await _scanBody(retries: retries);
    }
  }

  Future<void> _scanBody({required int retries}) async {
    List<WifiAccessPoint> aps = const [];
    for (var i = 0; i < retries; i++) {
      aps = await _wifi.scan();
      if (aps.isNotEmpty) break;
      if (i < retries - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    List<WifiSavedNetwork> saved = const [];
    try {
      saved = await _wifi.savedNetworks();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      // Keep last good list on a transient empty result so the UI does not
      // flash “No networks found” after a failed rescan.
      if (aps.isNotEmpty || _scanned.isEmpty) {
        _scanned = aps;
      }
      _saved = saved;
    });
  }

  IconData _signalIcon(int? dbm) {
    final s = dbm ?? -100;
    if (s >= -55) return Icons.wifi;
    if (s >= -70) return Icons.wifi_2_bar;
    return Icons.wifi_1_bar;
  }

  bool _connSecured() {
    final s = _conn.security;
    if (s == null || s.isEmpty) return true;
    final u = s.toUpperCase();
    if (u.contains('OPEN') || u == 'NONE') return false;
    return true;
  }

  Future<void> _openDetails() async {
    await pushSettingsPage(
      context,
      WifiDetailsPage(services: widget.services),
    );
    if (mounted && _radioOn) {
      unawaited(_scan(retries: 1));
    }
  }

  Future<void> _tapNetwork(WifiAccessPoint ap, {required bool fromSaved}) async {
    if (_conn.isAssociated && _conn.ssid == ap.ssid) {
      await _openDetails();
      return;
    }
    if (fromSaved) {
      await _connectSaved(ap.ssid);
      return;
    }
    if (ap.isOpen) {
      await _connectWithProgress(ssid: ap.ssid, psk: null);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final psk = await showCyberImeInputDialog(
      context: context,
      title: ap.ssid,
      fieldType: CyberImeFieldType.wifi,
      label: l10n.wifiDialogPasswordLabel,
      hint: l10n.wifiDialogPasswordLabel,
      obscureText: true,
      confirmLabel: l10n.confirmText,
      requireNonEmpty: true,
      emptyErrorText: l10n.wifiToastPasswordRequired,
    );
    if (psk == null || !mounted) return;
    await _connectWithProgress(ssid: ap.ssid, psk: psk);
  }

  Future<void> _connectSaved(String ssid) async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      await showCyberBusyDialog<void>(
        context: context,
        title: AppLocalizations.of(context)!.wifiStatusConnecting,
        work: () async {
          final ok = await _wifi.selectSaved(ssid);
          if (!ok) {
            throw StateError('saved network not found');
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      WifiAccessPoint? match;
      for (final ap in _scanned) {
        if (ap.ssid == ssid) {
          match = ap;
          break;
        }
      }
      final secured = match?.secured ?? true;
      if (!secured) {
        await _connectWithProgress(ssid: ssid, psk: null);
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      final psk = await showCyberImeInputDialog(
        context: context,
        title: ssid,
        fieldType: CyberImeFieldType.wifi,
        label: l10n.wifiDialogPasswordLabel,
        hint: l10n.wifiDialogPasswordLabel,
        obscureText: true,
        confirmLabel: l10n.confirmText,
        requireNonEmpty: true,
        emptyErrorText: l10n.wifiToastPasswordRequired,
      );
      if (psk == null || !mounted) return;
      await _connectWithProgress(ssid: ssid, psk: psk);
    }
  }

  Future<void> _connectWithProgress({
    required String ssid,
    String? psk,
    bool hidden = false,
  }) async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      await showCyberBusyDialog<void>(
        context: context,
        title: AppLocalizations.of(context)!.wifiStatusConnecting,
        work: () async {
          await _wifi.connect(
            ssid: ssid,
            psk: psk,
            hidden: hidden,
            requiresPsk: psk != null,
          );
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _joinHidden() async {
    final l10n = AppLocalizations.of(context)!;
    final ssidCtrl = TextEditingController();
    final pskCtrl = TextEditingController();
    final ime = CyberImeSession.shared;
    final ok = await showCyberImeFormDialog(
      context: context,
      title: l10n.wifiHiddenNetworkTitle,
      confirmLabel: l10n.confirmText,
      session: ime,
      fields: [
        CyberImeTextField(
          fieldType: CyberImeFieldType.text,
          controller: ssidCtrl,
          session: ime,
          decoration: InputDecoration(
            labelText: l10n.wifiDialogSsidLabel,
            labelStyle: const TextStyle(color: CyberColors.textSecondary),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: CyberColors.textSecondary),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: CyberColors.textPrimary),
            ),
          ),
          style: const TextStyle(color: CyberColors.textPrimary),
        ),
        CyberImeTextField(
          fieldType: CyberImeFieldType.wifi,
          controller: pskCtrl,
          obscureText: true,
          session: ime,
          decoration: InputDecoration(
            labelText: l10n.wifiDialogPasswordLabel,
            labelStyle: const TextStyle(color: CyberColors.textSecondary),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: CyberColors.textSecondary),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: CyberColors.textPrimary),
            ),
          ),
          style: const TextStyle(color: CyberColors.textPrimary),
        ),
      ],
    );
    if (ok != true || !mounted) {
      ssidCtrl.dispose();
      pskCtrl.dispose();
      return;
    }
    final ssid = ssidCtrl.text.trim();
    final psk = pskCtrl.text;
    ssidCtrl.dispose();
    pskCtrl.dispose();
    if (ssid.isEmpty) return;
    await _connectWithProgress(
      ssid: ssid,
      psk: psk.isEmpty ? null : psk,
      hidden: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connected =
        _conn.isAssociated && _conn.ssid != null && _conn.ssid!.isNotEmpty;
    final parts = WifiApList.partitionMyAndOther(
      saved: _saved,
      scanned: _scanned,
      connectedSsid: connected ? _conn.ssid : null,
    );
    final my = parts.myNetworks;
    final other = parts.otherNetworks.take(20).toList();

    return SettingsScaffold(
      // lws-ui `wifi_network_text` (activity_wifi title)
      title: l10n.wifiNetworkText,
      body: RefreshIndicator(
        color: CyberColors.buttonPrimaryAccent,
        onRefresh: () async {
          if (!_radioOn) return;
          await _scan(retries: 3);
        },
        child: SettingsScrollView(
          children: [
            SettingsGroup(
              borderGradientCenter:
                  CyberBorderGradientCenter.topLeftBottomRight,
              children: [
                SettingsSwitchRow(
                  title: l10n.wifiWlanLabel,
                  value: _radioOn,
                  onChanged: _busy != null
                      ? null
                      : (v) => unawaited(
                            _guard(() async {
                              await _wifi.setRadioEnabled(v);
                              if (v) await _scan(retries: 3, managed: false);
                            }),
                          ),
                ),
                if (connected)
                  _WifiNetworkRow(
                    ssid: _conn.ssid!,
                    secured: _connSecured(),
                    showConnectedBadge: true,
                    signalIcon: _signalIcon(_conn.signalDbm),
                    onTap: () => unawaited(_openDetails()),
                  )
                else if (_radioOn)
                  SettingsValueRow(
                    title: l10n.notConnected,
                    value: null,
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (_radioOn) ...[
              SettingsSectionHeader(l10n.wifiMyNetworks),
              SettingsGroup(
                borderGradientCenter:
                    CyberBorderGradientCenter.bottomLeftTopRight,
                children: [
                  if (my.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Text(
                        l10n.wifiNoSavedNetworks,
                        style: context.hmiTypography.body.copyWith(
                          color: CyberColors.textPrimary,
                        ),
                      ),
                    )
                  else
                    for (final ap in my)
                      _WifiNetworkRow(
                        ssid: ap.ssid,
                        secured: ap.secured,
                        showConnectedBadge: false,
                        signalIcon: _signalIcon(ap.signalDbm),
                        onTap: _busy != null
                            ? null
                            : () => unawaited(
                                  _tapNetwork(ap, fromSaved: true),
                                ),
                      ),
                ],
              ),
              SettingsSectionHeader(l10n.wifiOtherNetworks),
              SettingsGroup(
                borderGradientCenter: CyberBorderGradientCenter.topBottom,
                children: [
                  if (_busy != null && other.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Text(
                        l10n.wifiScanning,
                        style: context.hmiTypography.body.copyWith(
                          color: CyberColors.textPrimary,
                        ),
                      ),
                    )
                  else if (other.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Text(
                        l10n.wifiNoOtherNetworks,
                        style: context.hmiTypography.body.copyWith(
                          color: CyberColors.textPrimary,
                        ),
                      ),
                    )
                  else
                    for (final ap in other)
                      _WifiNetworkRow(
                        ssid: ap.ssid,
                        secured: !ap.isOpen,
                        showConnectedBadge: false,
                        signalIcon: _signalIcon(ap.signalDbm),
                        onTap: _busy != null
                            ? null
                            : () => unawaited(
                                  _tapNetwork(ap, fromSaved: false),
                                ),
                      ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SettingsDimens.inset,
                  0,
                  SettingsDimens.inset,
                  SettingsDimens.inset,
                ),
                child: Center(
                  child: HmiButton(
                    label: l10n.wifiHiddenNetworkConnect,
                    size: HmiButtonSize.medium,
                    // Flat 1px rim — same opacity as home quick-action tiles.
                    strokeWidth: 1,
                    borderGradientCenter: CyberBorderGradientCenter.uniform,
                    borderColor: const Color(0x4DFFFFFF),
                    onPressed: _busy != null
                        ? null
                        : () => unawaited(_joinHidden()),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// SSID · optional connected badge · lock + signal — no chevron.
class _WifiNetworkRow extends StatelessWidget {
  const _WifiNetworkRow({
    required this.ssid,
    required this.secured,
    required this.showConnectedBadge,
    required this.signalIcon,
    this.onTap,
  });

  final String ssid;
  final bool secured;
  final bool showConnectedBadge;
  final IconData signalIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              CyberClickSoundRegistry.playClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ssid,
                overflow: TextOverflow.ellipsis,
                style: context.hmiTypography.body.copyWith(
                  color: CyberColors.textPrimary,
                ),
              ),
            ),
            if (showConnectedBadge) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                size: 22,
                color: CyberColors.buttonPrimaryAccent,
              ),
            ],
            const SizedBox(width: 12),
            if (secured) ...[
              const Icon(
                Icons.lock,
                size: 20,
                color: CyberColors.textSecondary,
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              signalIcon,
              size: 22,
              color: CyberColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
