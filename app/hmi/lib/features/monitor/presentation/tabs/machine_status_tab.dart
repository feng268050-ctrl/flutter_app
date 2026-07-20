import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';

/// lws-ui `fragment_machine_status` — dual gauges + 7 status tiles (4+3).
class MachineStatusTab extends StatelessWidget {
  const MachineStatusTab({super.key});

  static const _tiles = <String>[
    'Laser',
    'Blow',
    'Safety Lock',
    'Gun Switch',
    'Red Light',
    'Wire Feeding',
    'Camera',
  ];

  @override
  Widget build(BuildContext context) {
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
                            value: 0,
                            min: 0,
                            max: 100,
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
                            value: 0,
                            min: 0,
                            max: 100,
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
                    final rows = (_tiles.length / cols).ceil();
                    final maxTileH =
                        (tileConstraints.maxHeight - gap * (rows - 1)) / rows;
                    final tileH = maxTileH.clamp(72.0, MonitorDimens.tileH);
                    return Align(
                      alignment: Alignment.topCenter,
                      child: Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final label in _tiles)
                            SizedBox(
                              width: tileW,
                              height: tileH,
                              child: MonitorStatusTile(
                                label: label,
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
