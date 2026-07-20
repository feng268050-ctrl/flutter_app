import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// Device Information tab — identity / versions from sysinfo + Modbus.
class DeviceInformationTab extends StatefulWidget {
  const DeviceInformationTab({super.key, required this.services});

  final AppServices services;

  @override
  State<DeviceInformationTab> createState() => _DeviceInformationTabState();
}

class _DeviceInformationTabState extends State<DeviceInformationTab> {
  String _deviceSn = kUnavailableDisplay;
  String _gunheadSn = kUnavailableDisplay;
  String _systemVersion = kUnavailableDisplay;
  String _kernelVersion = kUnavailableDisplay;
  String _controlCardVersion = kUnavailableDisplay;
  String _laserVersion = kUnavailableDisplay;
  String _wireFeederVersion = kUnavailableDisplay;
  String _modbusLink = kUnavailableDisplay;

  StreamSubscription<SysInfoUpdate>? _sysSub;
  StreamSubscription<List<ModbusAttributeChange>>? _modbusSub;
  StreamSubscription<ModbusHealth>? _healthSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  Future<void> _start() async {
    try {
      _sysSub = widget.services.sysInfo
          .watch(interval: const Duration(seconds: 2))
          .listen(_onSys, onError: (_) {});
    } catch (_) {}

    try {
      await widget.services.ensureModbusLive();
      _modbusSub = widget.services.modbusAttributeChanges.listen(_onModbus);
      _healthSub = widget.services.modbusHealthChanges.listen(_onHealth);
    } catch (_) {}
  }

  void _onSys(SysInfoUpdate update) {
    if (!mounted) return;
    final snap = update.snapshot;
    setState(() {
      _deviceSn = snap.serialNumber ?? kUnavailableDisplay;
      _kernelVersion = snap.kernelRelease ?? kUnavailableDisplay;
      _systemVersion = snap.appVersion ?? kUnavailableDisplay;
    });
  }

  void _onHealth(ModbusHealth health) {
    if (!mounted) return;
    setState(() {
      if (!health.ok || health.truncated) {
        _modbusLink = 'FAULT';
      } else if (health.groupId == null || _modbusLink == kUnavailableDisplay) {
        _modbusLink = 'OK';
      }
    });
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

  @override
  void dispose() {
    unawaited(_sysSub?.cancel() ?? Future<void>.value());
    unawaited(_modbusSub?.cancel() ?? Future<void>.value());
    unawaited(_healthSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              _row('Device SN', _deviceSn),
              _row('Gunhead SN', _gunheadSn),
              _row('System Version', _systemVersion),
              _row('Kernel Version', _kernelVersion),
              _row('Control Card Version', _controlCardVersion),
              _row('Laser Version', _laserVersion),
              _row('Wire Feeder Version', _wireFeederVersion),
              _row('Display Stack', widget.services.displayStack.displayLabel),
              _row('Modbus Link', _modbusLink),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    final style = Theme.of(context).textTheme.titleMedium;
    return ListTile(
      title: Text(label, style: style),
      trailing: Text(value, style: style),
    );
  }
}
