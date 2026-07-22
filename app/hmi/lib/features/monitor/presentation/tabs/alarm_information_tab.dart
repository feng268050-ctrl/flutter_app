import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';

/// lws-ui `fragment_warn_info` — left status/temps + right history + live actives.
///
/// Live Modbus (comm + temps) comes from [WarnAlarmController.monitor] only.
class AlarmInformationTab extends StatefulWidget {
  const AlarmInformationTab({super.key});

  @override
  State<AlarmInformationTab> createState() => _AlarmInformationTabState();
}

class _AlarmInformationTabState extends State<AlarmInformationTab> {
  StreamSubscription<List<AlarmLogEntry>>? _historySub;
  List<AlarmLogEntry> _history = const [];
  AlarmMonitorState? _monitor;
  final TempSeries _emptyTemp = TempSeries();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final warn = WarnAlarmScope.maybeOf(context);
      if (warn == null) {
        return;
      }
      _monitor = warn.monitor;
      _monitor!.addListener(_onMonitor);
      _historySub = warn.watchHistory(limit: 200).listen((rows) {
        if (!mounted) {
          return;
        }
        setState(() => _history = rows);
      });
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onMonitor() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _monitor?.removeListener(_onMonitor);
    unawaited(_historySub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  /// `null` → idle (empty); `true` → fault; `false` → ok.
  MonitorIndicatorKind _commKind(bool? fault) {
    if (fault == null) {
      return MonitorIndicatorKind.idle;
    }
    return fault ? MonitorIndicatorKind.failure : MonitorIndicatorKind.success;
  }

  Future<void> _clearHistory() async {
    final warn = WarnAlarmScope.maybeOf(context);
    if (warn == null) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    await warn.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final m = _monitor ?? WarnAlarmScope.maybeOf(context)?.monitor;
    final actives = m?.activeAlarms ?? const [];

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
                                kind: _commKind(m?.laserCommFault),
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
                                      kind: _commKind(m?.gunCommFault),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: MonitorCommCard(
                                      label: 'Camera Comm Status',
                                      kind: _commKind(m?.cameraCommFault),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: MonitorTempMetricCard(
                                      series: m?.motor ?? _emptyTemp,
                                      label: 'Motor Temperature',
                                      overTemp: m?.gunMotorOverTemp ?? false,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: MonitorTempMetricCard(
                                      series: m?.motorDriver ?? _emptyTemp,
                                      label: 'Motor Driver Temperature',
                                      overTemp: m?.driverOverTemp ?? false,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: MonitorTempMetricCard(
                                      series:
                                          m?.protectiveMirror ?? _emptyTemp,
                                      label: 'Protective Mirror Temperature',
                                      overTemp:
                                          m?.protectiveMirrorOverTemp ?? false,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: MonitorTempMetricCard(
                                      series: m?.collimator ?? _emptyTemp,
                                      label: 'Collimator Temperature',
                                      overTemp:
                                          m?.collimatorOverTemp ?? false,
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
                                kind: _commKind(m?.wireFeederCommFault),
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
                              onPressed:
                                  _history.isEmpty ? null : _clearHistory,
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        if (actives.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Active: ${actives.map((a) => a.label).join(', ')}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const Divider(color: Colors.white24),
                        Expanded(
                          child: _history.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No alarm history',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _history.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  itemBuilder: (context, i) {
                                    final row = _history[i];
                                    return MonitorAlarmLogRow(
                                      code: row.code,
                                      label: row.displayLabel,
                                      timestamp: row.timestamp,
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
