import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_tab_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

/// Compact Icon + Label group for primary top tabs.
///
/// Layout: horizontal padding → [Row] (`mainAxisSize: min`) →
/// icon ([HmiTabMetrics.iconSize]) → gap 8 → label 24.
/// Callers center this in the full-cell hit target; do not Position icon/label
/// separately.
final class HmiPrimaryTabContent extends StatelessWidget {
  const HmiPrimaryTabContent({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
  });

  /// Pre-sized icon face (typically [Icon] or [Image] at [HmiTabMetrics.iconSize]).
  final Widget icon;
  final String label;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final style = context.hmiTypography.primaryTabLabel.copyWith(
      color: color,
      fontWeight: selected
          ? HmiTabMetrics.selectedLabelWeight
          : HmiTabMetrics.labelWeight,
      height: 1.0,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HmiTabMetrics.horizontalPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: HmiTabMetrics.iconSize,
            height: HmiTabMetrics.iconSize,
            child: icon,
          ),
          const SizedBox(width: HmiTabMetrics.iconLabelGap),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
