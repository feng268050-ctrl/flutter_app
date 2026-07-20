import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/application/gun_alarm_telemetry.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';

/// lws-ui `fragment_warn_info` — left status/temps + right alarm log.
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
          startDelay: const Duration(milliseconds: 200),
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

  MonitorIndicatorKind _commKind(bool? fault) {
    // Idle (gray) until primed; then Success / Failure — never "?".
    if (fault == null) {
      return MonitorIndicatorKind.idle;
    }
    return fault ? MonitorIndicatorKind.failure : MonitorIndicatorKind.success;
  }

  @override
  Widget build(BuildContext context) {
    final alarms = _telemetry.activeAlarms;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 740,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MonitorGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const MonitorSectionHeader('Laser Device'),
                              MonitorCommCard(
                                label: 'Pump Comm Status',
                                kind: _commKind(_telemetry.laserCommFault),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        MonitorGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const MonitorSectionHeader('Welding Gun'),
                              Row(
                                children: [
                                  Expanded(
                                    child: MonitorCommCard(
                                      label: 'Gun Comm Status',
                                      kind: _commKind(_telemetry.gunCommFault),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  const Expanded(
                                    child: MonitorCommCard(
                                      label: 'Camera Comm Status',
                                      kind: MonitorIndicatorKind.idle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: MonitorTempMetricCard(
                                      series: _telemetry.motor,
                                      label: 'Motor Temperature',
                                      overTemp: _telemetry.gunMotorOverTemp,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: MonitorTempMetricCard(
                                      series: _telemetry.motorDriver,
                                      label: 'Motor Driver Temperature',
                                      overTemp: _telemetry.driverOverTemp,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: MonitorTempMetricCard(
                                      series: _telemetry.protectiveMirror,
                                      label: 'Protective Mirror Temperature',
                                      overTemp:
                                          _telemetry.protectiveMirrorOverTemp,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: MonitorTempMetricCard(
                                      series: _telemetry.collimator,
                                      label: 'Collimator Temperature',
                                      overTemp: _telemetry.collimatorOverTemp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        MonitorGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const MonitorSectionHeader('Wire Feeder'),
                              MonitorCommCard(
                                label: 'Wire Feeder Comm Status',
                                kind: _commKind(_telemetry.wireFeederCommFault),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 468,
                  child: MonitorGlassCard(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Alarm Logs',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: MonitorDimens.sectionTitleSize,
                                  fontWeight: FontWeight.w400,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: alarms.isEmpty
                                  ? null
                                  : () {
                                      // Clear is product-policy later; soft stub.
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Clear alarm log — coming soon',
                                          ),
                                        ),
                                      );
                                    },
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24),
                        Expanded(
                          child: alarms.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No active alarms',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: alarms.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  itemBuilder: (context, i) {
                                    return MonitorAlarmLogRow(
                                      alarm: alarms[i],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
