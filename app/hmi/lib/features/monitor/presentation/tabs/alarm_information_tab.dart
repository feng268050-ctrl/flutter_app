import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/features/warn_alarm/l10n/product_alarm_l10n.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
                              MonitorSectionHeader(l10n.alarmInfoLaserDevice),
                              MonitorCommCard(
                                label: l10n.pumpStatusText,
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
                              MonitorSectionHeader(l10n.alarmInfoWeldingGun),
                              Row(
                                children: [
                                  Expanded(
                                    child: MonitorCommCard(
                                      label: l10n.gunHeadCommunicationText,
                                      kind: _commKind(m?.gunCommFault),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: MonitorCommCard(
                                      label: l10n.cameraCommStatusText,
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
                                      label: l10n.motorTempLabel,
                                      overTemp: m?.gunMotorOverTemp ?? false,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: MonitorTempMetricCard(
                                      series: m?.motorDriver ?? _emptyTemp,
                                      label: l10n.motorDriverTempLabel,
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
                                      label: l10n.protectiveMirrorTempLabel,
                                      overTemp:
                                          m?.protectiveMirrorOverTemp ?? false,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: MonitorTempMetricCard(
                                      series: m?.collimator ?? _emptyTemp,
                                      label: l10n.collimatorTempLabel,
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
                              MonitorSectionHeader(l10n.alarmInfoWireFeeder),
                              MonitorCommCard(
                                label: l10n.wireFeedingMachineCommunicationText,
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
                            Expanded(
                              child: Text(
                                l10n.alarmLogsTitle,
                                style: const TextStyle(
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
                              child: Text(l10n.clearAlarmLogs),
                            ),
                          ],
                        ),
                        if (actives.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${l10n.activeAlarmsTitle}: '
                            '${actives.map((a) => l10n.alarmTitleFor(a.code, fallback: a.label)).join(', ')}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const Divider(color: Colors.white24),
                        Expanded(
                          child: _history.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.noActiveAlarms,
                                    style: const TextStyle(
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
                                      label: l10n.alarmTitleFor(
                                        row.code,
                                        fallback: row.displayLabel,
                                      ),
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
