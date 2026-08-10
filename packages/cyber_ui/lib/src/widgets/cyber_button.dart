import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';
import 'package:cyber_ui/src/theme/cyber_panel_outline.dart';
import 'package:cyber_ui/src/theme/cyber_tone.dart';
import 'package:cyber_ui/src/widgets/cyber_press_feedback.dart';
import 'package:cyber_ui/src/widgets/cyber_press_ink_splash.dart';

/// Frost `FrostButton` variants (`DEFAULT` → [standard]).
enum CyberButtonVariant { standard, primary, secondary, light }

enum CyberButtonSize {
  /// Compact trailing actions (height 38).
  mini,

  /// Default dialog / settings / monitor CTA (height 56).
  small,

  /// Process-mode outline / wire actions (height 66).
  medium,

  /// Primary hold / enable actions (height 86).
  large,

  /// Alias for [small] — prefer [small] in new code.
  @Deprecated('Use CyberButtonSize.small')
  regular,
}

/// Frost `FrostButtonShape` — [rounded] is pill (half-height); [rectangle]
/// uses [CyberDimens.rectangleButtonCornerRadius].
enum CyberButtonShape { rounded, rectangle }

/// Press tokens from lws-ui `FrostButtonPressDefaults`.
abstract final class CyberButtonPressDefaults {
  /// Resting alpha for [CyberButtonVariant.standard] / [secondary] (225/255).
  static const restingAlpha = 225 / 255;

  static const pressedAlpha = 1.0;
  static const disabledOpacity = 0.45;

  /// White ripple for DEFAULT / PRIMARY (`0x3D`).
  static const defaultRipple = Color(0x3DFFFFFF);

  /// White ripple for SECONDARY (`0x2A`).
  static const secondaryRipple = Color(0x2AFFFFFF);

  /// Black ripple for LIGHT IME keycaps (`0x33`).
  static const lightRipple = Color(0x33000000);

  static const pressIn = Duration(milliseconds: 70);
  static const pressOut = Duration(milliseconds: 140);

  /// Bounded ripple expand (Android [RippleDrawable] / Material ink).
  static const rippleExpand = Duration(milliseconds: 225);
  static const rippleFade = Duration(milliseconds: 200);

  static Color rippleColor(CyberButtonVariant variant) => switch (variant) {
        CyberButtonVariant.light => lightRipple,
        CyberButtonVariant.secondary => secondaryRipple,
        CyberButtonVariant.standard ||
        CyberButtonVariant.primary =>
          defaultRipple,
      };

  static double restingFaceAlpha(CyberButtonVariant variant) =>
      switch (variant) {
        CyberButtonVariant.primary || CyberButtonVariant.light => pressedAlpha,
        CyberButtonVariant.standard ||
        CyberButtonVariant.secondary =>
          restingAlpha,
      };

  /// Face alpha while pressed (performance / with ripple). PRIMARY/LIGHT stay
  /// opaque — ripple is the cue. Balanced uses a press dim overlay instead
  /// (see [CyberButton] build), not this alpha.
  static double pressedFaceAlpha(
    CyberButtonVariant variant, {
    required bool suppressRipple,
  }) {
    if (suppressRipple) {
      // Overlay path — keep face paint at resting alpha.
      return restingFaceAlpha(variant);
    }
    return pressedAlpha;
  }

  /// Black scrim at full press when ripple is suppressed (Balanced).
  /// Alias of [CyberPressFeedback.overlay] (Home Monitor/Settings QA).
  static const Color suppressRipplePressOverlay = CyberPressFeedback.overlay;
}

/// Frost-styled button (Material [InkRipple] + shape; lws-ui `FrostButton`).
///
/// Press feedback matches `FrostButtonPressFeedback`:
/// - Bounded ripple clipped to the button radius.
/// - LIGHT → black ripple; PRIMARY/DEFAULT → white `0x3D`; SECONDARY → `0x2A`.
/// - DEFAULT/SECONDARY face alpha 225→255 (70ms in / 140ms out); LIGHT/PRIMARY
///   stay at full opacity while ripple is the visible cue (same as IME).
/// - When [MediaQuery.disableAnimations] is true or theme [NoSplash] (Balanced),
///   ink / custom ripple is suppressed and a dark press scrim replaces it so
///   press feedback stays obvious on PRIMARY (which never changed face alpha).
///
/// IME alternate long-press keys set [inkWellGestures] false and drive
/// [externalPress] (global hotspot while down, `null` when up) so ripple still
/// runs while the parent owns the pointer (lws-ui `PressInteraction` emit).
class CyberButton extends StatefulWidget {
  const CyberButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = CyberButtonVariant.standard,
    this.size = CyberButtonSize.small,
    this.shape = CyberButtonShape.rectangle,
    this.clickSoundEnabled = true,
    this.expand = false,
    this.stretch = false,
    this.height,
    this.foregroundColor,
    this.onLongPress,
    this.borderGradientCenter = CyberBorderGradientCenter.uniform,
    this.borderGradientColors,
    this.borderColor,
    this.strokeWidth,
    this.inkWellGestures = true,
    this.externalPress,
    this.paintFill = true,
  });

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  final CyberButtonVariant variant;
  final CyberButtonSize size;
  final CyberButtonShape shape;
  final bool clickSoundEnabled;

  /// When false, skip solid/gradient face fill so an under-plate frost shows
  /// through (e.g. Monitor action pills on [CyberBackdropBlur]).
  final bool paintFill;

  /// When true, fill parent constraints (IME keycaps). Unbounded parents
  /// (e.g. [ListView] children) MUST NOT set this — use [stretch] instead.
  final bool expand;

  /// When true, take max cross-axis width with fixed button height.
  final bool stretch;

  /// Overrides [size] height when set (escape hatch for non-tier heights).
  final double? height;

  /// Optional label/icon color override (e.g. IME accent backspace).
  final Color? foregroundColor;

  /// Stroke direction (legacy). Buttons always paint a flat home QA rim;
  /// gradient centers are ignored unless a caller needs API compatibility.
  final CyberBorderGradientCenter borderGradientCenter;

  /// Legacy frost HL/mid/shadow override — ignored; rim is [buttonRim].
  final List<Color>? borderGradientColors;

  /// Flat stroke color override. Defaults to [CyberColors.buttonRim] (70%
  /// white) or [CyberColors.buttonPrimaryRim] (60%) for [primary]. Home
  /// Monitor / Settings / AI Vision keep [CyberColors.homeQuickActionRim]
  /// (30%) on their tiles only.
  final Color? borderColor;

  /// Stroke width override; defaults to [CyberDimens.buttonStrokeWidth] (1px).
  final double? strokeWidth;

  /// When false, [InkWell] does not own taps — parent drives [externalPress]
  /// (IME letter keys with alternate long-press).
  final bool inkWellGestures;

  /// Global press hotspot while down; `null` when released. Only used when
  /// [inkWellGestures] is false.
  final ValueNotifier<Offset?>? externalPress;

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton>
    with TickerProviderStateMixin {
  final GlobalKey _hostKey = GlobalKey();
  late final AnimationController _rippleExpand;
  late final AnimationController _rippleFade;
  /// 0 = resting face alpha, 1 = pressed. Uses a ticker so Balanced
  /// (`MediaQuery.disableAnimations`) can kill ink ripple without also
  /// zeroing [AnimatedOpacity] press feedback.
  late final AnimationController _facePress;
  Offset _rippleOrigin = Offset.zero;
  bool _inkHighlighted = false;
  /// Pointer-driven press (more reliable than InkWell highlight alone).
  bool _pointerDown = false;

  bool get _enabled => widget.onPressed != null;

  bool get _externalDown =>
      widget.externalPress != null && widget.externalPress!.value != null;

  bool get _pressed => _inkHighlighted || _externalDown || _pointerDown;

  /// Ripple-only gate (Balanced). Prefer MediaQuery; Theme press-ink is backup
  /// when density MediaQuery re-wrapping drops disableAnimations.
  bool get _suppressRipple {
    if (MediaQuery.disableAnimationsOf(context)) {
      return true;
    }
    final splash = Theme.of(context).splashFactory;
    return identical(splash, CyberPressInkSplash.splashFactory) ||
        identical(splash, NoSplash.splashFactory);
  }

  @override
  void initState() {
    super.initState();
    _rippleExpand = AnimationController(
      vsync: this,
      duration: CyberButtonPressDefaults.rippleExpand,
    );
    _rippleFade = AnimationController(
      vsync: this,
      duration: CyberButtonPressDefaults.rippleFade,
      value: 1,
    );
    _facePress = AnimationController(
      vsync: this,
      duration: CyberButtonPressDefaults.pressIn,
    );
    widget.externalPress?.addListener(_onExternalPress);
  }

  @override
  void didUpdateWidget(covariant CyberButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.externalPress != widget.externalPress) {
      oldWidget.externalPress?.removeListener(_onExternalPress);
      widget.externalPress?.addListener(_onExternalPress);
    }
  }

  @override
  void dispose() {
    widget.externalPress?.removeListener(_onExternalPress);
    _rippleExpand.dispose();
    _rippleFade.dispose();
    _facePress.dispose();
    super.dispose();
  }

  void _syncFacePress() {
    if (_pressed) {
      _facePress.duration = CyberButtonPressDefaults.pressIn;
      _facePress.forward();
    } else {
      _facePress.duration = CyberButtonPressDefaults.pressOut;
      _facePress.reverse();
    }
  }

  void _onExternalPress() {
    if (!mounted || widget.inkWellGestures || !_enabled) {
      return;
    }
    final hotspot = widget.externalPress?.value;
    if (!_suppressRipple) {
      if (hotspot != null) {
        _rippleOrigin = _hotspotInHost(hotspot);
        _rippleFade.value = 1;
        _rippleExpand.forward(from: 0);
      } else {
        if (_rippleExpand.status != AnimationStatus.completed) {
          _rippleExpand.value = 1;
        }
        _rippleFade.reverse(from: _rippleFade.value);
      }
    }
    setState(() {});
    _syncFacePress();
  }

  Offset _hotspotInHost(Offset globalPosition) {
    final box = _hostKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return Offset.zero;
    }
    final local = box.globalToLocal(globalPosition);
    return Offset(
      local.dx.clamp(0.0, box.size.width),
      local.dy.clamp(0.0, box.size.height),
    );
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    if (widget.clickSoundEnabled) {
      CyberClickSoundRegistry.playClick();
    }
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final tier = _resolvedSize(widget.size);
    final resolvedHeight = widget.height ?? _heightFor(tier);
    final hPad = (widget.expand || widget.stretch) ? 0.0 : _padHFor(tier);
    final cornerRadius = widget.shape == CyberButtonShape.rounded
        ? resolvedHeight / 2
        : CyberDimens.rectangleButtonCornerRadius;
    final radius = BorderRadius.circular(cornerRadius);
    final textColor = widget.foregroundColor ?? _foreground(widget.variant);
    final fontSize = _fontSizeFor(tier);

    // Flat 1px rim: primary = 60% white highlight; others = 70% white.
    // Home QA tiles keep 30% via [homeQuickActionRim] on their own chrome.
    final defaultRim = widget.variant == CyberButtonVariant.primary
        ? CyberColors.buttonPrimaryRim
        : CyberColors.buttonRim;
    final outline = CyberPanelOutline(
      style: CyberPanelOutlineStyle.uniform,
      tone: widget.variant == CyberButtonVariant.light
          ? CyberTone.light
          : CyberTone.dark,
      width: widget.strokeWidth ?? CyberDimens.buttonStrokeWidth,
      cornerRadius: cornerRadius,
      uniformColor: widget.borderColor ?? defaultRim,
    );

    final label = DefaultTextStyle(
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.0,
      ),
      child: IconTheme(
        data: IconThemeData(color: textColor, size: widget.expand ? 22 : 20),
        child: widget.child,
      ),
    );

    final fillDecoration = BoxDecoration(
      borderRadius: radius,
      color: widget.paintFill ? _solidFill(widget.variant) : null,
      gradient: widget.paintFill ? _fillGradient(widget.variant) : null,
    );

    final Widget face;
    if (widget.expand || widget.stretch) {
      face = Stack(
        fit: StackFit.passthrough,
        children: [
          Ink(
            height: resolvedHeight,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            decoration: fillDecoration,
            child: Center(child: label),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: CyberFrostPanelOutlinePainter(outline),
              ),
            ),
          ),
        ],
      );
    } else {
      // Shrink-wrap face. [Text] expands to max width for wrapping — wrap in
      // a min-[Row] so the label keeps intrinsic width under loose constraints.
      final vPad = ((resolvedHeight - fontSize) / 2).clamp(0.0, resolvedHeight);
      face = CustomPaint(
        foregroundPainter: CyberFrostPanelOutlinePainter(outline),
        child: DecoratedBox(
          decoration: fillDecoration,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [label],
            ),
          ),
        ),
      );
    }

    final resting = CyberButtonPressDefaults.restingFaceAlpha(widget.variant);
    final reduceMotion = _suppressRipple;
    final pressedTarget = CyberButtonPressDefaults.pressedFaceAlpha(
      widget.variant,
      suppressRipple: reduceMotion,
    );

    // Performance: DEFAULT/SECONDARY brighten via Opacity. Balanced: keep face
    // paint steady and use a dark scrim (PRIMARY never had an opacity cue).
    final Widget body;
    if (reduceMotion) {
      body = face;
    } else {
      body = AnimatedBuilder(
        animation: _facePress,
        builder: (context, child) {
          final faceAlpha = !enabled
              ? CyberButtonPressDefaults.disabledOpacity
              : resting + (pressedTarget - resting) * _facePress.value;
          return Opacity(opacity: faceAlpha, child: child);
        },
        child: face,
      );
    }

    Widget childBox = !enabled && reduceMotion
        ? Opacity(
            opacity: CyberButtonPressDefaults.disabledOpacity,
            child: body,
          )
        : body;
    if (widget.expand) {
      childBox = SizedBox.expand(child: childBox);
    } else if (widget.stretch) {
      childBox = SizedBox(
        width: double.infinity,
        height: resolvedHeight,
        child: childBox,
      );
    }

    final ripple = CyberButtonPressDefaults.rippleColor(widget.variant);
    final useInkWell = widget.inkWellGestures && enabled;
    final showExternalRipple = !widget.inkWellGestures && !reduceMotion;

    Widget surfaced = childBox;
    if (reduceMotion && !useInkWell) {
      // IME external-press path has no InkWell — paint Home-QA gray overlay.
      surfaced = Stack(
        fit: StackFit.passthrough,
        children: [
          childBox,
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: AnimatedBuilder(
                  animation: _facePress,
                  builder: (context, _) => ColoredBox(
                    color: CyberPressFeedback.overlayAt(_facePress.value),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (showExternalRipple) {
      surfaced = Stack(
        fit: StackFit.passthrough,
        children: [
          childBox,
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_rippleExpand, _rippleFade]),
                  builder: (context, _) => CustomPaint(
                    painter: _BoundedPressRipplePainter(
                      origin: _rippleOrigin,
                      progress: _rippleExpand.value,
                      opacity: _rippleFade.value,
                      color: ripple,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    void setPointerDown(bool down) {
      if (!_enabled || _pointerDown == down) {
        return;
      }
      setState(() => _pointerDown = down);
      _syncFacePress();
    }

    Widget button = Material(
      key: _hostKey,
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: useInkWell
          ? Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => setPointerDown(true),
              onPointerUp: (_) => setPointerDown(false),
              onPointerCancel: (_) => setPointerDown(false),
              child: InkWell(
                onTap: _handleTap,
                onLongPress: widget.onLongPress,
                onHighlightChanged: (v) {
                  if (_inkHighlighted == v) {
                    return;
                  }
                  setState(() => _inkHighlighted = v);
                  _syncFacePress();
                },
                borderRadius: radius,
                splashColor: reduceMotion
                    ? CyberPressFeedback.overlay
                    : ripple,
                highlightColor: Colors.transparent,
                splashFactory: reduceMotion
                    ? CyberPressInkSplash.splashFactory
                    : InkRipple.splashFactory,
                child: surfaced,
              ),
            )
          : surfaced,
    );

    if (widget.expand || widget.stretch) {
      return button;
    }
    // Shrink-wrap to label; [Align] widthFactor avoids [Ink]/[Container]
    // full-bleed under loose parent constraints.
    return Align(
      alignment: Alignment.center,
      widthFactor: 1.0,
      heightFactor: 1.0,
      child: button,
    );
  }

  /// Maps deprecated `CyberButtonSize.regular` onto [CyberButtonSize.small].
  static CyberButtonSize _resolvedSize(CyberButtonSize size) {
    if (size == CyberButtonSize.mini) {
      return CyberButtonSize.mini;
    }
    if (size == CyberButtonSize.medium) {
      return CyberButtonSize.medium;
    }
    if (size == CyberButtonSize.large) {
      return CyberButtonSize.large;
    }
    // [small] and deprecated [regular].
    return CyberButtonSize.small;
  }

  static double _heightFor(CyberButtonSize tier) {
    final t = _resolvedSize(tier);
    if (t == CyberButtonSize.mini) {
      return CyberDimens.actionButtonMiniHeight;
    }
    if (t == CyberButtonSize.medium) {
      return CyberDimens.actionButtonMediumHeight;
    }
    if (t == CyberButtonSize.large) {
      return CyberDimens.actionButtonLargeHeight;
    }
    return CyberDimens.actionButtonSmallHeight;
  }

  static double _padHFor(CyberButtonSize tier) {
    final t = _resolvedSize(tier);
    if (t == CyberButtonSize.mini) {
      return CyberDimens.actionButtonMiniPaddingHorizontal;
    }
    if (t == CyberButtonSize.medium) {
      return CyberDimens.actionButtonMediumPaddingHorizontal;
    }
    if (t == CyberButtonSize.large) {
      return CyberDimens.actionButtonLargePaddingHorizontal;
    }
    return CyberDimens.actionButtonSmallPaddingHorizontal;
  }

  static double _fontSizeFor(CyberButtonSize tier) {
    final t = _resolvedSize(tier);
    if (t == CyberButtonSize.mini) {
      return CyberDimens.actionButtonMiniFontSize;
    }
    if (t == CyberButtonSize.medium) {
      return CyberDimens.actionButtonMediumFontSize;
    }
    if (t == CyberButtonSize.large) {
      return CyberDimens.actionButtonLargeFontSize;
    }
    return CyberDimens.actionButtonSmallFontSize;
  }

  static Color _foreground(CyberButtonVariant variant) => switch (variant) {
        CyberButtonVariant.secondary => CyberColors.buttonSecondaryText,
        CyberButtonVariant.standard ||
        CyberButtonVariant.primary ||
        CyberButtonVariant.light =>
          CyberColors.textPrimary,
      };

  static Color? _solidFill(CyberButtonVariant variant) => switch (variant) {
        CyberButtonVariant.primary => CyberColors.buttonPrimaryFill,
        _ => null,
      };

  static Gradient? _fillGradient(CyberButtonVariant variant) =>
      switch (variant) {
        CyberButtonVariant.primary => null,
        CyberButtonVariant.light => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CyberColors.lightFillTop,
              CyberColors.lightFillMid,
              CyberColors.lightFillBottom,
            ],
          ),
        CyberButtonVariant.standard ||
        CyberButtonVariant.secondary =>
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CyberColors.fillTop,
              CyberColors.fillMid,
              CyberColors.fillBottom,
            ],
          ),
      };
}

/// Bounded radial press ripple — Flutter stand-in for Compose `rememberRipple`
/// / Android [RippleDrawable] mask used by Frost IME keycaps.
final class _BoundedPressRipplePainter extends CustomPainter {
  const _BoundedPressRipplePainter({
    required this.origin,
    required this.progress,
    required this.opacity,
    required this.color,
  });

  final Offset origin;
  final double progress;
  final double opacity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || opacity <= 0 || size.isEmpty) {
      return;
    }
    final cover = _coverRadius(origin, size);
    canvas.drawCircle(
      origin,
      cover * progress,
      Paint()
        ..color = color.withOpacity((color.opacity * opacity).clamp(0.0, 1.0)),
    );
  }

  static double _coverRadius(Offset origin, Size size) {
    final corners = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    var maxDist = 0.0;
    for (final c in corners) {
      maxDist = math.max(maxDist, (c - origin).distance);
    }
    return maxDist;
  }

  @override
  bool shouldRepaint(covariant _BoundedPressRipplePainter oldDelegate) =>
      oldDelegate.origin != origin ||
      oldDelegate.progress != progress ||
      oldDelegate.opacity != opacity ||
      oldDelegate.color != color;
}
