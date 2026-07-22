import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/status_bar/cyber_home_status_bar.dart';
import 'package:cyber_ui/src/status_bar/cyber_status_bar_clock.dart';
import 'package:flutter/material.dart';

/// Non-Home page chrome: back · centered title · status icons + clock.
///
/// Background defaults to ambient AppBar / surface theme color; override with
/// [backgroundColor]. Does not call [Navigator] — supply [onBack].
class CyberPageStatusBar extends StatelessWidget implements PreferredSizeWidget {
  const CyberPageStatusBar({
    super.key,
    required this.title,
    this.onBack,
    this.statusItems = const [],
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.statusIconGap = 12,
    this.clockGap = 12,
    this.toolbarHeight = kToolbarHeight,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> statusItems;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double statusIconGap;
  final double clockGap;
  final double toolbarHeight;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(toolbarHeight + bottomHeight);
  }

  Color _resolveBackground(BuildContext context) {
    if (backgroundColor != null) {
      return backgroundColor!;
    }
    final theme = Theme.of(context);
    return theme.appBarTheme.backgroundColor ??
        theme.colorScheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foregroundColor ??
        theme.appBarTheme.foregroundColor ??
        theme.colorScheme.onSurface;
    final bg = _resolveBackground(context);

    return AppBar(
      key: const ValueKey('cyber-page-status-bar'),
      title: Text(title),
      centerTitle: true,
      backgroundColor: bg,
      foregroundColor: fg,
      automaticallyImplyLeading: false,
      leading: onBack == null
          ? null
          : IconButton(
              key: const ValueKey('cyber-page-status-bar-back'),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                CyberClickSoundRegistry.playClick();
                onBack!();
              },
            ),
      actions: [
        ...?actions,
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CyberHomeStatusBar(
                items: statusItems,
                gap: statusIconGap,
              ),
              if (statusItems.isNotEmpty) SizedBox(width: clockGap),
              CyberStatusBarClock(
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: bottom,
    );
  }
}
