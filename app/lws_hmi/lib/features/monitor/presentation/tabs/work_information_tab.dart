import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

/// lws-ui `WorkInfoFragment` — 3 percent gauges + 3 data cards.
class WorkInformationTab extends StatelessWidget {
  const WorkInformationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                    // lws-ui `welding_proportion_text`
                    title: l10n.weldingProportionText,
                    value: 0,
                    color: const Color(0xFFFF0000),
                    // Weld → diagonal bright edge.
                    borderGradientCenter:
                        CyberBorderGradientCenter.topLeftBottomRight,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _PercentCard(
                    // lws-ui `cutting_proportion_text`
                    title: l10n.cuttingProportionText,
                    value: 0,
                    color: const Color(0xFF00A4F2),
                    // Cut → top↔bottom bright edge.
                    borderGradientCenter: CyberBorderGradientCenter.topBottom,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _PercentCard(
                    // lws-ui `wash_proportion_text`
                    title: l10n.washProportionText,
                    value: 0,
                    color: const Color(0xFFFF8000),
                    borderGradientCenter:
                        CyberBorderGradientCenter.bottomLeftTopRight,
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
                Expanded(
                  child: MonitorWorkDataCard(
                    // lws-ui `warn_info_light_time`
                    title: l10n.warnInfoLightTime,
                    value: '-',
                    suffix: 'h',
                    borderGradientCenter:
                        CyberBorderGradientCenter.topLeftBottomRight,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: MonitorWorkDataCard(
                    // lws-ui `warn_info_welding_consumables`
                    title: l10n.warnInfoWeldingConsumables,
                    value: '-',
                    suffix: 'm',
                    // Match Cut: top↔bottom bright edge.
                    borderGradientCenter: CyberBorderGradientCenter.topBottom,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: MonitorWorkDataCard(
                    // lws-ui `warn_info_last_work`
                    title: l10n.warnInfoLastWork,
                    value: '-',
                    borderGradientCenter:
                        CyberBorderGradientCenter.topRightBottomLeft,
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
    this.borderGradientCenter =
        CyberBorderGradientCenter.topLeftBottomRight,
  });

  final String title;
  final double value;
  final Color color;
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    return MonitorGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      borderGradientCenter: borderGradientCenter,
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.hmiTypography.navigation.copyWith(color: Colors.white),
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
