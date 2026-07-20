import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';

/// lws-ui `WorkInfoFragment` — 3 percent gauges + 3 data cards.
class WorkInformationTab extends StatelessWidget {
  const WorkInformationTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MonitorDimens.pad),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: _PercentCard(
                    title: 'Weld Time Ratio',
                    value: 0,
                    color: const Color(0xFFFF0000),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _PercentCard(
                    title: 'Cut Time Ratio',
                    value: 0,
                    color: const Color(0xFF00A4F2),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _PercentCard(
                    title: 'Clean Time Ratio',
                    value: 0,
                    color: const Color(0xFFFF8000),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Expanded(
                  child: MonitorWorkDataCard(
                    title: 'Laser On Time',
                    value: '-',
                    suffix: 'h',
                  ),
                ),
                const SizedBox(width: 24),
                const Expanded(
                  child: MonitorWorkDataCard(
                    title: 'Welding Consumables',
                    value: '-',
                    suffix: 'm',
                  ),
                ),
                const SizedBox(width: 24),
                const Expanded(
                  child: MonitorWorkDataCard(
                    title: 'Last Job',
                    value: '-',
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

class _PercentCard extends StatelessWidget {
  const _PercentCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MonitorGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 22),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side =
                    math.min(constraints.maxWidth, constraints.maxHeight);
                return Center(
                  child: PercentArcGauge(
                    value: value,
                    size: side.clamp(120.0, 220.0),
                    strokeWidth: 18,
                    progressColor: color,
                    trackColor: const Color(0xFF5A5A5A),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
