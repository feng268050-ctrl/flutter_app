import 'package:flutter/material.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/application/machine_status_controller.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// lws-ui `fragment_machine_status` — dual gauges + 7 status tiles (4+3).
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final services = AppScope.maybeOf(context);
      if (services == null || !mounted) {
        return;
      }
      final ctrl = MachineStatusController(services);
      ctrl.addListener(_onUpdate);
      setState(() => _ctrl = ctrl);
      if (widget.visible) {
        ctrl.start();
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = _ctrl;
    // Labels match lws-ui `fragment_machine_status` string refs.
    final tiles = <(String, bool?)>[
      (l10n.laserText, s?.laserOn),
      (l10n.blowText, s?.blowOn),
      (l10n.safetyLockText, s?.safetyLockOn),
      (l10n.gunHeadSwitchText, s?.gunSwitchOn),
      (l10n.redLightText, s?.redLightOn),
      (l10n.wireFeedingText, s?.wireFeedingOn),
      (l10n.ipCameraText, s?.cameraOn),
    ];

    // Edge inset == inter-card / inter-tile gap ([MonitorDimens.pad] /
    // [MonitorDimens.gap]) on all four sides and between sibling containers.
    return Padding(
      padding: const EdgeInsets.all(MonitorDimens.pad),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gaugeSize = (constraints.maxHeight - 16)
                    .clamp(160.0, 260.0);
                return Row(
                  children: [
                    Expanded(
                      child: MonitorGlassCard(
                        padding: const EdgeInsets.all(8),
                        borderGradientCenter:
                            CyberBorderGradientCenter.topLeftBottomRight,
                        child: Center(
                          child: CurrentArcGauge(
                            value: s?.gasPressureKpa ?? 0,
                            min: 0,
                            // lws-ui MachineStatusBaseFragment.setBlowAirPressure max.
                            max: 1500,
                            // lws-ui CircleProgressView: scaleInterval = max/10.
                            majorTickEvery: 150,
                            unit: 'kPa',
                            titleLine1: l10n.machineBlowTitle,
                            titleLine2: l10n.machineBlowContent,
                            size: gaugeSize,
                            progressColor: const Color(0xFF4FC3F7),
                            trackColor: const Color(0x33FFFFFF),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: MonitorDimens.gap),
                    Expanded(
                      child: MonitorGlassCard(
                        padding: const EdgeInsets.all(8),
                        borderGradientCenter:
                            CyberBorderGradientCenter.bottomLeftTopRight,
                        child: Center(
                          child: CurrentArcGauge(
                            value: s?.laserCurrentA ?? 0,
                            min: 0,
                            // lws-ui MachineStatusBaseFragment.setPumpSourceCurrent max.
                            max: 100,
                            // lws-ui CircleProgressView: scaleInterval = max/10.
                            majorTickEvery: 10,
                            unit: 'A',
                            titleLine1: l10n.machineLaserCurrentTitle,
                            titleLine2: l10n.machineLaserCurrentContent,
                            size: gaugeSize,
                            progressColor: const Color(0xFF4FC3F7),
                            trackColor: const Color(0x33FFFFFF),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: MonitorDimens.gap),
          Expanded(
            flex: 4,
            child: _MachineStatusTileGrid(tiles: tiles),
          ),
        ],
      ),
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
          Expanded(
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
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            // Fill the cell so row/column gaps stay exactly
                            // [MonitorDimens.gap] (same as page edge inset).
                            final tileH = constraints.maxHeight;
                            return MonitorStatusTile(
                              label: tiles[index].$1,
                              on: tiles[index].$2,
                              height: tileH,
                              borderGradientCenter: switch (index % 3) {
                                0 => CyberBorderGradientCenter
                                    .topLeftBottomRight,
                                1 => CyberBorderGradientCenter
                                    .bottomLeftTopRight,
                                _ => CyberBorderGradientCenter
                                    .topRightBottomLeft,
                              },
                            );
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
