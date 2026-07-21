import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/device/device_identity_qr.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Device Information — same Material settings chrome as Common Settings.
class DeviceInformationTab extends StatefulWidget {
  const DeviceInformationTab({super.key, required this.services});

  final AppServices services;

  @override
  State<DeviceInformationTab> createState() => _DeviceInformationTabState();
}

class _DeviceInformationTabState extends State<DeviceInformationTab> {
  String _deviceModel = kUnavailableDisplay;
  String _deviceSn = kUnavailableDisplay;
  String _gunheadSn = kUnavailableDisplay;
  String _systemVersion = kUnavailableDisplay;
  String _kernelVersion = kUnavailableDisplay;
  String _controlCardVersion = kUnavailableDisplay;
  String _laserVersion = kUnavailableDisplay;
  String _wireFeederVersion = kUnavailableDisplay;
  String _cameraType = kUnavailableDisplay;
  String _focusScaleRef = kUnavailableDisplay;

  String? _brandRaw;
  String? _modelRaw;

  StreamSubscription<SysInfoUpdate>? _sysSub;
  StreamSubscription<List<ModbusAttributeChange>>? _modbusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  Future<void> _start() async {
    try {
      await widget.services.ensureDisplayStack();
      if (mounted) setState(() {});
    } catch (_) {}

    try {
      _sysSub = widget.services.sysInfo
          .watch(interval: const Duration(seconds: 2))
          .listen(_onSys, onError: (_) {});
    } catch (_) {}

    try {
      await widget.services.ensureModbusLive();
      final stream = await widget.services.modbus.watchAttributes(
        ids: kDeviceInfoModbusWatchIds,
      );
      _modbusSub = stream.listen(_onModbus);
      // On-demand info group (gunhead / laser / wire) is not in continuous poll.
      try {
        final info = await widget.services.modbus.readGroup('info');
        _onModbus(modbusGroupToChanges(info));
      } catch (_) {}
    } catch (_) {}
  }

  static String _dash(String? value) {
    if (value == null || value.isEmpty) {
      return kUnavailableDisplay;
    }
    return value;
  }

  void _onSys(SysInfoUpdate update) {
    if (!mounted) return;
    final snap = update.snapshot;
    setState(() {
      _brandRaw = snap.brand;
      _modelRaw = snap.model;
      _deviceModel = productDeviceModelDisplay(snap.brand, snap.model);
      _deviceSn = _dash(snap.serialNumber);
      _kernelVersion = snap.kernelRelease ?? kUnavailableDisplay;
      _systemVersion = snap.appVersion ?? kUnavailableDisplay;
    });
    unawaited(_refreshProductRows());
  }

  Future<void> _refreshProductRows() async {
    try {
      final product = await widget.services.ensureProductInfo();
      if (!mounted) return;
      setState(() {
        _cameraType = productCameraTypeDisplay(product.cameraType());
        _focusScaleRef = _dash(product.focusScaleRef());
      });
    } catch (_) {}
  }

  void _onModbus(List<ModbusAttributeChange> changes) {
    if (!mounted || changes.isEmpty) return;
    setState(() {
      for (final c in changes) {
        switch (c.id) {
          case 'device.control_card_version':
            _controlCardVersion =
                modbusDisplayOrDash(modbusControlCardDisplay(c.value));
          case 'device.laser_sw_version':
            _laserVersion =
                modbusDisplayOrDash(modbusVersionStringDisplay(c.value));
          case 'device.wire_feeder_sw_version':
            _wireFeederVersion =
                modbusDisplayOrDash(modbusControlCardDisplay(c.value));
          case 'device.gun_head_sn':
            _gunheadSn =
                modbusDisplayOrDash(modbusVersionStringDisplay(c.value));
        }
      }
    });
  }

  Future<void> _openDeviceQr() async {
    CyberClickSoundRegistry.playClick();
    final sn = _deviceSn == kUnavailableDisplay ? '' : _deviceSn;
    final model = productDeviceModelForQr(_brandRaw, _modelRaw);
    final version =
        _systemVersion == kUnavailableDisplay ? '' : _systemVersion;
    final payload = DeviceIdentityQr.contentV2(
      sn: sn,
      model: model,
      systemVersion: version,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          child: InkWell(
            onTap: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_sysSub?.cancel() ?? Future<void>.value());
    unawaited(_modbusSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScrollView(
      children: [
        const SettingsSectionHeader('Identity'),
        SettingsGroup(
          children: [
            SettingsValueRow(
              title: 'Device Model',
              value: _deviceModel,
              trailing: IconButton(
                tooltip: 'Device QR code',
                onPressed: () => unawaited(_openDeviceQr()),
                icon: const Icon(Icons.qr_code_2),
              ),
            ),
            SettingsValueRow(title: 'Device SN', value: _deviceSn),
            SettingsValueRow(title: 'Gunhead SN', value: _gunheadSn),
          ],
        ),
        const SettingsSectionHeader('Versions'),
        SettingsGroup(
          children: [
            SettingsValueRow(title: 'System Version', value: _systemVersion),
            SettingsValueRow(title: 'Kernel Version', value: _kernelVersion),
            SettingsValueRow(
              title: 'Control Card Version',
              value: _controlCardVersion,
            ),
            SettingsValueRow(title: 'Laser Version', value: _laserVersion),
            SettingsValueRow(
              title: 'Wire Feeder Version',
              value: _wireFeederVersion,
            ),
          ],
        ),
        const SettingsSectionHeader('Platform'),
        SettingsGroup(
          children: [
            SettingsValueRow(
              title: 'Display Stack',
              value: widget.services.displayStack.displayLabel,
            ),
            SettingsValueRow(title: 'Camera Type', value: _cameraType),
            SettingsValueRow(
              title: 'Focus Scale Reference',
              value: _focusScaleRef,
            ),
          ],
        ),
      ],
    );
  }
}
