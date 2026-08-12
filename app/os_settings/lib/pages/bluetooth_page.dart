import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/bluetooth.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/ui/cyber_ime_input_dialog.dart';
import 'package:os_settings/util/bluetooth_alias.dart';

/// Bluetooth settings with pairing challenge UI.
class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothAdapterState _state = BluetoothAdapterState.off;
  BluetoothAdapterInfo _info = const BluetoothAdapterInfo();
  List<BluetoothRemoteDevice> _devices = const [];
  bool _scanning = false;
  bool _a2dp = false;
  String? _error;
  BluetoothPairingChallenge? _challenge;
  final _passkeyCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _subs = <StreamSubscription<dynamic>>[];
  bool _started = false;

  LinuxBluezBluetoothController get _bt => OsSettingsScope.of(context).bluetooth();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started) return;
      _started = true;
      _wireStreams();
      unawaited(_bootstrap());
    });
  }

  void _wireStreams() {
    _state = _bt.currentAdapterState;
    _info = _bt.currentAdapterInfo;
    _devices = _bt.currentDevices;
    _scanning = _bt.currentScanning;
    _a2dp = _bt.currentA2dpSinkEnabled;
    _subs.addAll([
      _bt.adapterState.listen((s) {
        if (mounted) setState(() => _state = s);
      }),
      _bt.adapterInfo.listen((i) {
        if (mounted) setState(() => _info = i);
      }),
      _bt.devices.listen((d) {
        if (mounted) setState(() => _devices = d);
      }),
      _bt.scanning.listen((v) {
        if (mounted) setState(() => _scanning = v);
      }),
      _bt.a2dpSinkEnabled.listen((v) {
        if (mounted) setState(() => _a2dp = v);
      }),
      _bt.pairingChallenge.listen((c) {
        if (mounted) setState(() => _challenge = c);
      }),
    ]);
    setState(() {});
  }

  Future<void> _bootstrap() async {
    try {
      await _bt.syncFromSystem();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _state = _bt.currentAdapterState;
      _info = _bt.currentAdapterInfo;
      _devices = _bt.currentDevices;
    });
    if (_info.powered) {
      unawaited(_run(() => _bt.startScan()));
    }
    try {
      final product = await OsSettingsScope.of(context).productInfo();
      await applyBluetoothAliasFromProduct(
        product,
        setAliasHelper: (name) async {
          try {
            final r = await Process.run(
              '/usr/libexec/bluetooth/bt-set-alias.sh',
              [name],
            );
            return r.exitCode;
          } catch (_) {
            return 127;
          }
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _passkeyCtrl.dispose();
    _pinCtrl.dispose();
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

  Future<void> _forget(String address) async {
    await _run(() => _bt.removeRemote(address));
  }

  @override
  Widget build(BuildContext context) {
    final on = _info.powered || _state == BluetoothAdapterState.on;
    final nearby = _devices.where((d) => !d.paired && !d.trusted).toList();
    final paired = _devices.where((d) => d.paired || d.trusted).toList();
    final challengePanel = _challengePanel();

    return SettingsScaffold(
      title: 'Bluetooth',
      body: SettingsScrollView(
        children: [
          if (challengePanel != null) challengePanel,
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsSwitchRow(
                title: 'Bluetooth',
                value: on,
                onChanged: (v) => unawaited(
                  _run(() async {
                    await _bt.setAdapterEnabled(v);
                    if (v) await _bt.startScan();
                  }),
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
                      await _bt.setDiscoverable(v);
                      await _bt.setPairable(v);
                    }),
                  ),
                ),
              if (on)
                SettingsSwitchRow(
                  title: 'Use as Speaker (A2DP)',
                  value: _a2dp,
                  onChanged: (v) => unawaited(
                    _run(() => _bt.setA2dpSinkEnabled(v)),
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
            SettingsSectionHeader('My Devices'),
            SettingsGroup(
              borderGradientCenter:
                  CyberBorderGradientCenter.bottomLeftTopRight,
              children: [
                if (paired.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Text(
                      'No paired devices',
                      style: SettingsTextStyles.title,
                    ),
                  )
                else
                  for (final d in paired)
                    SettingsNavRow(
                      title: d.name.isNotEmpty ? d.name : d.address,
                      value: d.connected ? 'Connected' : 'Paired',
                      showChevron: false,
                      onTap: () => unawaited(
                        _run(
                          () => d.connected
                              ? _bt.disconnectRemote(d.address)
                              : _bt.pairAndConnect(d.address),
                        ),
                      ),
                      trailingExtra: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 22),
                        color: CyberColors.textSecondary,
                        onPressed: () => unawaited(_forget(d.address)),
                      ),
                    ),
              ],
            ),
            SettingsSectionHeader('Other Devices'),
            SettingsGroup(
              borderGradientCenter: CyberBorderGradientCenter.topBottom,
              children: [
                if (nearby.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Text(
                      _scanning ? 'Scanning…' : 'No devices found',
                      style: SettingsTextStyles.title,
                    ),
                  )
                else
                  for (final d in nearby)
                    SettingsNavRow(
                      title: d.name.isNotEmpty ? d.name : d.address,
                      value: 'Not connected',
                      showChevron: false,
                      onTap: () => unawaited(
                        _run(() => _bt.pairAndConnect(d.address)),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget? _challengePanel() {
    final c = _challenge;
    if (c == null) return null;
    final label = c.name.isEmpty ? c.address : '${c.name} (${c.address})';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CyberColors.borderMid),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _challengeContent(c, label),
        ),
      ),
    );
  }

  Widget _challengeContent(BluetoothPairingChallenge c, String label) {
    switch (c.kind) {
      case BluetoothPairingChallengeKind.displayPasskey:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter this passkey on the remote device:',
              style: TextStyle(color: CyberColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              (c.passkey?.toString().padLeft(6, '0') ?? '------'),
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            TextButton(
              onPressed: () => unawaited(_bt.cancelPairing()),
              child: const Text('Cancel pairing'),
            ),
          ],
        );
      case BluetoothPairingChallengeKind.displayPinCode:
        return Text(
          'PIN for $label: ${c.pinCode ?? ''}',
          style: const TextStyle(color: Colors.amber, fontSize: 18),
        );
      case BluetoothPairingChallengeKind.confirm:
      case BluetoothPairingChallengeKind.authorizeService:
      case BluetoothPairingChallengeKind.requestAuthorization:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.kind == BluetoothPairingChallengeKind.authorizeService
                  ? 'Allow ${c.serviceUuid ?? 'service'} for $label?'
                  : '$label wants to pair',
              style: const TextStyle(color: CyberColors.textPrimary),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => unawaited(
                    _bt.respondToPairingChallenge(c.id, accept: true),
                  ),
                  child: const Text('Accept'),
                ),
                TextButton(
                  onPressed: () => unawaited(
                    _bt.respondToPairingChallenge(c.id, accept: false),
                  ),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        );
      case BluetoothPairingChallengeKind.requestPasskey:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter passkey for $label',
              style: const TextStyle(color: CyberColors.textPrimary),
            ),
            CyberImeTextField(
              fieldType: CyberImeFieldType.number,
              controller: _passkeyCtrl,
              style: const TextStyle(color: CyberColors.textPrimary),
            ),
            TextButton(
              onPressed: () {
                final v = int.tryParse(_passkeyCtrl.text.trim());
                unawaited(
                  _bt.respondToPairingChallenge(
                    c.id,
                    accept: v != null,
                    passkey: v,
                  ),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      case BluetoothPairingChallengeKind.requestPinCode:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter PIN for $label',
              style: const TextStyle(color: CyberColors.textPrimary),
            ),
            CyberImeTextField(
              fieldType: CyberImeFieldType.number,
              controller: _pinCtrl,
              style: const TextStyle(color: CyberColors.textPrimary),
            ),
            TextButton(
              onPressed: () {
                final pin = _pinCtrl.text.trim();
                unawaited(
                  _bt.respondToPairingChallenge(
                    c.id,
                    accept: pin.isNotEmpty,
                    pinCode: pin,
                  ),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
    }
  }
}
