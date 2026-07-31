import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Shared Settings chrome (lws-ui InsetList / FrostCard → CyberUI).
///
/// Interactive rows call [CyberClickSoundRegistry.playClick].
///
/// Device Information / Common Settings / Wi‑Fi / Camera MUST NOT use
/// [SettingsSectionHeader] — keep group names as Dart comments only.

/// Screen-edge inset and inter-group gap (lws-ui settings `padding="24dp"`).
/// Top / bottom / left / right / group-to-group must all use this value.
abstract final class SettingsDimens {
  static const inset = 24.0;

  /// Shared min height for switch / value / nav / slider / control rows.
  /// Device Info / General (+tabs nested lists).
  static const rowMinHeight = 70.0;

  /// Horizontal + vertical padding inside a settings row.
  static const rowPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 8);

  /// Gap between a settings card and [SettingsHelpFooter] under it.
  /// Preceding [SettingsGroup] must use `bottomInset: 0` so this is the only gap.
  static const helpGap = 8.0;

  /// Device Info / General list title & value (+2 vs prior 18).
  static const titleSize = 20.0;

  /// Secondary / subtitle / help (+2 vs prior 14).
  static const subtitleSize = 16.0;

  /// Uniform bright-edge stroke (no frost gradient).
  static const borderWidth = 1.5;

  /// Soft drop shadow for card depth on dark Settings chrome.
  static const cardShadow = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  /// Advanced tab body (+6 vs prior 16 title / 18 switch).
  static const advancedTitleSize = 22.0;
  static const advancedValueSize = 22.0;
  static const advancedSwitchTitleSize = 24.0;
  static const advancedSwitchSubtitleSize = 20.0;
  static const advancedSectionHeaderSize = 20.0;
}

/// Settings page Material-style top tabs (equal width, no rounded strip chrome).
///
/// L/R inset matches [SettingsDimens.inset] so the tab track, hairline, and
/// setting cards share the same outer edges. Every tab centers icon+label in
/// its equal-width cell; selection = bright label/icon + full-cell indicator.
final class SettingsTopTabs extends StatelessWidget
    implements PreferredSizeWidget {
  const SettingsTopTabs({
    super.key,
    required this.labels,
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
  });

  static const tabHeight = 68.0;
  static const dividerThickness = 1.0;
  static const iconSize = 31.0;
  static const labelSize = 27.0;
  static const iconTextGap = 6.0;
  static const indicatorHeight = 2.0;
  static const unselected = Color(0xFF94A3B8);
  static const dividerColor = Color(0x33FFFFFF);

  final List<String> labels;
  final List<({Key key, IconData icon})> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Size get preferredSize =>
      const Size.fromHeight(tabHeight + dividerThickness);

  @override
  Widget build(BuildContext context) {
    assert(labels.length == tabs.length);
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: tabHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SettingsDimens.inset,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _SettingsTopTabItem(
                        key: tabs[i].key,
                        label: labels[i],
                        icon: tabs[i].icon,
                        selected: i == currentIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Hairline matches card L/R — same [SettingsDimens.inset] as tabs.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: SettingsDimens.inset),
            child: ColoredBox(
              color: dividerColor,
              child: SizedBox(height: dividerThickness, width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

final class _SettingsTopTabItem extends StatelessWidget {
  const _SettingsTopTabItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : SettingsTopTabs.unselected;
    final labelStyle = TextStyle(
      color: color,
      fontSize: SettingsTopTabs.labelSize,
      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      height: 1.0,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          CyberClickSoundRegistry.playClick();
          onTap();
        },
        // Stretch so the indicator spans the full equal-width tab cell;
        // outer cell edges match [SettingsDimens.inset] with the cards.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: SettingsTopTabs.iconSize, color: color),
                      const SizedBox(width: SettingsTopTabs.iconTextGap),
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: labelStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: SettingsTopTabs.indicatorHeight,
              color: selected ? Colors.white : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(
    this.title, {
    super.key,
    this.fontSize = SettingsDimens.advancedSectionHeaderSize,
    this.topInset = SettingsDimens.inset,
  });

  final String title;
  final double fontSize;

  /// Space above the title (card → title). First group keeps [SettingsDimens.inset].
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SettingsDimens.inset,
        topInset,
        SettingsDimens.inset,
        8,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: CyberColors.textSecondary,
              letterSpacing: 0.6,
              fontSize: fontSize,
            ),
      ),
    );
  }
}

/// Operator help / footnote under a settings card.
///
/// Place immediately after a [SettingsGroup] with `bottomInset: 0` (or any
/// sibling that has no bottom margin) so card→help spacing is always
/// [SettingsDimens.helpGap], with L/R matching [SettingsDimens.inset].
class SettingsHelpFooter extends StatelessWidget {
  const SettingsHelpFooter(
    this.text, {
    super.key,
    this.bottomInset = SettingsDimens.inset,
  });

  final String text;

  /// Space below the footnote (use `0` when a [SettingsSectionHeader] follows).
  final double bottomInset;

  static const textStyle = TextStyle(
    color: Colors.white54,
    fontSize: SettingsDimens.subtitleSize,
    height: 1.35,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SettingsDimens.inset,
        SettingsDimens.helpGap,
        SettingsDimens.inset,
        bottomInset,
      ),
      child: Text(text, style: textStyle),
    );
  }
}

/// Settings group shell — Material [Card] outline, border-only (Frost
/// `transparent` blur: no live [BackdropFilter]).
///
/// Uniform bright edge + drop shadow (no frost gradient stroke).
/// [borderGradientCenter] is retained for call-site compatibility but ignored.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.child,
    this.borderGradientCenter =
        CyberBorderGradientCenter.topLeftBottomRight,
  });

  final Widget child;
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    final theme = CyberGlassTheme.of(context);
    final radius = BorderRadius.circular(theme.cornerRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: SettingsDimens.cardShadow,
      ),
      child: CyberOutlinedPanel(
        clipBehavior: Clip.none,
        outline: CyberPanelOutline(
          style: CyberPanelOutlineStyle.uniform,
          tone: theme.tone,
          width: SettingsDimens.borderWidth,
          cornerRadius: theme.cornerRadius,
          uniformColor: CyberColors.borderUniform,
        ),
        color: Colors.white.withOpacity(0.06),
        child: child,
      ),
    );
  }
}

/// Untitled settings group ([SettingsPanel] + inset dividers).
///
/// Outer margin: [SettingsDimens.inset] on left/right/bottom so group gap
/// equals distance to screen edges. Pair with [SettingsScrollView] top inset.
///
/// [borderGradientCenter] is unused (uniform outline); kept for call sites.
/// Set [bottomInset] to `0` when a following [SettingsSectionHeader] already
/// supplies the vertical gap.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    this.borderGradientCenter =
        CyberBorderGradientCenter.topLeftBottomRight,
    this.bottomInset = SettingsDimens.inset,
  });

  final List<Widget> children;
  final CyberBorderGradientCenter borderGradientCenter;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(
          const Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: CyberColors.dividerCenter,
          ),
        );
      }
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SettingsDimens.inset,
        0,
        SettingsDimens.inset,
        bottomInset,
      ),
      child: SettingsPanel(
        borderGradientCenter: borderGradientCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        ),
      ),
    );
  }
}

class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.title,
    this.value,
    this.leading,
    this.trailingExtra,
    this.onTap,
    this.showChevron,
  });

  final String title;
  final String? value;
  final Widget? leading;
  final Widget? trailingExtra;
  final VoidCallback? onTap;

  /// When null, chevron shows only if [onTap] is set. Set false for
  /// actionable rows that do not push a sub-page.
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final chevron = showChevron ?? (onTap != null);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SettingsDimens.rowMinHeight),
      child: ListTile(
        contentPadding: SettingsDimens.rowPadding,
        minVerticalPadding: 0,
        leading: leading,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: SettingsDimens.titleSize,
            color: CyberColors.textPrimary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                  style: const TextStyle(
                    color: CyberColors.textSecondary,
                    fontSize: SettingsDimens.titleSize,
                  ),
                ),
              ),
            if (chevron) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: CyberColors.textSecondary,
              ),
            ],
          ],
        ),
        onTap: onTap == null
            ? null
            : () {
                CyberClickSoundRegistry.playClick();
                onTap!();
              },
      ),
    );
  }
}

/// Read-only value row (Device Information) — same chrome as [SettingsNavRow],
/// without a chevron. Optional [trailing] (e.g. QR affordance) and [onTap].
class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({
    super.key,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
    this.clickFeedback = true,
  });

  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// When false, [onTap] has no click sound and no ink splash (hidden gestures).
  final bool clickFeedback;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      contentPadding: SettingsDimens.rowPadding,
      minVerticalPadding: 0,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: SettingsDimens.titleSize,
          color: CyberColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null && value!.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                value!,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: CyberColors.textSecondary,
                  fontSize: SettingsDimens.titleSize,
                ),
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
      onTap: onTap == null
          ? null
          : () {
              if (clickFeedback) {
                CyberClickSoundRegistry.playClick();
              }
              onTap!();
            },
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SettingsDimens.rowMinHeight),
      child: clickFeedback || onTap == null
          ? tile
          : Theme(
              data: Theme.of(context).copyWith(
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                hoverColor: Colors.transparent,
              ),
              child: tile,
            ),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.titleFontSize = SettingsDimens.titleSize,
    this.subtitleFontSize = SettingsDimens.subtitleSize,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double titleFontSize;
  final double subtitleFontSize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SettingsDimens.rowMinHeight),
      child: ListTile(
        contentPadding: SettingsDimens.rowPadding,
        minVerticalPadding: 0,
        title: Text(
          title,
          style: TextStyle(
            fontSize: titleFontSize,
            color: CyberColors.textPrimary,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: TextStyle(
                  color: CyberColors.textSecondary,
                  fontSize: subtitleFontSize,
                  height: 1.35,
                ),
              ),
        trailing: CyberSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Title left + trailing control right (segmented / chips), matching switch rows.
class SettingsControlRow extends StatelessWidget {
  const SettingsControlRow({
    super.key,
    required this.title,
    required this.control,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SettingsDimens.rowMinHeight),
      child: Padding(
        padding: SettingsDimens.rowPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: SettingsDimens.titleSize,
                      color: CyberColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: SettingsDimens.subtitleSize,
                        color: CyberColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: control,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title left + slider right (same left/right rhythm as [SettingsControlRow]).
class SettingsSliderRow extends StatelessWidget {
  const SettingsSliderRow({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SettingsDimens.rowMinHeight),
      child: Padding(
        padding: SettingsDimens.rowPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: SettingsDimens.titleSize,
                      color: CyberColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: SettingsDimens.subtitleSize,
                        color: CyberColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: child),
          ],
        ),
      ),
    );
  }
}

/// Checkbox + label row (Device Information OTA auto-check).
class SettingsCheckboxRow extends StatelessWidget {
  const SettingsCheckboxRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null
          ? null
          : () {
              CyberClickSoundRegistry.playClick();
              onChanged!(!value);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CyberCheckbox(value: value, onChanged: onChanged),
            Text(
              title,
              style: const TextStyle(
                fontSize: SettingsDimens.subtitleSize,
                color: CyberColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Radio / check-style option row (language, unit, screen-off, …).
class SettingsOptionTile extends StatelessWidget {
  const SettingsOptionTile({
    super.key,
    required this.title,
    this.selected = false,
    this.onTap,
    this.clickSoundEnabled = true,
  });

  final String title;
  final bool selected;
  final VoidCallback? onTap;
  final bool clickSoundEnabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(color: CyberColors.textPrimary),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: CyberColors.buttonPrimaryAccent)
          : null,
      onTap: onTap == null
          ? null
          : () {
              if (clickSoundEnabled) {
                CyberClickSoundRegistry.playClick();
              }
              onTap!();
            },
    );
  }
}

/// Settings list — bounce overscroll (same as [AppScrollBehavior]).
class SettingsScrollView extends StatelessWidget {
  const SettingsScrollView({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Allow CyberSlider drag bubbles / expanded thumbs to paint into the
      // top inset without being cropped by the viewport clip.
      clipBehavior: Clip.none,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      // Top inset only — L/R/bottom come from [SettingsGroup] so gap == edge.
      padding: padding ?? const EdgeInsets.only(top: SettingsDimens.inset),
      children: children,
    );
  }
}

/// Push a settings sub-page with a platform-like slide transition.
Future<T?> pushSettingsPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    CupertinoPageRoute<T>(builder: (_) => page),
  );
}

/// Bordered param panel — same uniform outline + depth as [SettingsPanel]
/// (lws-ui Advanced nested `FrostCardView`).
///
/// [borderGradientCenter] is retained for call-site compatibility but ignored.
class SettingsParamCard extends StatelessWidget {
  const SettingsParamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderGradientCenter =
        CyberBorderGradientCenter.topLeftBottomRight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    final theme = CyberGlassTheme.of(context);
    final radius = BorderRadius.circular(theme.cornerRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: SettingsDimens.cardShadow,
      ),
      child: CyberOutlinedPanel(
        outline: CyberPanelOutline(
          style: CyberPanelOutlineStyle.uniform,
          tone: theme.tone,
          width: SettingsDimens.borderWidth,
          cornerRadius: theme.cornerRadius,
          uniformColor: CyberColors.borderUniform,
        ),
        color: Colors.white.withOpacity(0.06),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Title + value readout + [CyberScaledSlider] (Advanced Settings threshold row).
///
/// Tap the value box to edit via [onValueTap] (lws-ui FrostNumericInputDialog).
class SettingsScaledParam extends StatelessWidget {
  const SettingsScaledParam({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.scaleMinText,
    this.scaleMaxText,
    this.valueLabel,
    this.trailing,
    this.enabled = true,
    this.onValueTap,
    this.borderGradientCenter =
        CyberBorderGradientCenter.topLeftBottomRight,
  });

  /// Matches lws-ui `advanced_setting_value_box` (36dp).
  static const headerControlHeight = 36.0;

  final String title;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final String? scaleMinText;
  final String? scaleMaxText;
  final String? valueLabel;
  final Widget? trailing;
  final bool enabled;

  /// When set, the value chip is tappable (opens numeric input dialog).
  final VoidCallback? onValueTap;

  /// Frost corner habit — pair left/right as TLBR / BLTR; full-width as
  /// [CyberBorderGradientCenter.topBottom].
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    final display = valueLabel ?? value.round().toString();
    final valueBox = Container(
      height: headerControlHeight,
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
      ),
      child: Text(
        display,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: SettingsDimens.advancedValueSize,
          color: Colors.white.withOpacity(0.85),
        ),
      ),
    );

    return SettingsParamCard(
      borderGradientCenter: borderGradientCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: SettingsDimens.advancedTitleSize,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onValueTap != null && enabled)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        CyberClickSoundRegistry.playClick();
                        onValueTap!();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: valueBox,
                    ),
                  )
                else
                  valueBox,
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          ),
          CyberScaledSlider(
            value: value,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            min: min,
            max: max,
            enabled: enabled,
            scaleMinText: scaleMinText ?? min.round().toString(),
            scaleMaxText: scaleMaxText ?? max.round().toString(),
            // Match Advanced title size (刻度 = 对应文案字号).
            scaleLabelFontSize: SettingsDimens.advancedTitleSize,
          ),
        ],
      ),
    );
  }
}

/// Two equal-width param cards in a row (lws-ui Advanced Settings grid).
class SettingsParamRow extends StatelessWidget {
  const SettingsParamRow({
    super.key,
    required this.left,
    this.right,
    this.gap = 24,
  });

  final Widget left;
  final Widget? right;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (right == null) {
      return left;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: gap),
        Expanded(child: right!),
      ],
    );
  }
}

class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final l10n = AppLocalizations.of(context)!;
    final background = Theme.of(context).scaffoldBackgroundColor;
    return CyberBlurBackdropScope(
      child: CyberBlurBackdropTarget(
        child: Scaffold(
          backgroundColor: background,
          appBar: ProductPageStatusBar(
            title: title,
            actions: actions,
            backgroundColor: background,
            foregroundColor: Colors.white,
            toolbarHeight: WorkModeStatusBarDimens.height,
            // Product CallBackHomeButton: Home → home icon, Back → arrow_back.
            // Nested settings pop → "Back".
            backLabel: l10n.equipmentStatusBack,
            backAccent: WorkModeAccent.weld,
            onBack: canPop ? () => Navigator.of(context).maybePop() : null,
          ),
          body: body,
        ),
      ),
    );
  }
}
