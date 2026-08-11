import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

import '../theme/settings_typography.dart';
import 'settings_row_frame.dart';

/// Nav row — title left, optional trailing summary, chevron when tappable.
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.title,
    this.value,
    this.leading,
    this.trailingExtra,
    this.onTap,
    this.showChevron,
    this.minHeight,
  });

  final String title;
  final String? value;
  final Widget? leading;
  final Widget? trailingExtra;
  final VoidCallback? onTap;
  final bool? showChevron;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final typography = SettingsTypography.of(context);
    final chevron = showChevron ?? (onTap != null);
    return SettingsRowFrame(
      onTap: onTap,
      minHeight: minHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 16)],
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: typography.rowTitle,
            ),
          ),
          const SizedBox(width: 12),
          if (trailingExtra != null) ...[
            trailingExtra!,
            const SizedBox(width: 8),
          ],
          if (value != null && value!.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                value!,
                overflow: TextOverflow.ellipsis,
                style: typography.rowValue,
              ),
            ),
          if (chevron) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: CyberColors.textSecondary),
          ],
        ],
      ),
    );
  }
}
