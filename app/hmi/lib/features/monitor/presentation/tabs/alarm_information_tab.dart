import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/monitor/application/gun_alarm_telemetry.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';

/// lws-ui Monitor → Alarm Information (HAL Modbus live slice).
class AlarmInformationTab extends StatefulWidget {
  const AlarmInformationTab({super.key});

  @override
  State<AlarmInformationTab> createState() => _AlarmInformationTabState();
}

class _AlarmInformationTabState extends State<AlarmInformationTab> {
  final GunAlarmTelemetry _telemetry = GunAlarmTelemetry();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final services = AppScope.maybeOf(context);
      if (services == null) {
        return;
      }
      unawaited(
        _telemetry.start(
          services,
          onUpdate: () {
            if (mounted) {
              setState(() {});
            }
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_telemetry.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final temps = <(String, TempSeries)>[
      ('Motor', _telemetry.motor),
      ('Motor Driver', _telemetry.motorDriver),
      ('Protective Mirror', _telemetry.protectiveMirror),
      ('Collimator', _telemetry.collimator),
    ];
    final alarms = _telemetry.activeAlarms;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (!_telemetry.healthOk) ...[
          MonitorHealthBanner(message: _telemetry.healthMessage),
          const SizedBox(height: 12),
        ],
        Text(
          'Temperatures',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        MonitorSectionCard(
          child: Column(
            children: [
              for (var i = 0; i < temps.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: Colors.white.withOpacity(0.12)),
                MonitorTempRow(label: temps[i].$1, series: temps[i].$2),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Active Alarms',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        MonitorSectionCard(
          child: alarms.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No active alarms',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < alarms.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: Colors.white.withOpacity(0.12),
                        ),
                      MonitorAlarmRow(alarm: alarms[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
