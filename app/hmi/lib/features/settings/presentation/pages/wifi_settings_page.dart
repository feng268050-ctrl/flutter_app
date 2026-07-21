import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';

/// Wireless Network — lws-ui / phone Settings style (not Demo forms).
class WifiSettingsPage extends StatefulWidget {
  const WifiSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<WifiSettingsPage> createState() => _WifiSettingsPageState();
}

class _WifiSettingsPageState extends State<WifiSettingsPage> {
  late WifiRadioState _radio = widget.services.wifi.currentRadio;
  late WifiConnectionState _conn = widget.services.wifi.currentConnection;
  List<WifiAccessPoint> _scanned = const [];
  String? _busy;
  String? _error;

  StreamSubscription<WifiRadioState>? _radioSub;
  StreamSubscription<WifiConnectionState>? _connSub;

  WifiController get _wifi => widget.services.wifi;

  @override
  void initState() {
    super.initState();
    _radioSub = _wifi.radio.listen((s) {
      if (mounted) setState(() => _radio = s);
    });
    _connSub = _wifi.connection.listen((c) {
      if (mounted) setState(() => _conn = c);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_radio == WifiRadioState.on) {
        unawaited(_scan());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_radioSub?.cancel() ?? Future<void>.value());
    unawaited(_connSub?.cancel() ?? Future<void>.value());
    super.dispose();
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

  Future<void> _scan() async {
    await _guard(() async {
      final aps = await _wifi.scan();
      if (mounted) setState(() => _scanned = aps);
    });
  }

  List<WifiAccessPoint> get _available => WifiApList.available(
        scanned: _scanned,
        connectedSsid: _radio == WifiRadioState.on && _conn.isAssociated
            ? _conn.ssid
            : null,
      );

  Future<void> _connectAp(WifiAccessPoint ap) async {
    if (ap.isOpen) {
      await _connectWithProgress(ssid: ap.ssid, psk: null);
      return;
    }
    final psk = await showCyberImeInputDialog(
      context: context,
      title: ap.ssid,
      fieldType: CyberImeFieldType.wifi,
      label: 'Password',
      hint: 'Enter password',
      obscureText: true,
      confirmLabel: 'Join',
      requireNonEmpty: true,
      emptyErrorText: 'Password required',
    );
    if (psk == null || !mounted) return;
    await _connectWithProgress(ssid: ap.ssid, psk: psk);
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
        title: 'Connecting…',
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
    final ssidCtrl = TextEditingController();
    final pskCtrl = TextEditingController();
    final ime = CyberImeSession.shared;
    final ok = await showCyberImeFormDialog(
      context: context,
      title: 'Other Network',
      confirmLabel: 'Join',
      session: ime,
      fields: [
        CyberImeTextField(
          fieldType: CyberImeFieldType.text,
          controller: ssidCtrl,
          session: ime,
          decoration: const InputDecoration(
            labelText: 'Name',
            labelStyle: TextStyle(color: CyberColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: CyberColors.textSecondary),
            ),
            focusedBorder: UnderlineInputBorder(
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
          decoration: const InputDecoration(
            labelText: 'Password',
            labelStyle: TextStyle(color: CyberColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: CyberColors.textSecondary),
            ),
            focusedBorder: UnderlineInputBorder(
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
    final radioOn = _radio == WifiRadioState.on ||
        _radio == WifiRadioState.starting;
    final connected = _conn.isAssociated &&
        _conn.ssid != null &&
        _conn.ssid!.isNotEmpty;

    return SettingsScaffold(
      title: 'Wireless Network',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('WLAN'),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: 'Wi‑Fi',
                value: radioOn,
                onChanged: _busy != null
                    ? null
                    : (v) => unawaited(
                          _guard(() => _wifi.setRadioEnabled(v)),
                        ),
              ),
              if (connected)
                SettingsNavRow(
                  title: _conn.ssid!,
                  value: _conn.ipv4 ?? 'Connected',
                  onTap: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _conn.ssid!,
                                style: Theme.of(ctx).textTheme.titleLarge,
                              ),
                              if (_conn.ipv4 != null)
                                Text('IP ${_conn.ipv4}'),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () {
                                  CyberClickSoundRegistry.playClick();
                                  Navigator.pop(ctx);
                                  unawaited(_guard(_wifi.disconnect));
                                },
                                child: const Text('Disconnect'),
                              ),
                              TextButton(
                                onPressed: () {
                                  CyberClickSoundRegistry.playClick();
                                  Navigator.pop(ctx);
                                  unawaited(
                                    _guard(() => _wifi.forget(_conn.ssid!)),
                                  );
                                },
                                child: const Text('Forget This Network'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                )
              else if (radioOn)
                const ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text('Not Connected'),
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
          if (radioOn) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text(
                    'NETWORKS',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.6,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy != null
                        ? null
                        : () {
                            CyberClickSoundRegistry.playClick();
                            unawaited(_scan());
                          },
                    child: const Text('Scan'),
                  ),
                ],
              ),
            ),
            SettingsGroup(
              children: [
                if (_available.isEmpty)
                  const ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    title: Text('No networks found'),
                  )
                else
                  for (final ap in _available.take(20))
                    SettingsNavRow(
                      title: ap.ssid,
                      value: '${ap.signalDbm ?? '—'} dBm',
                      leading: Icon(
                        (ap.signalDbm ?? -100) > -60
                            ? Icons.wifi
                            : Icons.wifi_2_bar,
                      ),
                      onTap: _busy != null ? null : () => _connectAp(ap),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: _busy != null
                    ? null
                    : () {
                        CyberClickSoundRegistry.playClick();
                        unawaited(_joinHidden());
                      },
                child: const Text('Other…'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
