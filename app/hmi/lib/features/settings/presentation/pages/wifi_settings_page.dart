import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

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
    final psk = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text(ap.ssid),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: 'Leave empty if open',
            ),
            autofocus: true,
            onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
          ),
          actions: [
            TextButton(
              onPressed: () {
                CyberClickSoundRegistry.playClick();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                CyberClickSoundRegistry.playClick();
                Navigator.pop(ctx, ctrl.text);
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
    if (psk == null || !mounted) return;
    await _guard(() => _wifi.connect(
          ssid: ap.ssid,
          psk: psk.isEmpty ? null : psk,
        ));
  }

  Future<void> _joinHidden() async {
    final ssidCtrl = TextEditingController();
    final pskCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Other Network'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ssidCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: pskCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
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
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final ssid = ssidCtrl.text.trim();
    if (ssid.isEmpty) return;
    await _guard(() => _wifi.connect(
          ssid: ssid,
          psk: pskCtrl.text.isEmpty ? null : pskCtrl.text,
          hidden: true,
        ));
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
