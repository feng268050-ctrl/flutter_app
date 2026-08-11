import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_settings_ui/cyber_settings_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/chrome/os_settings_page_status_bar.dart';
import 'package:os_settings/chrome/system_wallpaper_backdrop.dart';
import 'package:os_settings/l10n/app_localizations.dart';

export 'package:cyber_settings_ui/cyber_settings_ui.dart'
    show
        SettingsBlurHost,
        SettingsBlurredPageShell,
        SettingsNavRow,
        SettingsPageBackdropBlur,
        SettingsRowFrame,
        SettingsSharedBlurMask,
        SettingsTypography,
        SettingsWallpaperOption,
        SettingsWallpaperPicker;

/// Shared Settings chrome — faithful subset of product HMI
/// `features/settings/presentation/widgets/settings_chrome.dart`.
///
/// Uses CyberUI frost plates (blur + rim + contact shadow), not flat Material
/// cards. Logical plan group names are Dart comments only — never section
/// headers.

/// Layout tokens matching HMI Device Info / General Settings.
abstract final class SettingsDimens {
  static const inset = 24.0;

  /// Vertical space between stacked settings cards (= [inset]).
  static const groupGap = inset;

  /// Shared min height for switch / value / nav / slider / control rows.
  static const rowMinHeight = 70.0;

  /// Horizontal + vertical padding inside a settings row.
  static const rowPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 8);

  /// Gap between a settings card and [SettingsHelpFooter] under it.
  static const helpGap = 8.0;

  /// Row title / nav title — matches HMI ~20.
  static const titleSize = 20.0;

  /// Secondary / value / supporting — matches HMI ~16.
  static const subtitleSize = 16.0;

  static const borderWidth = 1.0;
  static const cardBorder = Color(0x66FFFFFF);
  static const cardHighlightGlow = Color(0x33FFFFFF);
  static const panelRim = Color(0x77FFFFFF);
  static const panelHighlight = Color(0x54FFFFFF);

  static const sectionDividerHeight = 1.0;
  static const sectionDividerColor = CyberColors.dividerCenter;

  static const innerShadowWidth = 0.0;
  static const innerShadowEdge = Color(0x00000000);

  static const depthLipOffset = 0.0;

  static const depthLipShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x8A000000),
      offset: Offset.zero,
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];

  static const outerAmbientExtent = 14.0;
  static const outerAmbientEdge = Color(0x54000000);

  static const cardShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x70000000),
      offset: Offset.zero,
      blurRadius: 8,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x42000000),
      offset: Offset.zero,
      blurRadius: 18,
      spreadRadius: -3,
    ),
  ];
}

/// Local typography (no HmiTypography / AppLocalizations dependency).
abstract final class SettingsTextStyles {
  static const title = TextStyle(
    fontSize: SettingsDimens.titleSize,
    fontWeight: FontWeight.w500,
    color: CyberColors.textPrimary,
    height: 1.25,
  );

  static const value = TextStyle(
    fontSize: SettingsDimens.titleSize,
    fontWeight: FontWeight.w500,
    color: CyberColors.textSecondary,
    height: 1.25,
  );

  static const supporting = TextStyle(
    fontSize: SettingsDimens.subtitleSize,
    fontWeight: FontWeight.w400,
    color: CyberColors.textSecondary,
    height: 1.35,
  );
}

/// Operator help / footnote under a settings card.
class SettingsHelpFooter extends StatelessWidget {
  const SettingsHelpFooter(
    this.text, {
    super.key,
    this.bottomInset = SettingsDimens.inset,
    this.style,
  });

  final String text;
  final double bottomInset;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SettingsDimens.inset,
        SettingsDimens.helpGap,
        SettingsDimens.inset,
        bottomInset,
      ),
      child: Text(
        text,
        style: style ??
            SettingsTextStyles.supporting.copyWith(color: Colors.white54),
      ),
    );
  }
}

/// Settings plate under [SettingsBlurredPageShell].
///
/// Page shell owns the single Gaussian (σ30) between wallpaper and chrome.
/// Plates here are tint + contact shadow + rim only — no second blur.
abstract final class SettingsPerspectiveChrome {
  static const blurSigma = 30.0;
  static const blurIntensity = CyberBlurIntensity.low;
  static const blurTint = CyberBlurTint.dark;

  static const strokeWidth = 1.0;
  static const strokeColor = CyberColors.borderUniform;

  static const cardShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 1),
      blurRadius: 4,
    ),
  ];

  static CyberPanelOutline outlineFor(double cornerRadius) => CyberPanelOutline(
        style: CyberPanelOutlineStyle.uniform,
        tone: CyberTone.dark,
        width: strokeWidth,
        cornerRadius: cornerRadius,
        uniformColor: strokeColor,
      );

  static Widget face({
    required double cornerRadius,
    CyberBorderGradientCenter borderGradientCenter =
        CyberBorderGradientCenter.topBottom,
  }) {
    final radius = BorderRadius.circular(cornerRadius);
    final tint = cyberBlurOverlayColor(
      intensity: blurIntensity,
      tint: blurTint,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: cardShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: tint,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  static Widget rim({required double cornerRadius}) {
    return IgnorePointer(
      child: CustomPaint(
        painter: CyberFrostPanelOutlinePainter(outlineFor(cornerRadius)),
      ),
    );
  }
}

/// Frosted settings plate — CyberUI blur + contact shadow + equal rim.
///
/// Under [SettingsBlurredPageShell]: tint + rim only (page owns Gaussian).
/// Elsewhere: per-panel [CyberBackdropBlur] followLayout / high / σ30.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.child,
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
    this.borderRadius,
    this.elevated = true,
    this.outerAmbientExtent = SettingsDimens.outerAmbientExtent,
    this.outerAmbientEdge = SettingsDimens.outerAmbientEdge,
    this.depthLipOffset = const Offset(0, SettingsDimens.depthLipOffset),
    this.depthLipShadow = SettingsDimens.depthLipShadow,
    this.cardShadow = SettingsDimens.cardShadow,
    this.rimColor = SettingsDimens.panelRim,
    this.blurSampleMode = CyberBlurSampleMode.followLayout,
    this.blurIntensity = CyberBlurIntensity.high,
    this.blurSigma = 30,
  });

  final Widget child;
  final CyberBorderGradientCenter borderGradientCenter;
  final BorderRadius? borderRadius;
  final bool elevated;
  final double outerAmbientExtent;
  final Color outerAmbientEdge;
  final Offset depthLipOffset;
  final List<BoxShadow> depthLipShadow;
  final List<BoxShadow> cardShadow;
  final Color rimColor;
  final CyberBlurSampleMode blurSampleMode;
  final CyberBlurIntensity blurIntensity;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final glass = CyberGlassTheme.of(context);
    final radius = borderRadius ?? BorderRadius.circular(glass.cornerRadius);
    final corner = radius.topLeft.x;
    final pageBlur = SettingsPageBackdropBlur.maybeOf(context);
    final perspective = pageBlur != null;
    final showDepthChrome = elevated && !perspective;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showDepthChrome)
          Positioned.fill(
            child: CustomPaint(
              painter: _SettingsOuterAmbientPainter(
                cornerRadius: corner,
                extent: outerAmbientExtent,
                edge: outerAmbientEdge,
              ),
            ),
          ),
        if (showDepthChrome)
          Positioned.fill(
            child: Transform.translate(
              offset: depthLipOffset,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: radius,
                  boxShadow: depthLipShadow,
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: showDepthChrome ? cardShadow : const [],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: perspective
                    ? SettingsPerspectiveChrome.face(
                        cornerRadius: corner,
                        borderGradientCenter: borderGradientCenter,
                      )
                    : ClipRRect(
                        borderRadius: radius,
                        child: CyberBackdropBlur(
                          sampleMode: blurSampleMode,
                          intensity: blurIntensity,
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                          blurTint: CyberBlurTint.dark,
                          child: const SizedBox.expand(),
                        ),
                      ),
              ),
              if (perspective) ...[
                child,
                Positioned.fill(
                  child: SettingsPerspectiveChrome.rim(cornerRadius: corner),
                ),
              ] else
                CustomPaint(
                  foregroundPainter: _SettingsDepthEdgePainter(
                    baseRim: rimColor,
                    highlightGlow: SettingsDimens.cardHighlightGlow,
                    width: SettingsDimens.borderWidth,
                    cornerRadius: corner,
                  ),
                  child: child,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Path _rrectRing(RRect outer, RRect inner) {
  return Path()
    ..fillType = PathFillType.evenOdd
    ..addRRect(outer)
    ..addRRect(inner);
}

double _shellOpacity(double edgeAlpha, double t) {
  final u = t.clamp(0.0, 1.0);
  final falloff = (1.0 - u) * (1.0 - u);
  return edgeAlpha * falloff;
}

final class _SettingsOuterAmbientPainter extends CustomPainter {
  const _SettingsOuterAmbientPainter({
    required this.cornerRadius,
    required this.extent,
    required this.edge,
  });

  static const _steps = 10;

  final double cornerRadius;
  final double extent;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || extent <= 0) return;

    final cr = cornerRadius
        .clamp(0.0, math.min(size.width, size.height) / 2.0)
        .toDouble();
    final plate = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cr),
    );
    final edgeAlpha = edge.a;
    var prev = plate;
    final paint = Paint()..isAntiAlias = true;

    for (var i = 1; i <= _steps; i++) {
      final t = i / _steps;
      final next = plate.inflate(extent * t);
      final opacity = _shellOpacity(edgeAlpha, t - 0.5 / _steps);
      paint.color = edge.withValues(alpha: opacity);
      canvas.drawPath(_rrectRing(next, prev), paint);
      prev = next;
    }
  }

  @override
  bool shouldRepaint(covariant _SettingsOuterAmbientPainter oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.extent != extent ||
        oldDelegate.edge != edge;
  }
}

final class _SettingsDepthEdgePainter extends CustomPainter {
  const _SettingsDepthEdgePainter({
    required this.baseRim,
    required this.highlightGlow,
    required this.width,
    required this.cornerRadius,
  });

  final Color baseRim;
  final Color highlightGlow;
  final double width;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (width <= 0 || size.isEmpty) return;

    final inset = width * 0.5;
    final rect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final innerRadius = cornerRadius > inset ? cornerRadius - inset : 0.0;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(innerRadius),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 2.5
        ..color = highlightGlow
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5)
        ..isAntiAlias = true,
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = baseRim
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _SettingsDepthEdgePainter oldDelegate) {
    return oldDelegate.baseRim != baseRim ||
        oldDelegate.highlightGlow != highlightGlow ||
        oldDelegate.width != width ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}

/// Untitled settings group ([SettingsPanel] + inset dividers).
///
/// Outer margin: [SettingsDimens.inset] L/R, [SettingsDimens.groupGap] bottom.
/// Pair with [SettingsScrollView] top inset only.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
    this.bottomInset = SettingsDimens.groupGap,
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
            height: SettingsDimens.sectionDividerHeight,
            thickness: SettingsDimens.sectionDividerHeight,
            indent: 20,
            endIndent: 20,
            color: SettingsDimens.sectionDividerColor,
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

/// Read-only value row — same chrome as [SettingsNavRow], without a chevron.
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
  final bool clickFeedback;

  @override
  Widget build(BuildContext context) {
    return SettingsRowFrame(
      onTap: onTap,
      clickSoundEnabled: clickFeedback,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: SettingsTextStyles.title,
            ),
          ),
          if (value != null && value!.isNotEmpty) ...[
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                value!,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: SettingsTextStyles.value,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
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
    return SettingsRowFrame(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: SettingsTextStyles.title),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: SettingsTextStyles.supporting),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          CyberSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Title left + trailing control right.
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
    return SettingsRowFrame(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: SettingsTextStyles.title),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: SettingsTextStyles.supporting),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Align(alignment: Alignment.centerRight, child: control),
          ),
        ],
      ),
    );
  }
}

/// Title left + optional [value] + slider right.
class SettingsSliderRow extends StatelessWidget {
  const SettingsSliderRow({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.value,
  });

  final String title;
  final String? subtitle;
  /// Current value shown immediately before the slider (not in [title]).
  final String? value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SettingsRowFrame(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: SettingsTextStyles.title),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: SettingsTextStyles.supporting),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (value != null) ...[
                  Text(value!, style: SettingsTextStyles.value),
                  const SizedBox(width: 12),
                ],
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Radio / check-style option row.
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
    return SettingsRowFrame(
      onTap: onTap,
      clickSoundEnabled: clickSoundEnabled,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: SettingsTextStyles.title,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 12),
            const Icon(Icons.check, color: CyberColors.buttonPrimaryAccent),
          ],
        ],
      ),
    );
  }
}

/// Settings list — top inset only; L/R/bottom come from [SettingsGroup].
class SettingsScrollView extends StatelessWidget {
  const SettingsScrollView({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      clipBehavior: Clip.none,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: padding ?? const EdgeInsets.only(top: SettingsDimens.inset),
      children: children,
    );
  }
}

/// Dark fill / subtle gradient so frost plates read without home wallpaper.
/// Prefer [SystemWallpaperBackdrop] (HAL path) when a preset is installed.
class SettingsPageBackdrop extends StatelessWidget {
  const SettingsPageBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const SystemWallpaperBackdrop();
  }
}

/// 1px hairline under the Back / title row.
final class SettingsStatusBarFadeDivider extends StatelessWidget {
  const SettingsStatusBarFadeDivider({super.key});

  static const thickness = 1.0;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: thickness,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0x00FFFFFF),
              Color(0xB3FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Section label above a [SettingsGroup] (matches HMI settings chrome).
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(
    this.title, {
    super.key,
    this.topInset = SettingsDimens.inset,
  });

  final String title;
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
        style: const TextStyle(
          color: CyberColors.textSecondary,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w500,
          fontSize: SettingsDimens.subtitleSize,
        ),
      ),
    );
  }
}

// Shared σ bake: SettingsBlurHost / SettingsSharedBlurMask / SettingsPageBackdropBlur
// from cyber_settings_ui. Apps mount the host above Navigator.

/// Nested / root Settings page shell.
///
/// Transparent scaffold over shared σ30 blur mask (blit inside route); status
/// bar is [OsSettingsPageStatusBar]. Body is [ClipRect]'d.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.backEnabled = true,
    this.exitToHmi = false,
    this.onExitToHmi,
    this.wrapBlurShell = false,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool backEnabled;

  /// Root shell: show Exit on the leading rail even when [canPop] is false.
  final bool exitToHmi;

  /// Called when [exitToHmi] is true (defaults to caller wiring).
  final VoidCallback? onExitToHmi;

  /// Legacy: nest a full [SettingsBlurredPageShell] (local host). Prefer false.
  final bool wrapBlurShell;

  static const double _toolbarHeight = 56;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showExit = exitToHmi && onExitToHmi != null;
    final showBack = !showExit && canPop;
    final effectiveBackEnabled = backEnabled && (showExit || canPop);

    final l10n = AppLocalizations.of(context);
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: OsSettingsPageStatusBar(
        title: title,
        toolbarHeight: _toolbarHeight,
        backLabel: showExit
            ? (l10n?.exitLabel ?? 'Exit')
            : (showBack ? (l10n?.backLabel ?? 'Back') : null),
        backAccent: CyberStatusBarAccent.weld,
        onBack: showExit
            ? onExitToHmi
            : (showBack ? () => Navigator.of(context).maybePop() : null),
        backEnabled: effectiveBackEnabled,
        actions: actions,
      ),
      body: ClipRect(child: body),
    );

    if (wrapBlurShell) {
      return SettingsBlurredPageShell(
        blurSigma: SettingsPerspectiveChrome.blurSigma,
        backdropBuilder: () => const SystemWallpaperBackdrop(),
        child: scaffold,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: SettingsSharedBlurMask()),
        scaffold,
      ],
    );
  }
}

/// Alias for call-site migration — prefer [SettingsScaffold].
typedef SettingsPageScaffold = SettingsScaffold;

/// Push a settings sub-page with Cupertino L/R slide.
Future<T?> pushSettingsPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    CupertinoPageRoute<T>(builder: (_) => page),
  );
}

/// Em-dash for missing / unavailable values.
const kUnavailable = '—';

String dashOr(String? value) {
  if (value == null || value.trim().isEmpty) return kUnavailable;
  return value.trim();
}
