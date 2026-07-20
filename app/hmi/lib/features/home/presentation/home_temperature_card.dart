import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// Semi-transparent Home card: SoC / GPU / gun temperatures from Demo.
class HomeTemperatureCard extends StatefulWidget {
  const HomeTemperatureCard({super.key});

  @override
  State<HomeTemperatureCard> createState() => _HomeTemperatureCardState();
}

class _HomeTemperatureCardState extends State<HomeTemperatureCard> {
  final TempSeries _soc = TempSeries();
  final TempSeries _gpu = TempSeries();
  final TempSeries _motor = TempSeries();
  final TempSeries _motorDriver = TempSeries();
  final TempSeries _protectiveMirror = TempSeries();
  final TempSeries _collimator = TempSeries();

  bool _gunMotorOverTemp = false;
  bool _driverOverTemp = false;
  bool _protectiveMirrorOverTemp = false;
  bool _collimatorOverTemp = false;

  StreamSubscription<SysInfoUpdate>? _sysSub;
  StreamSubscription<List<ModbusAttributeChange>>? _modbusSub;
  Timer? _modbusStartDelay;
  Timer? _modbusUiGate;
  bool _modbusDirty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  Future<void> _start() async {
    final services = AppScope.maybeOf(context);
    if (services == null) {
      return;
    }

    try {
      _sysSub = services.sysInfo
          .watch(interval: const Duration(seconds: 2))
          .listen((update) {
        if (!mounted) return;
        final snap = update.snapshot;
        setState(() {
          _soc.setCelsius(snap.socThermal?.temperatureCelsius);
          _gpu.setCelsius(snap.gpuThermal?.temperatureCelsius);
        });
      }, onError: (_) {});
    } catch (_) {}

    // Let Home finish first paint + WebP decode before serial Modbus work.
    _modbusStartDelay = Timer(const Duration(milliseconds: 1200), () {
      unawaited(_startModbus(services));
    });
  }

  Future<void> _startModbus(AppServices services) async {
    if (!mounted) return;
    try {
      await services.ensureModbusLive();
      if (!mounted) return;
      _modbusSub = services.modbusAttributeChanges.listen(_onModbus);
      _modbusUiGate = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted || !_modbusDirty) return;
        _modbusDirty = false;
        setState(() {});
      });
    } catch (_) {}
  }

  void _onModbus(List<ModbusAttributeChange> changes) {
    if (!mounted || changes.isEmpty) return;
    for (final c in changes) {
      switch (c.id) {
        case 'telemetry.gun_motor_temp':
        case 'alarm.gun_motor_temp':
          _motor.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: _gunMotorOverTemp,
          );
        case 'telemetry.gun_motor_drive_temp':
        case 'alarm.gun_motor_drive_temp':
          _motorDriver.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: _driverOverTemp,
          );
        case 'telemetry.protective_cover_temp':
        case 'alarm.protective_cover_temp':
          _protectiveMirror.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: _protectiveMirrorOverTemp,
          );
        case 'telemetry.collimator_temp':
        case 'alarm.collimator_temp':
          _collimator.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: _collimatorOverTemp,
          );
        case 'alarm.gun_motor_over_temp':
          _gunMotorOverTemp = c.value == true;
          _motor.setOverTemp(_gunMotorOverTemp);
        case 'alarm.driver_over_temp':
          _driverOverTemp = c.value == true;
          _motorDriver.setOverTemp(_driverOverTemp);
        case 'alarm.protective_mirror_over_temp':
          _protectiveMirrorOverTemp = c.value == true;
          _protectiveMirror.setOverTemp(_protectiveMirrorOverTemp);
        case 'alarm.collimator_over_temp':
          _collimatorOverTemp = c.value == true;
          _collimator.setOverTemp(_collimatorOverTemp);
      }
    }
    _modbusDirty = true;
  }

  @override
  void dispose() {
    _modbusStartDelay?.cancel();
    _modbusUiGate?.cancel();
    unawaited(_sysSub?.cancel() ?? Future<void>.value());
    unawaited(_modbusSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = <(String, TempSeries)>[
      ('SoC Temperature', _soc),
      ('GPU Temperature', _gpu),
      ('Motor Temperature', _motor),
      ('Motor Driver Temperature', _motorDriver),
      ('Protective Mirror Temperature', _protectiveMirror),
      ('Collimator Temperature', _collimator),
    ];

    return Material(
      color: Colors.black.withOpacity(0.42),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Temperatures',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: Colors.white.withOpacity(0.12)),
              _TempRow(label: rows[i].$1, series: rows[i].$2),
            ],
          ],
        ),
      ),
    );
  }
}

class _TempRow extends StatelessWidget {
  const _TempRow({required this.label, required this.series});

  final String label;
  final TempSeries series;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 15,
              ),
            ),
          ),
          if (series.trend == TempTrend.up)
            const Icon(Icons.arrow_drop_up, color: Color(0xFFE53935), size: 24)
          else if (series.trend == TempTrend.down)
            const Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF43A047),
              size: 24,
            ),
          Text(
            series.display,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
