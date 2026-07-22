import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/application/machine_status_controller.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';

/// lws-ui `fragment_machine_status` — dual gauges + 7 status tiles (4+3).
class MachineStatusTab extends StatefulWidget {
  const MachineStatusTab({super.key});

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
      ctrl.start();
    });
  }

  void _onUpdate() {
    if (mounted) {
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
    final s = _ctrl;
    final tiles = <(String, bool?)>[
      ('Laser', s?.laserOn),
      ('Blow', s?.blowOn),
      ('Safety Lock', s?.safetyLockOn),
      ('Gun Switch', s?.gunSwitchOn),
      ('Red Light', s?.redLightOn),
      ('Wire Feeding', s?.wireFeedingOn),
      ('Camera', s?.cameraOn),
    ];

    return Padding(
      padding: const EdgeInsets.all(MonitorDimens.pad),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gaugeH = (constraints.maxHeight * 0.52).clamp(220.0, 300.0);
          final gaugeSize = (gaugeH - 24).clamp(180.0, 260.0);
          return Column(
            children: [
              SizedBox(
                height: gaugeH,
                child: Row(
                  children: [
                    Expanded(
                      child: MonitorGlassCard(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: CurrentArcGauge(
                            value: s?.gasPressureKpa ?? 0,
                            min: 0,
                            // lws-ui MachineStatusBaseFragment.setBlowAirPressure max.
                            max: 1500,
                            // lws-ui CircleProgressView: scaleInterval = max/10.
                            majorTickEvery: 150,
                            minorTickEvery: 30,
                            unit: 'kPa',
                            titleLine1: 'Gas',
                            titleLine2: 'Pressure',
                            size: gaugeSize,
                            progressColor: const Color(0xFF4FC3F7),
                            trackColor: const Color(0xFF2A3550),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: MonitorGlassCard(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: CurrentArcGauge(
                            value: s?.laserCurrentA ?? 0,
                            min: 0,
                            // lws-ui MachineStatusBaseFragment.setPumpSourceCurrent max.
                            max: 100,
                            // lws-ui CircleProgressView: scaleInterval = max/10.
                            majorTickEvery: 10,
                            minorTickEvery: 2,
                            unit: 'A',
                            titleLine1: 'Laser',
                            titleLine2: 'Current',
                            size: gaugeSize,
                            progressColor: const Color(0xFF4FC3F7),
                            trackColor: const Color(0xFF2A3550),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, tileConstraints) {
                    const cols = 4;
                    const gap = 24.0;
                    final tileW =
                        (tileConstraints.maxWidth - gap * (cols - 1)) / cols;
                    // Keep both rows visible: shrink tile height if needed.
                    final rows = (tiles.length / cols).ceil();
                    final maxTileH =
                        (tileConstraints.maxHeight - gap * (rows - 1)) / rows;
                    final tileH = maxTileH.clamp(72.0, MonitorDimens.tileH);
                    return Align(
                      alignment: Alignment.topCenter,
                      child: Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final tile in tiles)
                            SizedBox(
                              width: tileW,
                              height: tileH,
                              child: MonitorStatusTile(
                                label: tile.$1,
                                on: tile.$2,
                                height: tileH,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
