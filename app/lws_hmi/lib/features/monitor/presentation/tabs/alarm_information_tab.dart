import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/features/warn_alarm/l10n/product_alarm_l10n.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/alarm_logs_cleared_dialog.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';

/// lws-ui `fragment_warn_info` — left status/temps + right history + live actives.
///
/// Left column follows Advanced Settings: [SettingsSectionHeader] + inset
/// [SettingsParamRow] grid. Metric / comm tiles use the same [MonitorGlassCard]
/// plate as the right Alarm Log (page σ30 only). Live Modbus (comm + temps)
/// comes from [WarnAlarmController.monitor] only.
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

    // Advanced Settings layout on the left: section headers + inset card grid
    // (same MonitorGlassCard face as the right Alarm Log plate). Alarm Log
    // outer pad matches left column insets ([SettingsDimens.inset] = 24).
    const ambient = MonitorDimens.outerAmbientExtent;
    const pageEdge = MonitorDimens.pad - ambient;
    const hPad = EdgeInsets.symmetric(horizontal: SettingsDimens.inset);
    const cardGap = SizedBox(height: SettingsDimens.inset);
    // Same absolute width as Engineer left device panel (1 : φ row share).
    final alarmLogWidth = ProcessModeDimens.engineerLeftPanelWidthFor(
      MediaQuery.sizeOf(context).width,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(pageEdge, 0, pageEdge, 16),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SettingsScrollView(
                    // Headers own the top inset (Advanced Settings parity).
                    padding: EdgeInsets.zero,
                    children: [
                      SettingsSectionHeader(l10n.alarmInfoLaserDevice),
                      Padding(
                        padding: hPad,
                        child: MonitorCommCard(
                          label: l10n.pumpStatusText,
                          kind: _commKind(m?.laserCommFault),
                        ),
                      ),
                      SettingsSectionHeader(
                        l10n.alarmInfoWeldingGun,
                        topInset: 36,
                      ),
                      Padding(
                        padding: hPad,
                        child: SettingsParamRow(
                          left: MonitorCommCard(
                            label: l10n.gunHeadCommunicationText,
                            kind: _commKind(m?.gunCommFault),
                          ),
                          right: MonitorCommCard(
                            label: l10n.cameraCommStatusText,
                            kind: _commKind(m?.cameraCommFault),
                          ),
                        ),
                      ),
                      cardGap,
                      Padding(
                        padding: hPad,
                        child: SettingsParamRow(
                          left: MonitorTempMetricCard(
                            series: m?.motor ?? _emptyTemp,
                            // lws-ui `gun_motor_temp_text`
                            label: l10n.gunMotorTempText,
                            overTemp: m?.gunMotorOverTemp ?? false,
                          ),
                          right: MonitorTempMetricCard(
                            series: m?.motorDriver ?? _emptyTemp,
                            // lws-ui `motor_driver_temperature_text`
                            label: l10n.motorDriverTemperatureText,
                            overTemp: m?.driverOverTemp ?? false,
                          ),
                        ),
                      ),
                      cardGap,
                      Padding(
                        padding: hPad,
                        child: SettingsParamRow(
                          left: MonitorTempMetricCard(
                            series: m?.protectiveMirror ?? _emptyTemp,
                            // lws-ui `protective_mirror_temperature_text`
                            label: l10n.protectiveMirrorTemperatureText,
                            overTemp: m?.protectiveMirrorOverTemp ?? false,
                          ),
                          right: MonitorTempMetricCard(
                            series: m?.collimator ?? _emptyTemp,
                            // lws-ui `collimator_temperature_text`
                            label: l10n.collimatorTemperatureText,
                            overTemp: m?.collimatorOverTemp ?? false,
                          ),
                        ),
                      ),
                      SettingsSectionHeader(
                        l10n.alarmInfoWireFeeder,
                        topInset: 36,
                      ),
                      Padding(
                        padding: hPad,
                        child: MonitorCommCard(
                          label: l10n.wireFeedingMachineCommunicationText,
                          kind: _commKind(m?.wireFeederCommFault),
                        ),
                      ),
                      const SizedBox(height: SettingsDimens.inset),
                    ],
                  ),
                ),
                // Face-to-face gap ≈ pad: each column already reserves [ambient].
                const SizedBox(width: MonitorDimens.pad - ambient),
                SizedBox(
                  width: alarmLogWidth,
                  // Match left monitoring column insets: SettingsSectionHeader
                  // topInset + card hPad + trailing inset (all SettingsDimens.inset).
                  child: Padding(
                    padding: const EdgeInsets.all(SettingsDimens.inset),
                    child: MonitorGlassCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WordBoundaryLabel(
                            text: l10n.alarmLogsTitle,
                            maxLines: 2,
                            style: context.hmiTypography.pageTitle.copyWith(
                              color: Colors.white,
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
                                      child: WordBoundaryLabel(
                                        text: l10n.noActiveAlarms,
                                        textAlign: TextAlign.center,
                                        maxLines: 3,
                                        style: context
                                            .hmiTypography.settingsRowTitle
                                            .copyWith(
                                          color: Colors.white54,
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
                              groupIconWithLabel: true,
                              onPressed:
                                  _history.isEmpty ? null : _clearHistory,
                              label: l10n.clearAlarmLogs,
                              leading: Image.asset(
                                'assets/warn/alarm_button_icon.webp',
                                color: CyberColors.buttonSecondaryText,
                                colorBlendMode: BlendMode.srcIn,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.delete_outline,
                                  color: CyberColors.buttonSecondaryText,
                                ),
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
