import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/home/domain/home_assets.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Shared Settings chrome (lws-ui InsetList / FrostCard → CyberUI).
///
/// Interactive rows call [CyberClickSoundRegistry.playClick].
///
/// Device Information / Common Settings / Camera MUST NOT use
/// [SettingsSectionHeader] — keep group names as Dart comments only.
/// Wi‑Fi list/details MAY use section headers (My Networks / IPv4 / DNS).

/// Screen-edge inset (lws-ui settings `padding="24dp"`).
///
/// Inter-group gap ([groupGap]) matches [inset] so card stacking rhythm equals
/// L/R page margins ([SettingsScrollView] top uses the same value).
abstract final class SettingsDimens {
  static const inset = 24.0;

  /// Vertical space between stacked settings cards (= [inset]).
  static const groupGap = inset;

  /// Shared min height for switch / value / nav / slider / control rows.
  /// Device Info / General (+tabs nested lists).
  static const rowMinHeight = 70.0;

  /// Horizontal + vertical padding inside a settings row.
  static const rowPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 8);

  /// Gap between a settings card and [SettingsHelpFooter] under it.
  /// Preceding [SettingsGroup] must use `bottomInset: 0` so this is the only gap.
  static const helpGap = 8.0;

  /// Device Info / General list title & value → [HmiTypography.settingsRowTitle] (20).
  static const titleSize = 20.0;

  /// Secondary / subtitle / help → [HmiTypography.supporting] (16).
  static const subtitleSize = 16.0;

  /// Shared raised-panel shadow: even contact + ambient on all four sides
  /// (no top-left / bottom-right directional bias).
  static const borderWidth = 1.0;
  static const cardBorder = Color(0x66FFFFFF);
  static const cardHighlightGlow = Color(0x33FFFFFF);
  /// Crisp equal-brightness plate contour (was `0x38` — too soft on frost).
  static const panelRim = Color(0x77FFFFFF);
  static const panelHighlight = Color(0x54FFFFFF);

  /// Section / row hairline — shared by Settings cards and Monitor headers.
  /// Matches container outer stroke: flat 1px, no gradient.
  static const sectionDividerHeight = 1.0;
  static const sectionDividerColor = CyberColors.dividerCenter;

  /// Settings and Monitor share a flat glass face; depth is external only.
  /// Keep the legacy color token for opt-in callers, but no inset vignette.
  static const innerShadowWidth = 0.0;
  static const innerShadowEdge = Color(0x00000000);

  /// Omnidirectional contact shadows (offset zero — matches all edges).
  static const depthLipOffset = 0.0;

  /// Soft shade cast from the depth lip onto the page (under-plate → background).
  static const depthLipShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x8A000000),
      offset: Offset.zero,
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];

  /// Outer shade: plate RRect inflated in steps (edge → transparent), equal
  /// on all sides when [SettingsPanel.lightFromTopLeft] is false.
  static const outerAmbientExtent = 14.0;
  static const outerAmbientEdge = Color(0x54000000);

  /// Compact contact shadow around the front plate (all sides equal).
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

  /// Advanced tab body — ladder sizes matching HmiTypography roles.
  static const advancedTitleSize = 22.0; // sectionTitle
  static const advancedValueSize = 22.0; // sectionTitle
  static const advancedSwitchTitleSize = 24.0; // navigation / primaryTabLabel
  static const advancedSwitchSubtitleSize = 20.0; // control / settingsRowTitle
  static const advancedSectionHeaderSize = 20.0; // control
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
    this.backgroundColor,
  });

  static const tabHeight = 68.0;
  static const dividerThickness = 1.0;
  static const iconSize = 31.0;
  /// Primary tab label size — mirrors [HmiTypography.primaryTabLabel] (24).
  static const labelSize = 24.0;
  static const iconTextGap = 6.0;
  static const indicatorHeight = 2.0;
  static const unselected = Color(0xFF94A3B8);
  static const dividerColor = Color(0x33FFFFFF);

  /// Default tab-strip fill for callers that do not use a page wallpaper.
  static const background = CyberColors.fillSolidTop;

  final List<String> labels;
  final List<
      ({
        Key key,
        IconData icon,
        double iconLeftNudge,
        bool balanceIconLabelGap,
      })> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(tabHeight + dividerThickness);

  @override
  Widget build(BuildContext context) {
    assert(labels.length == tabs.length);
    return ColoredBox(
      color: backgroundColor ?? background,
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
                        iconLeftNudge: tabs[i].iconLeftNudge,
                        balanceIconLabelGap: tabs[i].balanceIconLabelGap,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Center→sides fade hairline (same as nested status-bar divider).
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: SettingsDimens.inset),
            child: SettingsStatusBarFadeDivider(),
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
    this.iconLeftNudge = 0,
    this.balanceIconLabelGap = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  /// Negative shifts icon left from the equal L/T inset.
  final double iconLeftNudge;

  /// When true, icon left inset equals the gap between icon and centered label.
  final bool balanceIconLabelGap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : SettingsTopTabs.unselected;
    final labelStyle = context.hmiTypography.primaryTabLabel.copyWith(
      color: color,
      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      height: 1.0,
    );
    // Left inset matches top/bottom inset to the tab edge (ProductTopTabs).
    final iconInset =
        (SettingsTopTabs.tabHeight - SettingsTopTabs.iconSize) / 2;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          CyberClickSoundRegistry.playClick();
          onTap();
        },
        // Stretch so the indicator spans the full equal-width tab cell;
        // outer cell edges match [SettingsDimens.inset] with the cards.
        child: LayoutBuilder(
          builder: (context, constraints) {
            var iconLeft = iconInset + iconLeftNudge;
            if (balanceIconLabelGap) {
              final painter = TextPainter(
                text: TextSpan(text: label, style: labelStyle),
                maxLines: 1,
                ellipsis: '…',
                textDirection: Directionality.of(context),
              )..layout(maxWidth: constraints.maxWidth);
              final textLeft = (constraints.maxWidth - painter.width) / 2;
              // left == (textLeft - iconRight) ⇒ left == gap to label.
              iconLeft = ((textLeft - SettingsTopTabs.iconSize) / 2)
                  .clamp(0.0, double.infinity);
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ),
                Positioned(
                  left: iconLeft,
                  top: iconInset,
                  width: SettingsTopTabs.iconSize,
                  height: SettingsTopTabs.iconSize,
                  child: Icon(
                    icon,
                    size: SettingsTopTabs.iconSize,
                    color: color,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: SettingsTopTabs.indicatorHeight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    color: selected ? Colors.white : Colors.transparent,
                  ),
                ),
              ],
            );
          },
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
      child: Text(
        text,
        style: context.hmiTypography.supporting.copyWith(
          color: Colors.white54,
        ),
      ),
    );
  }
}

/// Settings / Monitor plate under [SettingsBlurredPageShell].
///
/// Page shell owns the single Gaussian ([ImageFiltered] σ30) between wallpaper
/// and chrome. Plates here are **tint + contact shadow + rim only** — no second
/// [BackdropFilter] / [CyberBackdropBlur] (avoids duplicate blur cost).
///
/// Outer stroke is flat 1px [CyberColors.borderUniform] (no HL / gradient).
/// Depth matches lasercyber-mobile community cards ([AppCardShadowShell]):
/// [BoxDecoration.boxShadow] outside the clipped face, not [Material.elevation].
abstract final class SettingsPerspectiveChrome {
  /// Gaussian between Settings wallpaper and foreground chrome.
  /// Owned by [SettingsBlurredPageShell], not by [face].
  static const blurSigma = 30.0;
  static const blurIntensity = CyberBlurIntensity.low;
  static const blurTint = CyberBlurTint.dark;

  static const strokeWidth = 1.0;
  static const strokeColor = CyberColors.borderUniform;

  /// lasercyber-mobile dark [AppPalette.surfaceCardShadow] — soft contact on
  /// the blurred wallpaper behind the plate.
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

  /// Dark tint + contact shadow only. Rim is [rim] — paint **above** content
  /// so full-bleed rows cannot cover the 1px stroke. Blur comes from the page
  /// [ImageFiltered] layer under the plate.
  static Widget face({
    required double cornerRadius,
    // Retained for call-site compatibility; outline is always uniform.
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

  /// Flat 1px stroke drawn above panel children (IgnorePointer).
  static Widget rim({required double cornerRadius}) {
    return IgnorePointer(
      child: CustomPaint(
        painter: CyberFrostPanelOutlinePainter(outlineFor(cornerRadius)),
      ),
    );
  }
}

/// Settings group shell — frosted or perspective face + depth chrome.
///
/// Under [SettingsBlurredPageShell] / [SettingsPageBackdropBlur]:
/// face uses [SettingsPerspectiveChrome] (dark tint + contact shadow + rim;
/// page [ImageFiltered] owns the only Gaussian) and skips the legacy
/// multi-layer depth ambient / lip painters.
///
/// Elsewhere: face uses [CyberBackdropBlur] [followLayout] / [high] / sigma 30.
///
/// Depth (flat, raised glass): outer shade = inflated RRect shells; inner
/// shade = deflated RRect shells; both fade with distance. Plus transparent
/// lip cast, contact [cardShadow], and an equal bright rim on all sides.
///
/// [borderGradientCenter] is unused under page blur (uniform 1px outline);
/// kept for call-site compatibility. Legacy depth-edge rim ignores it too.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.child,
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
    this.borderRadius,
    this.elevated = true,
    this.innerShadowWidth = SettingsDimens.innerShadowWidth,
    this.innerShadowEdge = SettingsDimens.innerShadowEdge,
    this.outerAmbientExtent = SettingsDimens.outerAmbientExtent,
    this.outerAmbientEdge = SettingsDimens.outerAmbientEdge,
    this.depthLipOffset = const Offset(0, SettingsDimens.depthLipOffset),
    this.depthLipShadow = SettingsDimens.depthLipShadow,
    this.cardShadow = SettingsDimens.cardShadow,
    this.lightFromTopLeft = false,
    this.rimColor = SettingsDimens.panelRim,
    this.lightRim = SettingsDimens.panelHighlight,
    this.innerHighlightWidth = 0,
    this.innerHighlightColor = const Color(0x00FFFFFF),
    this.surfaceGradient,
    this.blurSampleMode = CyberBlurSampleMode.followLayout,
    this.blurIntensity = CyberBlurIntensity.high,
    this.blurSigma = 30,
  });

  final Widget child;
  final CyberBorderGradientCenter borderGradientCenter;

  /// When null, uses [CyberGlassTheme.cornerRadius].
  final BorderRadius? borderRadius;

  /// When false, skip lip cast + contact shadow (compact frost pills / chips).
  final bool elevated;

  /// Per-surface depth tuning. Monitor uses a clean face and a tighter,
  /// lighter outer falloff without changing the Settings page treatment.
  final double innerShadowWidth;
  final Color innerShadowEdge;
  final double outerAmbientExtent;
  final Color outerAmbientEdge;
  final Offset depthLipOffset;
  final List<BoxShadow> depthLipShadow;
  final List<BoxShadow> cardShadow;

  /// When true, ambient/rim are biased top-left lit / bottom-right shaded.
  /// Default false: equal outer ambient + equal rim on all four sides so
  /// bottom-right depth matches top-left.
  final bool lightFromTopLeft;
  final Color rimColor;
  final Color lightRim;
  final double innerHighlightWidth;
  final Color innerHighlightColor;

  /// Optional translucent front-surface layer above the frost / tint fill.
  final Gradient? surfaceGradient;

  /// How the face samples wallpaper frost when page-level blur is absent.
  ///
  /// Default [followLayout] (capture + [ImageFilter.blur]) — required on
  /// Weston/QEMU where [CyberBlurSampleMode.realtime] / [BackdropFilter]
  /// composites black. Prefer [realtime] only where the compositor is known
  /// good (e.g. Android). Ignored under [SettingsPageBackdropBlur].
  final CyberBlurSampleMode blurSampleMode;

  /// Panel-local Gaussian strength (dialog-grade HIGH with Settings/Monitor).
  /// Ignored under [SettingsPageBackdropBlur] ([SettingsPerspectiveChrome]).
  final CyberBlurIntensity blurIntensity;

  /// Gaussian sigma for [CyberBackdropBlur] (page shell uses σ30).
  /// Ignored under [SettingsPageBackdropBlur] (page shell owns sigma).
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final glass = CyberGlassTheme.of(context);
    final radius = borderRadius ?? BorderRadius.circular(glass.cornerRadius);
    final corner = radius.topLeft.x;
    final pageBlur = SettingsPageBackdropBlur.maybeOf(context);
    final perspective = pageBlur != null;
    // Soft black plate shadows show through a translucent white face and read
    // as a charcoal fill — drop them in page-perspective mode.
    final showDepthChrome = elevated && !perspective;

    // No opaque under-plate: a filled lip behind the frost read as solid face
    // fill. Keep its cast shadow on a transparent twin so depth is unchanged.
    // Do not use StackFit.expand — Settings groups live in scroll views with
    // unbounded height; expand → Infinity/NaN transforms and a blank body.
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
                lightFromTopLeft: lightFromTopLeft,
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
          // Face / gradient stay rounded-clipped; [child] may paint outside
          // (e.g. CyberSlider drag value bubble above the first settings row).
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
                          child: DecoratedBox(
                            decoration:
                                BoxDecoration(gradient: surfaceGradient),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
              ),
              if (perspective) ...[
                child,
                // Rim above content — full-bleed rows must not cover the stroke.
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
                    innerShadowWidth: innerShadowWidth,
                    innerShadowEdge: innerShadowEdge,
                    lightFromTopLeft: lightFromTopLeft,
                    lightRim: lightRim,
                    innerHighlightWidth: innerHighlightWidth,
                    innerHighlightColor: innerHighlightColor,
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

/// Annular RRect shells between [inner] (inclusive outer) and [outer].
Path _rrectRing(RRect outer, RRect inner) {
  return Path()
    ..fillType = PathFillType.evenOdd
    ..addRRect(outer)
    ..addRRect(inner);
}

/// Opacity falloff for flat depth shells: strong at the plate edge, clear afar.
double _shellOpacity(double edgeAlpha, double t) {
  // Ease-out so the near-edge band stays readable without a hard cliff.
  final u = t.clamp(0.0, 1.0);
  final falloff = (1.0 - u) * (1.0 - u);
  return edgeAlpha * falloff;
}

/// Outer ambient: inflate the plate RRect in steps; each shell fades out.
///
/// Flat raised look — same rounded-rect silhouette as the plate, larger.
final class _SettingsOuterAmbientPainter extends CustomPainter {
  const _SettingsOuterAmbientPainter({
    required this.cornerRadius,
    required this.extent,
    required this.edge,
    required this.lightFromTopLeft,
  });

  static const _steps = 10;

  final double cornerRadius;
  final double extent;
  final Color edge;
  final bool lightFromTopLeft;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || extent <= 0) {
      return;
    }

    final cr = cornerRadius
        .clamp(0.0, math.min(size.width, size.height) / 2.0)
        .toDouble();
    final plate = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cr),
    );
    final edgeAlpha = edge.opacity;
    final outerBounds = plate.inflate(extent).outerRect;
    var prev = plate;
    final paint = Paint()..isAntiAlias = true;

    for (var i = 1; i <= _steps; i++) {
      final t = i / _steps;
      final next = plate.inflate(extent * t);
      final opacity = _shellOpacity(edgeAlpha, t - 0.5 / _steps);
      if (lightFromTopLeft) {
        // Keep the lit top-left free of an outer halo. A small lower-left
        // contact shade leads naturally into the right/bottom back shadow.
        paint
          ..color = Colors.white
          ..shader = ui.Gradient.linear(
            outerBounds.topLeft,
            outerBounds.bottomRight,
            [
              Colors.transparent,
              edge.withOpacity(opacity * 0.22),
              edge.withOpacity(opacity),
            ],
            const [0.0, 0.55, 1.0],
          );
      } else {
        paint
          ..shader = null
          ..color = edge.withOpacity(opacity);
      }
      canvas.drawPath(_rrectRing(next, prev), paint);
      prev = next;
    }
  }

  @override
  bool shouldRepaint(covariant _SettingsOuterAmbientPainter oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.extent != extent ||
        oldDelegate.edge != edge ||
        oldDelegate.lightFromTopLeft != lightFromTopLeft;
  }
}

/// Uniform 1px rim + soft highlight, plus inner shade from deflated RRects.
final class _SettingsDepthEdgePainter extends CustomPainter {
  const _SettingsDepthEdgePainter({
    required this.baseRim,
    required this.highlightGlow,
    required this.width,
    required this.cornerRadius,
    required this.innerShadowWidth,
    required this.innerShadowEdge,
    required this.lightFromTopLeft,
    required this.lightRim,
    required this.innerHighlightWidth,
    required this.innerHighlightColor,
  });

  static const _innerSteps = 10;

  final Color baseRim;
  final Color highlightGlow;
  final double width;
  final double cornerRadius;
  final double innerShadowWidth;
  final Color innerShadowEdge;
  final bool lightFromTopLeft;
  final Color lightRim;
  final double innerHighlightWidth;
  final Color innerHighlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (width <= 0 || size.isEmpty) {
      return;
    }

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

    _paintInnerShadow(canvas, rrect);

    if (lightFromTopLeft) {
      _paintDirectionalInnerHighlight(canvas, rrect);
      _paintDirectionalContinuousRim(canvas, rrect);
    } else {
      // Soft equal highlight on all four sides (not a neon wire, not top-lit).
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 2.5
          ..color = highlightGlow
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5)
          ..isAntiAlias = true,
      );

      // Crisp equal-brightness contour.
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = baseRim
          ..isAntiAlias = true,
      );
    }
  }

  void _paintDirectionalContinuousRim(Canvas canvas, RRect rrect) {
    // A full 1px low-opacity contour remains continuous around the plate.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = baseRim
        ..isAntiAlias = true,
    );

    // Overlay an RRect-stroke shader, not clipped segments. It begins with
    // soft light at top-left and decays continuously toward bottom-right.
    final bounds = rrect.outerRect;
    final lightStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = ui.Gradient.linear(
        bounds.topLeft,
        bounds.bottomRight,
        [
          lightRim,
          lightRim.withOpacity(lightRim.opacity * 0.32),
          Colors.transparent,
        ],
        const [0.0, 0.52, 1.0],
      )
      ..isAntiAlias = true;
    canvas.drawRRect(rrect, lightStroke);
  }

  void _paintDirectionalInnerHighlight(Canvas canvas, RRect rim) {
    final band = innerHighlightWidth;
    if (band <= 0 || innerHighlightColor.opacity <= 0) {
      return;
    }
    final maxInset = math.min(
      band,
      math.min(rim.width, rim.height) / 2.0 - 0.5,
    );
    if (maxInset <= 0) {
      return;
    }

    // Use the same rounded-rect geometry as the rim. The gradient is clipped
    // by its curved ring, so the soft top-left light remains continuous.
    final bounds = rim.outerRect;
    final paint = Paint()..isAntiAlias = true;
    var previous = rim;
    for (var i = 1; i <= 4; i++) {
      final t = i / 4;
      final next = rim.deflate(maxInset * t);
      final opacity = (1.0 - t) * (1.0 - t);
      paint.shader = ui.Gradient.linear(
        bounds.topLeft,
        bounds.bottomRight,
        [
          innerHighlightColor
              .withOpacity(innerHighlightColor.opacity * opacity),
          innerHighlightColor.withOpacity(
            innerHighlightColor.opacity * opacity * 0.2,
          ),
          Colors.transparent,
        ],
        const [0.0, 0.52, 1.0],
      );
      canvas.drawPath(_rrectRing(previous, next), paint);
      previous = next;
    }
  }

  /// Inner shade: deflate the plate RRect in steps; each shell fades inward.
  void _paintInnerShadow(Canvas canvas, RRect rim) {
    final band = innerShadowWidth;
    if (band <= 0) {
      return;
    }

    final maxInset = math.min(
      band,
      math.min(rim.width, rim.height) / 2.0 - 0.5,
    );
    if (maxInset <= 0) {
      return;
    }

    canvas.save();
    canvas.clipRRect(rim);

    final edgeAlpha = innerShadowEdge.opacity;
    var prev = rim;
    final paint = Paint()..isAntiAlias = true;

    for (var i = 1; i <= _innerSteps; i++) {
      final t = i / _innerSteps;
      final next = rim.deflate(maxInset * t);
      if (next.outerRect.isEmpty) {
        break;
      }
      paint.color = innerShadowEdge.withOpacity(
        _shellOpacity(edgeAlpha, t - 0.5 / _innerSteps),
      );
      canvas.drawPath(_rrectRing(prev, next), paint);
      prev = next;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SettingsDepthEdgePainter oldDelegate) {
    return oldDelegate.baseRim != baseRim ||
        oldDelegate.highlightGlow != highlightGlow ||
        oldDelegate.width != width ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.innerShadowWidth != innerShadowWidth ||
        oldDelegate.innerShadowEdge != innerShadowEdge ||
        oldDelegate.lightFromTopLeft != lightFromTopLeft ||
        oldDelegate.lightRim != lightRim ||
        oldDelegate.innerHighlightWidth != innerHighlightWidth ||
        oldDelegate.innerHighlightColor != innerHighlightColor;
  }
}

/// Untitled settings group ([SettingsPanel] + inset dividers).
///
/// Outer margin: [SettingsDimens.inset] L/R, [SettingsDimens.groupGap] bottom
/// (same as edge inset). Pair with [SettingsScrollView] top inset.
///
/// [borderGradientCenter] is unused (uniform outline); kept for call sites.
/// Set [bottomInset] to `0` when a following [SettingsSectionHeader] / help
/// footer already supplies the vertical gap.
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
          style: context.hmiTypography.settingsRowTitle.copyWith(
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
                  style: context.hmiTypography.settingsRowValue.copyWith(
                    color: CyberColors.textSecondary,
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
        style: context.hmiTypography.settingsRowTitle.copyWith(
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
                style: context.hmiTypography.settingsRowValue.copyWith(
                  color: CyberColors.textSecondary,
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
    final typography = context.hmiTypography;
    final titleStyle = typography.settingsRowTitle.copyWith(
      fontSize: titleFontSize,
      color: CyberColors.textPrimary,
    );
    final subtitleStyle = typography.supporting.copyWith(
      fontSize: subtitleFontSize,
      color: CyberColors.textSecondary,
      height: 1.35,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SettingsDimens.rowMinHeight),
      child: ListTile(
        contentPadding: SettingsDimens.rowPadding,
        minVerticalPadding: 0,
        title: Text(
          title,
          style: titleStyle,
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: subtitleStyle,
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
                    style: context.hmiTypography.settingsRowTitle.copyWith(
                      color: CyberColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: context.hmiTypography.supporting.copyWith(
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
                    style: context.hmiTypography.settingsRowTitle.copyWith(
                      color: CyberColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: context.hmiTypography.supporting.copyWith(
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
            CyberCheckbox(
              value: value,
              size: CyberDimens.checkboxLargeSize,
              onChanged: onChanged,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: context.hmiTypography.sectionTitle.copyWith(
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
        style: context.hmiTypography.settingsRowTitle.copyWith(
          color: CyberColors.textPrimary,
        ),
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

/// Push a settings sub-page with industry L/R slide transitions.
///
/// Nested pages use a cheap backdrop via [SettingsScaffold] so exit does not
/// stack two live page Gaussians during the animation.
Future<T?> pushSettingsPage<T>(BuildContext context, Widget page) {
  return pushAppSlidePage<T>(context, page);
}

/// Bordered param panel — same equal-edge shadow chrome as [SettingsPanel]
/// (lws-ui Advanced nested `FrostCardView`).
///
/// [borderGradientCenter] is retained for call-site compatibility but ignored.
class SettingsParamCard extends StatelessWidget {
  const SettingsParamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    return SettingsPanel(
      borderGradientCenter: borderGradientCenter,
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
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
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
                    style: context.hmiTypography.sectionTitle,
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

/// Home wallpaper used as Settings capture root / page backdrop.
class SettingsHomeBackdrop extends StatelessWidget {
  const SettingsHomeBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = MediaQuery.sizeOf(context);
    final (cacheW, cacheH) = HomeAssets.backdropCachePx(
      logicalSize: size,
      devicePixelRatio: dpr,
    );
    return Image.asset(
      HomeAssets.backdrop,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1A1A)),
    );
  }
}

/// Declares Settings / Monitor page chrome — descendant [SettingsPanel]s use
/// [SettingsPerspectiveChrome] (tint + rim; page owns Gaussian) instead of
/// dialog frost.
class SettingsPageBackdropBlur extends InheritedWidget {
  const SettingsPageBackdropBlur({
    super.key,
    required this.sigma,
    required super.child,
  });

  /// Page [ImageFiltered] sigma ([SettingsPerspectiveChrome.blurSigma] = 30).
  final double sigma;

  static SettingsPageBackdropBlur? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SettingsPageBackdropBlur>();
  }

  @override
  bool updateShouldNotify(SettingsPageBackdropBlur oldWidget) =>
      oldWidget.sigma != sigma;
}

/// Settings / Monitor / Engineer page stack: sharp wallpaper (capture) → page
/// blur plate → [child] chrome.
///
/// Capture for tip/IME frost stays on the sharp [CyberBlurBackdropTarget].
/// Panels use [SettingsPerspectiveChrome] tint/rim/shadow only — no second
/// BackdropFilter.
///
/// **Default blur plate (scheme A / home firstFrame):** bake σ30 once from the
/// sharp plate (downscaled), then blit [RawImage] every frame. Wallpaper is
/// static, so live [ImageFiltered] is unnecessary on product pages and costly
/// on RK3566/QEMU — especially under Cupertino L/R slides.
///
/// Set [livePageBlur] true only for rare cases that need per-frame Gaussian
/// (e.g. animated wallpaper experiments).
class SettingsBlurredPageShell extends StatelessWidget {
  const SettingsBlurredPageShell({
    super.key,
    required this.child,
    this.blurSigma = SettingsPerspectiveChrome.blurSigma,
    this.backdropBuilder,
    this.livePageBlur = false,
  });

  final Widget child;

  /// Page wallpaper Gaussian sigma (foreground ↔ background).
  final double blurSigma;

  /// Wallpaper under capture + blur layer. Called for sharp capture target and
  /// for the live [ImageFiltered] child when [livePageBlur] is true. Defaults
  /// to [SettingsHomeBackdrop]. Monitor passes a dimmed stack.
  final Widget Function()? backdropBuilder;

  /// When false (default), bake a static σ plate once. When true, live
  /// [ImageFiltered] every frame.
  final bool livePageBlur;

  /// Capture downscale divisor — matches home [CyberBackdropBlur] / lws-ui.
  static const captureScaleFactor = 3.0;

  @override
  Widget build(BuildContext context) {
    final buildPlate = backdropBuilder ?? () => const SettingsHomeBackdrop();
    return CyberBlurBackdropScope(
      child: SettingsPageBackdropBlur(
        sigma: blurSigma,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CyberBlurBackdropTarget(
                child: buildPlate(),
              ),
            ),
            Positioned.fill(
              child: _SettingsPageBlurPlate(
                livePageBlur: livePageBlur,
                blurSigma: blurSigma,
                buildPlate: buildPlate,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Live [ImageFiltered] or firstFrame-baked [RawImage] under Settings chrome.
class _SettingsPageBlurPlate extends StatefulWidget {
  const _SettingsPageBlurPlate({
    required this.livePageBlur,
    required this.blurSigma,
    required this.buildPlate,
  });

  final bool livePageBlur;
  final double blurSigma;
  final Widget Function() buildPlate;

  @override
  State<_SettingsPageBlurPlate> createState() => _SettingsPageBlurPlateState();
}

class _SettingsPageBlurPlateState extends State<_SettingsPageBlurPlate> {
  ui.Image? _baked;
  bool _bakePending = false;
  int _bakeGen = 0;
  int _bakeRetries = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.livePageBlur) {
      _scheduleBake();
    }
  }

  @override
  void didUpdateWidget(covariant _SettingsPageBlurPlate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.livePageBlur && !oldWidget.livePageBlur) {
      // Root became current again — drop static plate; live path owns blur.
      _bakeGen++;
      _baked = null;
      _bakePending = false;
      _bakeRetries = 0;
      return;
    }
    if (!widget.livePageBlur &&
        (oldWidget.livePageBlur ||
            oldWidget.blurSigma != widget.blurSigma)) {
      _baked = null;
      _bakeRetries = 0;
      _scheduleBake();
    }
  }

  @override
  void dispose() {
    _bakeGen++;
    // [_baked] is a handle into [CyberBlurBackdropScope] shared capture —
    // do not dispose here.
    _baked = null;
    super.dispose();
  }

  void _scheduleBake({int settlePasses = 2}) {
    if (_bakePending || !mounted || _baked != null) {
      return;
    }
    final gen = ++_bakeGen;
    _bakePending = true;
    void pass(int remaining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || gen != _bakeGen) {
          if (gen == _bakeGen) {
            _bakePending = false;
          }
          return;
        }
        if (remaining > 1) {
          pass(remaining - 1);
          return;
        }
        unawaited(_bake(gen));
      });
    }

    pass(settlePasses.clamp(1, 4));
  }

  Future<void> _bake(int gen) async {
    try {
      if (!mounted || gen != _bakeGen || widget.livePageBlur) {
        return;
      }
      final scope = CyberBlurBackdropScope.maybeOf(context);
      final boundary = scope?.renderBoundary;
      if (scope == null || boundary == null || !boundary.hasSize) {
        if (gen == _bakeGen && _bakeRetries < 12) {
          _bakeRetries++;
          _bakePending = false;
          _scheduleBake(settlePasses: 1);
        }
        return;
      }
      // Do NOT read [RenderObject.debugNeedsPaint] here: in profile/release
      // that getter throws LateInitializationError (assert-stripped late local).
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final scale = (dpr / SettingsBlurredPageShell.captureScaleFactor)
          .clamp(0.25, dpr);
      // Sigma in capture-pixel space (same as CyberBackdropBlur firstFrame).
      final sigma = widget.blurSigma * scale;
      ui.Image? image;
      try {
        image = await scope.acquireBlurredCapture(
          pixelRatio: scale,
          sigmaX: sigma,
          sigmaY: sigma,
        );
      } catch (e) {
        debugPrint('settings-blur-plate: bake capture failed: $e');
        if (gen == _bakeGen && _bakeRetries < 12) {
          _bakeRetries++;
          _bakePending = false;
          _scheduleBake(settlePasses: 1);
        }
        return;
      }
      if (!mounted || gen != _bakeGen || widget.livePageBlur) {
        return;
      }
      if (image == null || image.width < 1 || image.height < 1) {
        if (gen == _bakeGen && _bakeRetries < 12) {
          _bakeRetries++;
          _bakePending = false;
          _scheduleBake(settlePasses: 1);
        }
        return;
      }
      debugPrint(
        'settings-blur-plate: baked ${image.width}x${image.height} '
        'sigma=${sigma.toStringAsFixed(1)} scale=${scale.toStringAsFixed(2)}',
      );
      setState(() {
        _baked = image;
        _bakeRetries = 0;
      });
    } catch (e) {
      debugPrint('settings-blur-plate: bake aborted: $e');
    } finally {
      if (gen == _bakeGen) {
        _bakePending = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.livePageBlur) {
      return IgnorePointer(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
            tileMode: ui.TileMode.clamp,
          ),
          child: widget.buildPlate(),
        ),
      );
    }

    final baked = _baked;
    if (baked != null) {
      return IgnorePointer(
        child: RawImage(
          image: baked,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.medium,
        ),
      );
    }

    // Placeholder until bake completes — opaque enough that gutters do not
    // flash sharp wallpaper under a sliding nested page.
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.buildPlate(),
          const ColoredBox(color: Color(0xE6101012)),
        ],
      ),
    );
  }
}

/// 1px hairline under Settings status / tab strips: bright at center, fades
/// to transparent at L/R (matches Videos column header treatment).
final class SettingsStatusBarFadeDivider extends StatelessWidget {
  const SettingsStatusBarFadeDivider({super.key});

  static const thickness = SettingsTopTabs.dividerThickness;

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

/// Hairline under nested Settings [ProductPageStatusBar] (no top tabs).
///
/// Matches [SettingsTopTabs] fade divider. Sits at the bottom of the Back /
/// title row ([WorkModeStatusBarDimens.height]); Scaffold body is [ClipRect]’d
/// so list content cannot paint above it while scrolling.
final class SettingsStatusBarHairline extends StatelessWidget
    implements PreferredSizeWidget {
  const SettingsStatusBarHairline({super.key});

  @override
  Size get preferredSize =>
      const Size.fromHeight(SettingsStatusBarFadeDivider.thickness);

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: SettingsDimens.inset),
      child: SettingsStatusBarFadeDivider(),
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
    // Nested Settings: static σ30 plate (shell default). Never live ImageFiltered
    // under Cupertino L/R — parent root also uses a baked plate.
    return SettingsBlurredPageShell(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ProductPageStatusBar(
          title: title,
          actions: actions,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          // Back / title row height; hairline rides under this band.
          toolbarHeight: WorkModeStatusBarDimens.height,
          bottom: const SettingsStatusBarHairline(),
          // Product CallBackHomeButton: Home → home icon, Back → arrow_back.
          // Nested settings pop → "Back".
          backLabel: l10n.equipmentStatusBack,
          backAccent: WorkModeAccent.weld,
          onBack: canPop ? () => Navigator.of(context).maybePop() : null,
        ),
        // Clip at status-bar hairline so scroll cannot enter the Back row.
        body: ClipRect(child: body),
      ),
    );
  }
}
