import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/status_bar/cyber_home_status_bar.dart';
import 'package:cyber_ui/src/status_bar/cyber_status_bar_clock.dart';
import 'package:flutter/material.dart';

/// Non-Home page chrome: back · centered title (or clock) · status icons.
///
/// Background defaults to ambient AppBar / surface theme color; override with
/// [backgroundColor]. Does not call [Navigator] — supply [onBack].
class CyberPageStatusBar extends StatelessWidget implements PreferredSizeWidget {
  const CyberPageStatusBar({
    super.key,
    required this.title,
    this.onBack,
    this.leading,
    this.leadingWidth,
    this.statusItems = const [],
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.statusIconGap = 12,
    this.clockGap = 12,
    this.toolbarHeight = kToolbarHeight,
    this.clockNow,
    this.clockStyle,
    this.use24HourFormat = true,
    this.showClockDate = true,
    this.clockEndPadding = 55,
    this.centerClock = false,
  });

  final String title;
  final VoidCallback? onBack;

  /// When set, replaces the default Material back [IconButton].
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget> statusItems;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double statusIconGap;
  final double clockGap;
  final double toolbarHeight;

  /// Optional wall-clock source (e.g. OS civil time); defaults to [DateTime.now].
  final DateTime Function()? clockNow;

  /// When null, uses [TextTheme.titleMedium] + [foregroundColor].
  final TextStyle? clockStyle;

  /// Forwarded to [CyberStatusBarClock.use24HourFormat].
  final bool use24HourFormat;

  /// Weekday + date left of time (Settings / Monitor / …). Quick / Engineer
  /// use [WorkModeStatusBar] with time-only [CyberStatusBarClock].
  final bool showClockDate;

  /// Clock trailing inset vs screen end — matches Home Quick/Engineer mode
  /// entry top inset (`55` on the 1280×800 design canvas).
  final double clockEndPadding;

  /// When true, put [CyberStatusBarClock] in the AppBar title (centered) and
  /// keep only status icons on the trailing side (no trailing clock).
  final bool centerClock;

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

  TextStyle _resolvedClockStyle(ThemeData theme, Color fg) {
    return clockStyle ??
        theme.textTheme.titleMedium?.copyWith(
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ) ??
        TextStyle(
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foregroundColor ??
        theme.appBarTheme.foregroundColor ??
        theme.colorScheme.onSurface;
    final bg = _resolveBackground(context);
    final clockTextStyle = _resolvedClockStyle(theme, fg);

    final resolvedLeading = leading ??
        (onBack == null
            ? null
            : IconButton(
                key: const ValueKey('cyber-page-status-bar-back'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () {
                  CyberClickSoundRegistry.playClick();
                  onBack!();
                },
              ));

    final Widget titleWidget = centerClock
        ? CyberStatusBarClock(
            now: clockNow,
            use24HourFormat: use24HourFormat,
            showDate: showClockDate,
            style: clockTextStyle,
          )
        : Text(title);

    final List<Widget> trailing = [
      ...?actions,
      Padding(
        padding: EdgeInsets.only(right: clockEndPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CyberHomeStatusBar(
              items: statusItems,
              gap: statusIconGap,
            ),
            if (!centerClock) ...[
              if (statusItems.isNotEmpty) SizedBox(width: clockGap),
              CyberStatusBarClock(
                now: clockNow,
                use24HourFormat: use24HourFormat,
                showDate: showClockDate,
                style: clockTextStyle,
              ),
            ],
          ],
        ),
      ),
    ];

    return AppBar(
      key: const ValueKey('cyber-page-status-bar'),
      title: titleWidget,
      centerTitle: true,
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: false,
      actionsPadding: EdgeInsets.zero,
      leadingWidth: leadingWidth,
      leading: resolvedLeading == null
          ? null
          : SizedBox(
              height: toolbarHeight,
              width: leadingWidth,
              // Loose horizontal max so IntrinsicWidth / full labels do not
              // report a flex overflow when painter undershoots slightly.
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: leadingWidth == null
                    ? double.infinity
                    : leadingWidth! * 1.5,
                child: resolvedLeading,
              ),
            ),
      actions: trailing,
      bottom: bottom,
    );
  }
}
