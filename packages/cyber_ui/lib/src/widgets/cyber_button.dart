import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';
import 'package:cyber_ui/src/theme/cyber_panel_outline.dart';
import 'package:cyber_ui/src/theme/cyber_tone.dart';

/// Frost `FrostButton` variants (`DEFAULT` → [standard]).
enum CyberButtonVariant { standard, primary, secondary, light }

enum CyberButtonSize {
  small,
  medium,
  large,

  /// Alias for [medium] — prefer [medium] in new code.
  @Deprecated('Use CyberButtonSize.medium')
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
}

/// Frost-styled button (Material [InkRipple] + shape; lws-ui `FrostButton`).
///
/// Press feedback matches `FrostButtonPressFeedback`:
/// - Bounded ripple clipped to the button radius.
/// - LIGHT → black ripple; PRIMARY/DEFAULT → white `0x3D`; SECONDARY → `0x2A`.
/// - DEFAULT/SECONDARY face alpha 225→255 (70ms in / 140ms out); LIGHT/PRIMARY
///   stay at full opacity (ripple is the visible cue — same as IME).
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
    this.size = CyberButtonSize.medium,
    this.shape = CyberButtonShape.rectangle,
    this.clickSoundEnabled = true,
    this.expand = false,
    this.stretch = false,
    this.height,
    this.foregroundColor,
    this.onLongPress,
    this.borderGradientCenter = CyberBorderGradientCenter.topLeftBottomRight,
    this.borderGradientColors,
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

  /// Frost `borderGradientCenter` for the 1dp stroke.
  final CyberBorderGradientCenter borderGradientCenter;

  /// Optional HL / mid / shadow override for the frost rim (e.g. brighter
  /// engineer Reset / Save pills). When null, uses [variant] defaults.
  final List<Color>? borderGradientColors;

  /// Stroke width override; defaults to [CyberDimens.buttonStrokeWidth].
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
  Offset _rippleOrigin = Offset.zero;
  bool _inkHighlighted = false;

  bool get _enabled => widget.onPressed != null;

  bool get _externalDown =>
      widget.externalPress != null && widget.externalPress!.value != null;

  bool get _pressed => _inkHighlighted || _externalDown;

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
    super.dispose();
  }

  void _onExternalPress() {
    if (!mounted || widget.inkWellGestures || !_enabled) {
      return;
    }
    final hotspot = widget.externalPress?.value;
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
    setState(() {});
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

    final outline = CyberPanelOutline(
      style: CyberPanelOutlineStyle.frostGradient,
      tone: widget.variant == CyberButtonVariant.light
          ? CyberTone.light
          : CyberTone.dark,
      width: widget.strokeWidth ?? CyberDimens.buttonStrokeWidth,
      cornerRadius: cornerRadius,
      gradientCenter: widget.borderGradientCenter,
      gradientColorsOverride:
          widget.borderGradientColors ?? _borderGradientColors(widget.variant),
      uniformColor: _borderFlat(widget.variant),
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
    final faceAlpha = !enabled
        ? CyberButtonPressDefaults.disabledOpacity
        : (_pressed ? CyberButtonPressDefaults.pressedAlpha : resting);

    final body = AnimatedOpacity(
      duration: _pressed
          ? CyberButtonPressDefaults.pressIn
          : CyberButtonPressDefaults.pressOut,
      opacity: faceAlpha,
      child: face,
    );

    Widget childBox = body;
    if (widget.expand) {
      childBox = SizedBox.expand(child: body);
    } else if (widget.stretch) {
      childBox = SizedBox(
        width: double.infinity,
        height: resolvedHeight,
        child: body,
      );
    }

    final ripple = CyberButtonPressDefaults.rippleColor(widget.variant);
    final useInkWell = widget.inkWellGestures && enabled;
    final showExternalRipple = !widget.inkWellGestures;

    // Face + optional external foreground ripple (IME PressInteraction path).
    Widget surfaced = childBox;
    if (showExternalRipple) {
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

    final button = Material(
      key: _hostKey,
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: useInkWell
          ? InkWell(
              onTap: _handleTap,
              onLongPress: widget.onLongPress,
              onHighlightChanged: (v) {
                if (_inkHighlighted == v) {
                  return;
                }
                setState(() => _inkHighlighted = v);
              },
              borderRadius: radius,
              splashColor: ripple,
              highlightColor: Colors.transparent,
              splashFactory: InkRipple.splashFactory,
              child: surfaced,
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

  /// Maps deprecated `CyberButtonSize.regular` onto [CyberButtonSize.medium].
  static CyberButtonSize _resolvedSize(CyberButtonSize size) {
    if (size == CyberButtonSize.small) {
      return CyberButtonSize.small;
    }
    if (size == CyberButtonSize.large) {
      return CyberButtonSize.large;
    }
    return CyberButtonSize.medium;
  }

  static double _heightFor(CyberButtonSize tier) {
    final t = _resolvedSize(tier);
    if (t == CyberButtonSize.small) {
      return CyberDimens.actionButtonSmallHeight;
    }
    if (t == CyberButtonSize.large) {
      return CyberDimens.actionButtonLargeHeight;
    }
    return CyberDimens.actionButtonMediumHeight;
  }

  static double _padHFor(CyberButtonSize tier) {
    final t = _resolvedSize(tier);
    if (t == CyberButtonSize.small) {
      return CyberDimens.actionButtonSmallPaddingHorizontal;
    }
    if (t == CyberButtonSize.large) {
      return CyberDimens.actionButtonLargePaddingHorizontal;
    }
    return CyberDimens.actionButtonMediumPaddingHorizontal;
  }

  static double _fontSizeFor(CyberButtonSize tier) {
    final t = _resolvedSize(tier);
    if (t == CyberButtonSize.small) {
      return CyberDimens.actionButtonSmallFontSize;
    }
    if (t == CyberButtonSize.large) {
      return CyberDimens.actionButtonLargeFontSize;
    }
    return CyberDimens.actionButtonMediumFontSize;
  }

  static Color _foreground(CyberButtonVariant variant) => switch (variant) {
        CyberButtonVariant.secondary => CyberColors.buttonSecondaryText,
        CyberButtonVariant.standard ||
        CyberButtonVariant.primary ||
        CyberButtonVariant.light =>
          CyberColors.textPrimary,
      };

  static Color _borderFlat(CyberButtonVariant variant) => switch (variant) {
        CyberButtonVariant.primary => CyberColors.buttonPrimaryBorderMid,
        CyberButtonVariant.light => CyberColors.lightBorderHighlight,
        CyberButtonVariant.standard ||
        CyberButtonVariant.secondary =>
          CyberColors.borderUniform,
      };

  static List<Color>? _borderGradientColors(CyberButtonVariant variant) =>
      switch (variant) {
        CyberButtonVariant.primary => const [
            CyberColors.buttonPrimaryBorderHighlight,
            CyberColors.buttonPrimaryBorderMid,
            CyberColors.buttonPrimaryBorderShadow,
          ],
        CyberButtonVariant.light => const [
            CyberColors.lightBorderHighlight,
            CyberColors.lightBorderMid,
            CyberColors.lightBorderShadow,
          ],
        CyberButtonVariant.standard || CyberButtonVariant.secondary => null,
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
