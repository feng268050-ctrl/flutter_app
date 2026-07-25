import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';

/// Bluetooth settings — phone-style list (not Demo section dump).
class BluetoothSettingsPage extends StatefulWidget {
  const BluetoothSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<BluetoothSettingsPage> createState() => _BluetoothSettingsPageState();
}

class _BluetoothSettingsPageState extends State<BluetoothSettingsPage> {
  late BluetoothAdapterState _state =
      widget.services.bluetooth.currentAdapterState;
  late BluetoothAdapterInfo _info =
      widget.services.bluetooth.currentAdapterInfo;
  late List<BluetoothRemoteDevice> _devices =
      widget.services.bluetooth.currentDevices;
  late bool _scanning = widget.services.bluetooth.currentScanning;
  late bool _a2dp = widget.services.bluetooth.currentA2dpSinkEnabled;
  String? _error;

  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    final bt = widget.services.bluetooth;
    _subs.addAll([
      bt.adapterState.listen((s) {
        if (mounted) setState(() => _state = s);
      }),
      bt.adapterInfo.listen((i) {
        if (mounted) setState(() => _info = i);
      }),
      bt.devices.listen((d) {
        if (mounted) setState(() => _devices = d);
      }),
      bt.scanning.listen((v) {
        if (mounted) setState(() => _scanning = v);
      }),
      bt.a2dpSinkEnabled.listen((v) {
        if (mounted) setState(() => _a2dp = v);
      }),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _error = null);
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final on = _info.powered || _state == BluetoothAdapterState.on;
    final nearby =
        _devices.where((d) => !d.paired && !d.trusted).toList();
    final paired = _devices.where((d) => d.paired || d.trusted).toList();

    return SettingsScaffold(
      title: l10n.bluetoothSettings,
      body: SettingsScrollView(
        children: [
          // Adapter — rotate like Wi‑Fi top card
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsSwitchRow(
                title: l10n.bluetoothText,
                value: on,
                onChanged: (v) => unawaited(
                  _run(() => widget.services.bluetooth.setAdapterEnabled(v)),
                ),
              ),
              if (on && _info.name.isNotEmpty)
                SettingsValueRow(
                  title: 'This Device',
                  value: _info.name,
                ),
              if (on)
                SettingsSwitchRow(
                  title: 'Discoverable',
                  value: _info.discoverable,
                  onChanged: (v) => unawaited(
                    _run(() async {
                      await widget.services.bluetooth.setDiscoverable(v);
                      await widget.services.bluetooth.setPairable(v);
                    }),
                  ),
                ),
              if (on)
                SettingsSwitchRow(
                  title: l10n.bluetoothAsSpeaker,
                  value: _a2dp,
                  onChanged: (v) => unawaited(
                    _run(
                      () => widget.services.bluetooth.setA2dpSinkEnabled(v),
                    ),
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
          if (on) ...[
            // My Devices
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SettingsDimens.inset,
                12,
                SettingsDimens.inset,
                8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'MY DEVICES',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: CyberColors.textSecondary,
                          letterSpacing: 0.6,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: _scanning
                        ? () {
                            CyberClickSoundRegistry.playClick();
                            unawaited(
                              widget.services.bluetooth.stopScan(),
                            );
                          }
                        : () {
                            CyberClickSoundRegistry.playClick();
                            unawaited(
                              _run(
                                () => widget.services.bluetooth.startScan(),
                              ),
                            );
                          },
                    child: Text(_scanning ? 'Stop' : 'Scan'),
                  ),
                ],
              ),
            ),
            SettingsGroup(
              borderGradientCenter:
                  CyberBorderGradientCenter.bottomLeftTopRight,
              children: [
                if (paired.isEmpty)
                  const ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    title: Text(
                      'No paired devices',
                      style: TextStyle(color: CyberColors.textPrimary),
                    ),
                  )
                else
                  for (final d in paired)
                    SettingsNavRow(
                      title: d.name.isNotEmpty ? d.name : d.address,
                      value: d.connected ? l10n.connectedText : 'Paired',
                      showChevron: false,
                      onTap: () => unawaited(
                        _run(
                          () => d.connected
                              ? widget.services.bluetooth
                                  .disconnectRemote(d.address)
                              : widget.services.bluetooth
                                  .pairAndConnect(d.address),
                        ),
                      ),
                    ),
              ],
            ),
            // Other Devices
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SettingsDimens.inset,
                12,
                SettingsDimens.inset,
                8,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'OTHER DEVICES',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: CyberColors.textSecondary,
                        letterSpacing: 0.6,
                      ),
                ),
              ),
            ),
            SettingsGroup(
              borderGradientCenter: CyberBorderGradientCenter.topBottom,
              children: [
                if (nearby.isEmpty)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    title: Text(
                      _scanning ? 'Scanning…' : 'No devices found',
                      style: const TextStyle(color: CyberColors.textPrimary),
                    ),
                  )
                else
                  for (final d in nearby)
                    SettingsNavRow(
                      title: d.name.isNotEmpty ? d.name : d.address,
                      value: l10n.notConnected,
                      showChevron: false,
                      onTap: () => unawaited(
                        _run(
                          () => widget.services.bluetooth
                              .pairAndConnect(d.address),
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
