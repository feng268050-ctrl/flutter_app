import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/features/warn_alarm/l10n/product_alarm_l10n.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/alarm_logs_cleared_dialog.dart';
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
    if (!mounted) {
      return;
    }
    await showAlarmLogsClearedDialog(context: context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final m = _monitor ?? WarnAlarmScope.maybeOf(context)?.monitor;

    // Page edge + ambient gutter ≈ MonitorDimens.pad (24). Outer glow paints
    // inside the gutter (SettingsGroup pattern); Clip.none lets inner edges
    // bleed into the column gap without a hard truncate.
    const ambient = MonitorDimens.outerAmbientExtent;
    const pageEdge = MonitorDimens.pad - ambient;

    return Padding(
      padding: const EdgeInsets.fromLTRB(pageEdge, 0, pageEdge, 16),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 740,
                  child: SingleChildScrollView(
                    // Default hardEdge clips SettingsPanel outer ambient.
                    clipBehavior: Clip.none,
                    // L/R gutters keep glow inside the viewport; top matches pad.
                    padding: const EdgeInsets.fromLTRB(
                      ambient,
                      ambient,
                      ambient,
                      0,
                    ),
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
                                      series: m?.protectiveMirror ?? _emptyTemp,
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
                                      overTemp: m?.collimatorOverTemp ?? false,
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
                // Face-to-face gap ≈ pad: each column already reserves [ambient].
                const SizedBox(width: MonitorDimens.pad - ambient),
                Expanded(
                  flex: 468,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ambient,
                      ambient,
                      ambient,
                      0,
                    ),
                    child: MonitorGlassCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.alarmLogsTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: MonitorDimens.sectionTitleSize,
                              fontWeight: FontWeight.w400,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(
                            height: MonitorSectionHeader.dividerTopSpacing,
                          ),
                          const SizedBox(
                            height: MonitorSectionHeader.dividerHeight,
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    SettingsDimens.sectionDividerColor,
                                    SettingsDimens.sectionDividerColor,
                                    Color(0x00000000),
                                  ],
                                  stops: [0.0, 0.4, 1.0],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            // Keep rows below the Alarm Logs divider while
                            // scrolling; their content must not paint behind
                            // the fixed title area.
                            child: ClipRect(
                              child: _history.isEmpty
                                  ? Center(
                                      child: Text(
                                        l10n.noActiveAlarms,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 20,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      clipBehavior: Clip.hardEdge,
                                      itemCount: _history.length,
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
                          ),
                          const SizedBox(height: 16),
                          // lws-ui `fragment_warn_log` bottom Clear pill.
                          Center(
                            child: MonitorFrostActionButton(
                              variant: CyberButtonVariant.secondary,
                              clickSoundEnabled: false,
                              onPressed:
                                  _history.isEmpty ? null : _clearHistory,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/warn/alarm_button_icon.webp',
                                    width: 28,
                                    height: 28,
                                    color: CyberColors.buttonSecondaryText,
                                    colorBlendMode: BlendMode.srcIn,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.delete_outline,
                                      size: 28,
                                      color: CyberColors.buttonSecondaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.clearAlarmLogs,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: CyberColors.buttonSecondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
