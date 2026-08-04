import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/ip_camera/presentation/ip_camera_preview.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/monitor/application/machine_status_controller.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/temperature_unit_convert.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

/// Manual More Status route name (confirm bar). Distinct from gun-managed.
const liveMachineStatusManualRouteName = 'manual-live-machine-status';

/// lws-ui [MachineStatusOverlay] — light frost + live PR1 video (not Monitor route).
///
/// Quick Mode “More Status” opens this with a confirm action
/// (`MachineStatusOverlay.show(context, true)`). Gun path uses
/// [WorkStatusDialogHost.showNoConfirmDialog] (`showConfirmButton: false`).
Future<void> showLiveMachineStatusDialog(
  BuildContext context, {
  IpCameraPreviewPlayerFactory? playerFactory,
  bool showConfirmButton = true,
  String? routeName,
  void Function(BuildContext dialogContext)? onDialogContext,
}) {
  final panel = CyberPanelBorder(tone: CyberTone.light);
  return showDialog<void>(
    context: context,
    barrierDismissible: !showConfirmButton,
    barrierColor: CyberColors.scrim,
    routeSettings: RouteSettings(
      name: routeName ??
          (showConfirmButton
              ? liveMachineStatusManualRouteName
              : 'live-machine-status'),
    ),
    builder: (dialogContext) {
      onDialogContext?.call(dialogContext);
      // lws-ui `machine_status_dialog_screen_inset` = 2dp.
      const screenInset = 2.0;
      final size = MediaQuery.sizeOf(dialogContext);
      final maxW = (size.width - screenInset * 2).clamp(480.0, 1280.0);
      final maxH = (size.height - screenInset * 2).clamp(420.0, 800.0);
      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: SizedBox(
            width: maxW,
            height: maxH,
            child: ClipRRect(
              borderRadius: panel.borderRadius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: panel.borderRadius,
                  border: Border.all(
                    color: panel.flatBorderColor,
                    width: panel.width,
                  ),
                ),
                child: CyberModal(
                  sampleMode: CyberBlurSampleMode.firstFrame,
                  intensity: CyberBlurIntensity.high,
                  blurTint: CyberBlurTint.warm,
                  useFakeGlass: true,
                  borderRadius: panel.borderRadius,
                  // Horizontal pad 0 so the live frame sits 2px from screen edges.
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
                  child: _LiveMachineStatusBody(
                    playerFactory: playerFactory,
                    showConfirmButton: showConfirmButton,
                    onConfirm: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

final class _LiveMachineStatusBody extends StatefulWidget {
  const _LiveMachineStatusBody({
    required this.onConfirm,
    required this.showConfirmButton,
    this.playerFactory,
  });

  final VoidCallback onConfirm;
  final bool showConfirmButton;
  final IpCameraPreviewPlayerFactory? playerFactory;

  @override
  State<_LiveMachineStatusBody> createState() => _LiveMachineStatusBodyState();
}

final class _LiveMachineStatusBodyState extends State<_LiveMachineStatusBody> {
  static const _titleDark = Color(0xFF1A1A1A);
  static const _liveGaugeSidePad = 12.0;
  /// Equal: above gauges and below status tiles.
  static const _liveEdgeGap = 12.0;
  static const _liveStatusGap = 8.0;
  static const _metricGap = 8.0;
  static const _gaugeToMetricsGap = 10.0;

  /// Shared empty series when [WarnAlarmScope] is absent (tests / early bind).
  static final _emptyTemp = TempSeries();

  IpCameraProductSession? _session;
  IpCameraUiStatus _status = IpCameraUiStatus.connecting;
  StreamSubscription<IpCameraUiStatus>? _statusSub;
  MachineStatusController? _machine;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bind());
    });
  }

  Future<void> _bind() async {
    final services = AppScope.maybeOf(context);
    if (services == null || !mounted) {
      setState(
        () => _error =
            AppLocalizations.of(context)!.deviceControlCameraUnavailable,
      );
      return;
    }

    final machine = MachineStatusController(services);
    machine.addListener(_onMachine);
    unawaited(machine.start());

    try {
      final session = await services.ensureIpCamera();
      if (!mounted) {
        machine.dispose();
        return;
      }
      setState(() {
        _session = session;
        _machine = machine;
        _status = session.currentStatus;
        _error = null;
      });
      await _statusSub?.cancel();
      _statusSub = session.status.listen((s) {
        if (mounted) {
          setState(() => _status = s);
        }
      });
      await session.start();
      await session.ensureReady();
      if (mounted) {
        setState(() => _status = session.currentStatus);
      }
    } catch (e) {
      machine.removeListener(_onMachine);
      machine.dispose();
      if (mounted) {
        setState(() => _error = '$e');
      }
    }
  }

  void _onMachine() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    unawaited(_statusSub?.cancel() ?? Future<void>.value());
    final machine = _machine;
    machine?.removeListener(_onMachine);
    machine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // lws-ui `real_time_machine_status_text` (not Monitor tab title).
    final liveTitle =
        l10n?.liveMachineStatusTitle ?? 'Live Machine Status';

    final session = _session;
    // lws-ui LaserLiveMonitorOverlayFragment uses PR1; fall back to PR0.
    final rtsp = session?.previewPr1 ?? session?.previewPr0;
    final relayReady = session?.previewReady ?? false;
    final machine = _machine;

    final tiles = <(String, bool?)>[
      (l10n?.laserOnLabel ?? 'Laser', machine?.laserOn),
      (l10n?.blowOnLabel ?? 'Blow', machine?.blowOn),
      (l10n?.safetyLockLabel ?? 'Safety Lock', machine?.safetyLockOn),
      (l10n?.gunSwitchLabel ?? 'Gun Switch', machine?.gunSwitchOn),
      (l10n?.redLightLabel ?? 'Red Light', machine?.redLightOn),
      (l10n?.wireFeedingText ?? 'Wire Feeder', machine?.wireFeedingOn),
    ];

    return Column(
      key: const ValueKey('live-machine-status-dialog'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            liveTitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _titleDark,
              fontSize: AppTypography.pageTitleSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_error != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: AppTypography.supportingSize,
                              ),
                            ),
                          ),
                        )
                      else
                        IpCameraPreview(
                          key: const ValueKey('live-machine-status-preview'),
                          rtspUrl: rtsp,
                          linkPhase: _status.phase,
                          relayReady: relayReady,
                          playerFactory:
                              widget.playerFactory ?? createIpCameraPreviewPlayer,
                        ),
                      // Top gap == status bottom gap; temps fill middle remainder.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: _liveEdgeGap),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _liveGaugeSidePad,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _GaugePanel(
                                  child: CurrentArcGauge(
                                    value: machine?.gasPressureKpa ?? 0,
                                    min: 0,
                                    max: 1500,
                                    majorTickEvery: 150,
                                    unit: 'kPa',
                                    titleLine1:
                                        l10n?.machineBlowTitle ?? 'Blow',
                                    titleLine2:
                                        l10n?.machineBlowContent ?? 'Pressure',
                                    size: _LiveGaugeDimens.gaugeSide,
                                    trackWidth: _LiveGaugeDimens.trackWidth,
                                  ),
                                ),
                                const Spacer(),
                                _GaugePanel(
                                  child: CurrentArcGauge(
                                    value: machine?.laserCurrentA ?? 0,
                                    min: 0,
                                    max: 100,
                                    majorTickEvery: 10,
                                    unit: 'A',
                                    titleLine1:
                                        l10n?.machineLaserCurrentTitle ??
                                            'Laser',
                                    titleLine2:
                                        l10n?.machineLaserCurrentContent ??
                                            'Current',
                                    size: _LiveGaugeDimens.gaugeSide,
                                    trackWidth: _LiveGaugeDimens.trackWidth,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: _gaugeToMetricsGap),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: _liveGaugeSidePad,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: _LiveGaugeDimens.panelW,
                                    child: _MotorTempMetrics(l10n: l10n),
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: _LiveGaugeDimens.panelW,
                                    child: _LensTempMetrics(l10n: l10n),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: _liveStatusGap),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    _liveEdgeGap,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(width: _liveStatusGap),
                        Expanded(
                          child: _CompactStatusTile(
                            label: tiles[i].$1,
                            on: tiles[i].$2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.showConfirmButton) ...[
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 280,
              child: CyberButton(
                key: const ValueKey('live-machine-status-confirm'),
                size: CyberButtonSize.small,
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                stretch: true,
                onPressed: widget.onConfirm,
                child: Text(
                  l10n?.gotItText ?? 'Got It',
                  style: const TextStyle(
                    fontSize: AppTypography.controlSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Left column under Gas Pressure: Motor + Motor Driver (adaptive height).
final class _MotorTempMetrics extends StatelessWidget {
  const _MotorTempMetrics({required this.l10n});

  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    return _AlarmTempPair(
      builder: (monitor) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _LiveTempMetricCard(
              series: monitor?.motor ?? _LiveMachineStatusBodyState._emptyTemp,
              label: l10n?.motorTempLabel ?? 'Motor',
              overTemp: monitor?.gunMotorOverTemp ?? false,
            ),
          ),
          const SizedBox(height: _LiveMachineStatusBodyState._metricGap),
          Expanded(
            child: _LiveTempMetricCard(
              series: monitor?.motorDriver ??
                  _LiveMachineStatusBodyState._emptyTemp,
              label: l10n?.motorDriverTempLabel ?? 'Motor Driver',
              overTemp: monitor?.driverOverTemp ?? false,
            ),
          ),
        ],
      ),
    );
  }
}

/// Right column under Laser Current: Protective Mirror + Collimator.
final class _LensTempMetrics extends StatelessWidget {
  const _LensTempMetrics({required this.l10n});

  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    return _AlarmTempPair(
      builder: (monitor) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _LiveTempMetricCard(
              series: monitor?.protectiveMirror ??
                  _LiveMachineStatusBodyState._emptyTemp,
              label: l10n?.protectiveMirrorTempLabel ?? 'Protective Mirror',
              overTemp: monitor?.protectiveMirrorOverTemp ?? false,
            ),
          ),
          const SizedBox(height: _LiveMachineStatusBodyState._metricGap),
          Expanded(
            child: _LiveTempMetricCard(
              series:
                  monitor?.collimator ?? _LiveMachineStatusBodyState._emptyTemp,
              label: l10n?.collimatorTempLabel ?? 'Collimator',
              overTemp: monitor?.collimatorOverTemp ?? false,
            ),
          ),
        ],
      ),
    );
  }
}

final class _AlarmTempPair extends StatelessWidget {
  const _AlarmTempPair({required this.builder});

  final Widget Function(AlarmMonitorState? monitor) builder;

  @override
  Widget build(BuildContext context) {
    final monitor = WarnAlarmScope.maybeOf(context)?.monitor;
    if (monitor == null) {
      return builder(null);
    }
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) => builder(monitor),
    );
  }
}

/// Live More Status temp row: name left, value right; no status light.
///
/// Panel chrome matches [_GaugePanel]. Label turns white when a reading exists.
final class _LiveTempMetricCard extends StatelessWidget {
  const _LiveTempMetricCard({
    required this.series,
    required this.label,
    required this.overTemp,
  });

  final TempSeries series;
  final String label;
  final bool overTemp;

  static const _idleLabel = Color(0xFFB0B1C2);
  static const _faultValue = Color(0xFFFF8A80);

  @override
  Widget build(BuildContext context) {
    final common = CommonSettingsScope.maybeOf(context);
    final l10n = AppLocalizations.of(context);

    Widget card() {
      final unit = common?.unit;
      final hasValue = series.lastCelsius != null;
      final String value;
      if (overTemp && !hasValue) {
        value = l10n?.overTempLabel ?? 'Over Temp';
      } else if (hasValue) {
        value = TemperatureUnitConvert.formatSensorCelsius(
          series.lastCelsius!,
          unit,
        );
      } else {
        value = kUnavailableDisplay;
      }
      final labelActive = hasValue || overTemp;
      return SizedBox.expand(
        child: DecoratedBox(
          decoration: _LivePanelChrome.decoration,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelActive ? Colors.white : _idleLabel,
                      fontSize: MonitorDimens.metricLabelSize,
                      fontWeight: FontWeight.w400,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: overTemp ? _faultValue : Colors.white,
                    fontSize: MonitorDimens.metricValueSize,
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (common == null) {
      return card();
    }
    return ListenableBuilder(
      listenable: common,
      builder: (context, _) => card(),
    );
  }
}

/// Shared frosted-black panel chrome for gauges + live temp cards.
abstract final class _LivePanelChrome {
  static const fill = Color(0x99000000);
  static const border = Color(0x33FFFFFF);
  static const radius = 14.0;

  static BoxDecoration get decoration => BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      );
}

/// lws-ui `laser_live_monitor_gauge_*` (panel size fixed).
abstract final class _LiveGaugeDimens {
  static const panelW = 280.0;
  static const panelH = 250.0;

  /// Prefer a little inset on all sides while keeping L=R and T=B.
  static double get gaugeSide {
    const minInset = 8.0;
    final short = panelH < panelW ? panelH : panelW;
    return short - 2 * minInset; // 250 - 16 = 234
  }

  static double get padH => (panelW - gaugeSide) / 2;
  static double get padV => (panelH - gaugeSide) / 2;

  static const trackWidth = 18.0;
}

final class _GaugePanel extends StatelessWidget {
  const _GaugePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Explicit equal insets: left==right (padH), top==bottom (padV).
    // Panel size stays [panelW]×[panelH].
    return SizedBox(
      width: _LiveGaugeDimens.panelW,
      height: _LiveGaugeDimens.panelH,
      child: DecoratedBox(
        decoration: _LivePanelChrome.decoration,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _LiveGaugeDimens.padH,
            _LiveGaugeDimens.padV,
            _LiveGaugeDimens.padH,
            _LiveGaugeDimens.padV,
          ),
          child: SizedBox(
            width: _LiveGaugeDimens.gaugeSide,
            height: _LiveGaugeDimens.gaugeSide,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// lws-ui [MachineStatusStatusTile]: whole-tile fill, no status glyph.
///
/// Success → `machine_status_tile_success_fill` (#FFF46E01);
/// idle / undetected → `machine_status_tile_idle_fill` (#99000000).
final class _CompactStatusTile extends StatelessWidget {
  const _CompactStatusTile({required this.label, required this.on});

  static const height = 52.0;

  final String label;
  final bool? on;

  static const _idleFill = Color(0x99000000);
  static const _successFill = Color(0xFFF46E01);

  @override
  Widget build(BuildContext context) {
    final active = on == true;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? _successFill : _idleFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x40FFFFFF)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
