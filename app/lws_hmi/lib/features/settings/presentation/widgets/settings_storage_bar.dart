import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/settings/application/storage_capacity.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// iOS-style segmented capacity bar for Device Information storage group.
class SettingsStorageBar extends StatelessWidget {
  const SettingsStorageBar({
    super.key,
    required this.summary,
  });

  final StorageCapacitySummary summary;

  String _mountLabel(AppLocalizations l10n, String mount) {
    switch (mount) {
      case '/':
        return l10n.storageMountSystem;
      case '/userdata':
        return l10n.storageMountUserData;
      default:
        return mount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = context.hmiTypography;
    final titleStyle = typography.settingsRowTitle.copyWith(
      color: CyberColors.textPrimary,
    );
    final captionStyle = typography.settingsRowValue.copyWith(
      color: CyberColors.textSecondary,
    );
    final legendStyle = typography.supporting.copyWith(
      color: CyberColors.textSecondary,
      fontSize: 14,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.storageTitle, style: titleStyle),
          const SizedBox(height: 8),
          if (!summary.hasData)
            Text(kUnavailableDisplay, style: captionStyle)
          else ...[
            Text(
              l10n.storageUsedOfTotal(
                formatStorageBytes(summary.usedBytes),
                formatStorageBytes(summary.totalBytes),
              ),
              style: captionStyle,
            ),
            const SizedBox(height: 12),
            _SegmentedBar(summary: summary),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final seg in summary.segments)
                  _LegendDot(
                    color: seg.color,
                    label:
                        '${_mountLabel(l10n, seg.mountPoint)}  ${formatStorageBytes(seg.usedBytes)}',
                    style: legendStyle,
                  ),
                _LegendDot(
                  color: StorageBarColors.available,
                  label:
                      '${l10n.storageAvailableLegend}  ${formatStorageBytes(summary.availableBytes)}',
                  style: legendStyle,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.summary});

  final StorageCapacitySummary summary;

  static const _height = 22.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final total = summary.totalBytes.toDouble();
        if (width <= 0 || total <= 0) {
          return const SizedBox(height: _height);
        }
        // Explicit height on every segment — ColoredBox collapses to 0 height
        // when only width is tight and height is loose.
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: _height,
            width: width,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final seg in summary.segments)
                  SizedBox(
                    width: (seg.usedBytes / total * width).clamp(0.0, width),
                    child: ColoredBox(color: seg.color),
                  ),
                const Expanded(
                  child: ColoredBox(color: StorageBarColors.available),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.style,
  });

  final Color color;
  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }
}
