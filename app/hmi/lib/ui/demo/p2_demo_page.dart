import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/device/device_sn_reader.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/gpio/gpio_led_config.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// P2 home demo: device information + alarm sensor temps + RGB LED mode rows.
class P2DemoPage extends StatefulWidget {
  const P2DemoPage({
    super.key,
    this.deviceSnReader = const DeviceSnReader(),
    this.modbusClient,
    this.ledController,
  });

  final DeviceSnReader deviceSnReader;
  final ModbusRtuClient? modbusClient;
  final GpioLedController? ledController;

  @override
  State<P2DemoPage> createState() => _P2DemoPageState();
}

class _P2DemoPageState extends State<P2DemoPage> {
  late final ModbusRtuClient _modbus;
  late final GpioLedController _leds;

  String _deviceSn = kUnavailableDisplay;
  String _gunheadSn = kUnavailableDisplay;
  String _firmwareVersion = kUnavailableDisplay;
  String _laserVersion = kUnavailableDisplay;
  String _wireFeederVersion = kUnavailableDisplay;

  String _motorTemperature = kUnavailableDisplay;
  String _motorDriverTemperature = kUnavailableDisplay;
  String _protectiveMirrorTemperature = kUnavailableDisplay;
  String _collimatorTemperature = kUnavailableDisplay;

  final Map<LedColor, IndicatorMode> _ledModes = {
    for (final c in LedColor.values) c: IndicatorMode.off,
  };

  @override
  void initState() {
    super.initState();
    _modbus = widget.modbusClient ?? ModbusRtuClient();
    _leds = widget.ledController ?? GpioLedController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadAfterFirstFrame());
    });
  }

  Future<void> _loadAfterFirstFrame() async {
    final sn = await widget.deviceSnReader.read();
    if (!mounted) {
      return;
    }
    setState(() => _deviceSn = sn);

    final info = await _modbus.readDeviceInfo();
    if (!mounted) {
      return;
    }
    setState(() {
      _gunheadSn = info.gunheadSn;
      _firmwareVersion = info.firmwareVersion;
      _laserVersion = info.laserVersion;
      _wireFeederVersion = info.wireFeederVersion;
    });

    final temps = await _modbus.readAlarmTemperatures();
    if (!mounted) {
      return;
    }
    setState(() {
      _motorTemperature = temps.motorTemperature;
      _motorDriverTemperature = temps.motorDriverTemperature;
      _protectiveMirrorTemperature = temps.protectiveMirrorTemperature;
      _collimatorTemperature = temps.collimatorTemperature;
    });
  }

  Future<void> _onLedMode(LedColor color, IndicatorMode mode) async {
    setState(() => _ledModes[color] = mode);
    await _leds.setMode(color, mode);
  }

  @override
  void dispose() {
    unawaited(_leds.dispose());
    unawaited(_modbus.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Device Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Device SN', value: _deviceSn),
            _InfoRow(label: 'Gunhead SN', value: _gunheadSn),
            _InfoRow(label: 'Firmware Version', value: _firmwareVersion),
            _InfoRow(label: 'Laser Version', value: _laserVersion),
            _InfoRow(label: 'Wire Feeder Version', value: _wireFeederVersion),
            const SizedBox(height: 32),
            const Text(
              'Alarm Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Motor Temperature', value: _motorTemperature),
            _InfoRow(
              label: 'Motor Driver Temperature',
              value: _motorDriverTemperature,
            ),
            _InfoRow(
              label: 'Protective Mirror Temperature',
              value: _protectiveMirrorTemperature,
            ),
            _InfoRow(
              label: 'Collimator Temperature',
              value: _collimatorTemperature,
            ),
            const SizedBox(height: 32),
            const Text(
              'RGB LED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pins R/Y/G = ${GpioLedConfig.red}/${GpioLedConfig.yellow}/${GpioLedConfig.green}',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 16),
            for (final color in LedColor.values)
              _LedModeRow(
                color: color,
                selected: _ledModes[color]!,
                onSelected: (mode) => unawaited(_onLedMode(color, mode)),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white, fontSize: 22),
      ),
    );
  }
}

class _LedModeRow extends StatelessWidget {
  const _LedModeRow({
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final LedColor color;
  final IndicatorMode selected;
  final ValueChanged<IndicatorMode> onSelected;

  String get _title {
    switch (color) {
      case LedColor.red:
        return 'Red';
      case LedColor.yellow:
        return 'Yellow';
      case LedColor.green:
        return 'Green';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 8),
          SegmentedButton<IndicatorMode>(
            segments: const [
              ButtonSegment(value: IndicatorMode.steadyOn, label: Text('Steady')),
              ButtonSegment(value: IndicatorMode.blink, label: Text('Blink')),
              ButtonSegment(value: IndicatorMode.off, label: Text('Off')),
            ],
            selected: {selected},
            onSelectionChanged: (set) {
              if (set.isEmpty) {
                return;
              }
              onSelected(set.first);
            },
          ),
        ],
      ),
    );
  }
}
