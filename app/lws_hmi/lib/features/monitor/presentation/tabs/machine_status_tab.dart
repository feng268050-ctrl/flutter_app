import 'dart:async';
import 'dart:math' as math;

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/monitor/application/machine_status_controller.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/product_top_tabs.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/features/warn_alarm/l10n/product_alarm_l10n.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/alarm_logs_cleared_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';

/// Newest rows shown on Machine Status → Alarm Logs (full watch stays 200).
@visibleForTesting
const kMachineAlarmLogsVisibleLimit = 10;

/// Pinned Alarm Logs header: title row + tab-style hairline. Transparent fill
/// so the section blends with the page; the divider is the clip edge (same
/// rule as [ProductTopTabs]: content below the line does not paint through).
const _kAlarmLogsPinnedHeaderExtent = 8 +
    HmiButtonMetrics.smallHeight +
    16 +
    ProductTopTabs.dividerThickness;

/// Newest-first slice for the Machine Status Alarm Logs section.
@visibleForTesting
List<AlarmLogEntry> latestAlarmHistoryRows(
  List<AlarmLogEntry> rows, {
  int limit = kMachineAlarmLogsVisibleLimit,
}) {
  final sorted = List<AlarmLogEntry>.from(rows)
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  if (sorted.length <= limit) {
    return sorted;
  }
  return sorted.sublist(0, limit);
}

/// Machine Status: Live Status → Device Health → Alarm Logs (one scroll).
class MachineStatusTab extends StatefulWidget {
  const MachineStatusTab({
    super.key,
    this.visible = true,
  });

  /// When false, Modbus polling is paused (hidden Monitor tab).
  final bool visible;

  @override
  State<MachineStatusTab> createState() => _MachineStatusTabState();
}

class _MachineStatusTabState extends State<MachineStatusTab> {
  MachineStatusController? _ctrl;
  StreamSubscription<List<AlarmLogEntry>>? _historySub;
  List<AlarmLogEntry> _history = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final services = AppScope.maybeOf(context);
      if (services != null && mounted) {
        final ctrl = MachineStatusController(services);
        ctrl.addListener(_onUpdate);
        setState(() => _ctrl = ctrl);
        if (widget.visible) {
          ctrl.start();
        }
      }
      final warn = WarnAlarmScope.maybeOf(context);
      if (warn == null || !mounted) {
        return;
      }
      _historySub = warn.watchHistory(limit: 200).listen((rows) {
        if (!mounted) {
          return;
        }
        setState(() => _history = rows);
      });
    });
  }

  @override
  void didUpdateWidget(covariant MachineStatusTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) {
      return;
    }
    final ctrl = _ctrl;
    if (ctrl == null) {
      return;
    }
    if (widget.visible) {
      ctrl.start();
    } else {
      ctrl.stop();
    }
  }

  void _onUpdate() {
    if (mounted && widget.visible) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    final ctrl = _ctrl;
    ctrl?.removeListener(_onUpdate);
    ctrl?.dispose();
    unawaited(_historySub?.cancel() ?? Future<void>.value());
    super.dispose();
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
    final visibleLogs = latestAlarmHistoryRows(_history);
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                key: const ValueKey('machine-status-live-status'),
                height: constraints.maxHeight,
                child: Padding(
                  padding: const EdgeInsets.all(MonitorDimens.pad),
                  child: _MachineLiveStatusSection(ctrl: _ctrl),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: _MachineDeviceHealthSection(),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _AlarmLogsPinnedHeaderDelegate(
                title: l10n.alarmLogsTitle,
                clearLabel: l10n.clearAlarmLogs,
                onClear: visibleLogs.isEmpty ? null : _clearHistory,
              ),
            ),
            _SliverClipPinnedOverlap(
              key: const ValueKey('machine-status-alarm-logs-clip'),
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  MonitorDimens.pad,
                  0,
                  MonitorDimens.pad,
                  MonitorDimens.pad,
                ),
                sliver: visibleLogs.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: WordBoundaryLabel(
                            text: l10n.noActiveAlarms,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            style:
                                context.hmiTypography.settingsRowTitle.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final row = visibleLogs[index];
                            return MonitorAlarmLogRow(
                              code: row.code,
                              label: l10n.alarmTitleFor(
                                row.code,
                                fallback: row.displayLabel,
                              ),
                              timestamp: row.timestamp,
                            );
                          },
                          childCount: visibleLogs.length,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MachineLiveStatusSection extends StatelessWidget {
  const _MachineLiveStatusSection({required this.ctrl});

  final MachineStatusController? ctrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = ctrl;
    final gasPressureTitle =
        '${l10n.machineBlowTitle}\n${l10n.machineBlowContent}';
    final laserCurrentTitle =
        '${l10n.machineLaserCurrentTitle}\n${l10n.machineLaserCurrentContent}';
    final tiles = <(String, bool?)>[
      (l10n.safetyLockText, s?.safetyLockOn),
      (l10n.gunHeadSwitchText, s?.gunSwitchOn),
      (l10n.redLightText, s?.redLightOn),
      (l10n.ipCameraText, s?.cameraOn),
    ];

    Widget gaugeCard({
      required double value,
      required double max,
      required double majorTickEvery,
      required String unit,
      required String title,
      required CyberBorderGradientCenter borderGradientCenter,
    }) {
      return Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gaugeSize = math.max(
              1.0,
              math.min(
                constraints.maxWidth - 16,
                constraints.maxHeight - 16,
              ),
            );
            return MonitorGlassCard(
              height: constraints.maxHeight,
              padding: const EdgeInsets.all(8),
              borderGradientCenter: borderGradientCenter,
              child: Center(
                child: CurrentArcGauge(
                  visualStyle: GaugeVisualStyle.integratedRing,
                  value: value,
                  min: 0,
                  max: max,
                  majorTickEvery: majorTickEvery,
                  unit: unit,
                  title: title,
                  size: gaugeSize,
                  progressColor: const Color(0xFFD18846),
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              gaugeCard(
                value: s?.gasPressureKpa ?? 0,
                max: 1500,
                majorTickEvery: 150,
                unit: 'kPa',
                title: gasPressureTitle,
                borderGradientCenter:
                    CyberBorderGradientCenter.topLeftBottomRight,
              ),
              const SizedBox(width: MonitorDimens.gap),
              gaugeCard(
                value: s?.laserCurrentA ?? 0,
                max: 100,
                majorTickEvery: 10,
                unit: 'A',
                title: laserCurrentTitle,
                borderGradientCenter:
                    CyberBorderGradientCenter.bottomLeftTopRight,
              ),
            ],
          ),
        ),
        const SizedBox(height: MonitorDimens.gap),
        _MachineStatusTileGrid(tiles: tiles),
      ],
    );
  }
}

class _MachineStatusTileGrid extends StatelessWidget {
  const _MachineStatusTileGrid({required this.tiles});

  final List<(String, bool?)> tiles;

  static const _cols = 4;

  @override
  Widget build(BuildContext context) {
    final rows = (tiles.length / _cols).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: MonitorDimens.gap),
          SizedBox(
            height: MonitorDimens.tileH,
            child: Row(
              children: [
                for (var col = 0; col < _cols; col++) ...[
                  if (col > 0) const SizedBox(width: MonitorDimens.gap),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final index = row * _cols + col;
                        if (index >= tiles.length) {
                          return const SizedBox.shrink();
                        }
                        return MonitorStatusTile(
                          label: tiles[index].$1,
                          on: tiles[index].$2,
                          height: MonitorDimens.tileH,
                          borderGradientCenter: switch (index % 3) {
                            0 => CyberBorderGradientCenter.topLeftBottomRight,
                            1 => CyberBorderGradientCenter.bottomLeftTopRight,
                            _ => CyberBorderGradientCenter.topRightBottomLeft,
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MachineDeviceHealthSection extends StatefulWidget {
  const _MachineDeviceHealthSection();

  @override
  State<_MachineDeviceHealthSection> createState() =>
      _MachineDeviceHealthSectionState();
}

class _MachineDeviceHealthSectionState
    extends State<_MachineDeviceHealthSection> {
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
    super.dispose();
  }

  /// `null` → idle (empty); `true` → fault; `false` → ok.
  MonitorIndicatorKind _commKind(bool? fault) {
    if (fault == null) {
      return MonitorIndicatorKind.idle;
    }
    return fault ? MonitorIndicatorKind.failure : MonitorIndicatorKind.success;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final m = _monitor ?? WarnAlarmScope.maybeOf(context)?.monitor;
    const hPad = EdgeInsets.symmetric(horizontal: MonitorDimens.pad);
    const cardGap = SizedBox(height: SettingsDimens.inset);

    return KeyedSubtree(
      key: const ValueKey('machine-status-device-health'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: hPad,
            child: MonitorSectionHeader(l10n.deviceMonitorDeviceHealthTitle),
          ),
          _HealthGroupHeader(l10n.alarmInfoLaserDevice, topInset: 8),
          Padding(
            padding: hPad,
            child: MonitorCommCard(
              label: l10n.pumpStatusText,
              kind: _commKind(m?.laserCommFault),
            ),
          ),
          _HealthGroupHeader(l10n.alarmInfoWeldingGun),
          Padding(
            padding: hPad,
            child: MonitorCommCard(
              label: l10n.gunHeadCommunicationText,
              kind: _commKind(m?.gunCommFault),
            ),
          ),
          cardGap,
          Padding(
            padding: hPad,
            child: SettingsParamRow(
              left: MonitorTempMetricCard(
                series: m?.motor ?? _emptyTemp,
                label: l10n.gunMotorTempText,
                overTemp: m?.gunMotorOverTemp ?? false,
              ),
              right: MonitorTempMetricCard(
                series: m?.motorDriver ?? _emptyTemp,
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
                label: l10n.protectiveMirrorTemperatureText,
                overTemp: m?.protectiveMirrorOverTemp ?? false,
              ),
              right: MonitorTempMetricCard(
                series: m?.collimator ?? _emptyTemp,
                label: l10n.collimatorTemperatureText,
                overTemp: m?.collimatorOverTemp ?? false,
              ),
            ),
          ),
          _HealthGroupHeader(l10n.alarmInfoWireFeeder),
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
    );
  }
}

class _HealthGroupHeader extends StatelessWidget {
  const _HealthGroupHeader(this.title, {this.topInset = 36});

  final String title;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MonitorDimens.pad,
        topInset,
        MonitorDimens.pad,
        8,
      ),
      child: Text(
        title.toUpperCase(),
        style: context.hmiTypography.settingsRowTitle.copyWith(
          color: CyberColors.textSecondary,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AlarmLogsPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _AlarmLogsPinnedHeaderDelegate({
    required this.title,
    required this.clearLabel,
    required this.onClear,
  });

  final String title;
  final String clearLabel;
  final VoidCallback? onClear;

  @override
  double get minExtent => _kAlarmLogsPinnedHeaderExtent;

  @override
  double get maxExtent => _kAlarmLogsPinnedHeaderExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    const iconSize = HmiButtonMetrics.smallIconSize;
    return ColoredBox(
      key: const ValueKey('machine-status-alarm-logs'),
      color: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        height: _kAlarmLogsPinnedHeaderExtent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MonitorDimens.pad,
                8,
                MonitorDimens.pad,
                16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.hmiTypography.pageTitle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  MonitorFrostActionButton(
                    key: const ValueKey('machine-status-clear-alarm-logs'),
                    size: HmiButtonSize.small,
                    variant: CyberButtonVariant.secondary,
                    clickSoundEnabled: false,
                    onPressed: onClear,
                    label: clearLabel,
                    leading: Image.asset(
                      'assets/warn/alarm_button_icon.webp',
                      width: iconSize,
                      height: iconSize,
                      color: CyberColors.buttonSecondaryText,
                      colorBlendMode: BlendMode.srcIn,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.delete_outline,
                        size: iconSize,
                        color: CyberColors.buttonSecondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ProductTopTabs.dividerInset,
              ),
              child: ColoredBox(
                color: ProductTopTabs.dividerColor,
                child: SizedBox(
                  height: ProductTopTabs.dividerThickness,
                  width: double.infinity,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AlarmLogsPinnedHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        clearLabel != oldDelegate.clearLabel ||
        onClear != oldDelegate.onClear;
  }
}

/// Clips the following sliver so pinned-header overlap does not paint through.
/// Same rule as tab content below [ProductTopTabs] hairline.
class _SliverClipPinnedOverlap extends SingleChildRenderObjectWidget {
  const _SliverClipPinnedOverlap({super.key, required Widget sliver})
      : super(child: sliver);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSliverClipPinnedOverlap();
  }
}

class _RenderSliverClipPinnedOverlap extends RenderProxySliver {
  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || geometry == null || !geometry!.visible) {
      _clipRectLayer.layer = null;
      return;
    }
    final overlap = math.max(0.0, constraints.overlap);
    if (overlap <= 0) {
      _clipRectLayer.layer = null;
      context.paintChild(child!, offset);
      return;
    }
    final height = math.max(0.0, geometry!.paintExtent - overlap);
    if (height <= 0) {
      _clipRectLayer.layer = null;
      return;
    }
    _clipRectLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTWH(0, overlap, constraints.crossAxisExtent, height),
      (context, offset) => context.paintChild(child!, offset),
      oldLayer: _clipRectLayer.layer,
    );
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    if (mainAxisPosition < constraints.overlap) {
      return false;
    }
    return super.hitTestChildren(
      result,
      mainAxisPosition: mainAxisPosition,
      crossAxisPosition: crossAxisPosition,
    );
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }
}
