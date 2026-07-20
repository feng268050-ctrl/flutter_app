import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/monitor/application/gun_alarm_telemetry.dart';

/// Semi-transparent Home card: SoC / GPU / gun temperatures.
class HomeTemperatureCard extends StatefulWidget {
  const HomeTemperatureCard({super.key});

  @override
  State<HomeTemperatureCard> createState() => _HomeTemperatureCardState();
}

class _HomeTemperatureCardState extends State<HomeTemperatureCard> {
  final TempSeries _soc = TempSeries();
  final TempSeries _gpu = TempSeries();
  final GunAlarmTelemetry _gun = GunAlarmTelemetry();

  StreamSubscription<SysInfoUpdate>? _sysSub;

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

    await _gun.start(
      services,
      onUpdate: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    unawaited(_sysSub?.cancel() ?? Future<void>.value());
    unawaited(_gun.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = <(String, TempSeries)>[
      ('SoC Temperature', _soc),
      ('GPU Temperature', _gpu),
      ('Motor Temperature', _gun.motor),
      ('Motor Driver Temperature', _gun.motorDriver),
      ('Protective Mirror Temperature', _gun.protectiveMirror),
      ('Collimator Temperature', _gun.collimator),
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
