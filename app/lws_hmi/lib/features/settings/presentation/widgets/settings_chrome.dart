import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';

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
  static const rowMinHeight = 64.0;

  /// Horizontal + vertical padding inside a settings row.
  static const rowPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 8);

  /// Gap between a settings card and [SettingsHelpFooter] under it.
  /// Preceding [SettingsGroup] must use `bottomInset: 0` so this is the only gap.
  static const helpGap = 8.0;
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SettingsDimens.inset,
        SettingsDimens.inset,
        SettingsDimens.inset,
        8,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: CyberColors.textSecondary,
              letterSpacing: 0.6,
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
    fontSize: 14,
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
    return CyberOutlinedPanel(
      clipBehavior: Clip.none,
      outline: CyberPanelOutline(
        style: CyberPanelOutlineStyle.frostGradient,
        tone: theme.tone,
        width: theme.borderWidth,
        cornerRadius: theme.cornerRadius,
        gradientCenter: borderGradientCenter,
      ),
      color: Colors.white.withOpacity(0.06),
      child: child,
    );
  }
}

/// Untitled settings group ([SettingsPanel] + inset dividers).
///
/// Outer margin: [SettingsDimens.inset] on left/right/bottom so group gap
/// equals distance to screen edges. Pair with [SettingsScrollView] top inset.
///
/// Pass [borderGradientCenter] so adjacent cards follow lws-ui Frost habit
/// (not one shared diagonal). Set [bottomInset] to `0` when a following
/// [SettingsSectionHeader] already supplies the vertical gap.
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
            fontSize: 18,
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
                    fontSize: 18,
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
          fontSize: 18,
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
                  fontSize: 18,
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
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SettingsDimens.rowMinHeight),
      child: ListTile(
        contentPadding: SettingsDimens.rowPadding,
        minVerticalPadding: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            color: CyberColors.textPrimary,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(
                  color: CyberColors.textSecondary,
                  fontSize: 14,
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
                      fontSize: 18,
                      color: CyberColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 14,
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
                      fontSize: 18,
                      color: CyberColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 14,
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
                fontSize: 16,
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

/// Bordered param panel — same frost outline chrome as [SettingsPanel]
/// (lws-ui Advanced nested `FrostCardView`).
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
    return CyberOutlinedPanel(
      outline: CyberPanelOutline(
        style: CyberPanelOutlineStyle.frostGradient,
        tone: theme.tone,
        width: theme.borderWidth,
        cornerRadius: theme.cornerRadius,
        gradientCenter: borderGradientCenter,
      ),
      color: Colors.white.withOpacity(0.06),
      child: Padding(padding: padding, child: child),
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

  /// Matches lws-ui `advanced_setting_value_box` (36dp); Auto trailing
  /// stretches to the same height.
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
          fontSize: 16,
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
                    style: const TextStyle(fontSize: 16),
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
    return Scaffold(
      appBar: ProductPageStatusBar(
        title: title,
        actions: actions,
        onBack: canPop
            ? () => Navigator.of(context).maybePop()
            : null,
      ),
      body: body,
    );
  }
}
