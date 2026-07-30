import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Design tokens from lws-ui `home_quick_action_*` / `home_stat_card_corner_radius`.
const double kHomeQuickActionCorner = 18;
const double kHomeQuickActionLabelMarginTop = 10;

/// Caption reference used to size all home quick-action labels equally.
const String kHomeQuickActionLabelSizeRef = 'Settings';

/// lws-ui `home_quick_action_label_text` ColorStateList.
const Color _kLabelIdle = Color(0xFFFFFFFF);
const Color _kLabelPressed = Color(0xB3FFFFFF);

/// lws-ui `FrostButtonTileRipple` → argb(0x3D, 255, 255, 255) ≈ 24% white.
/// Shared with Quick / Engineer `FrostRippleClickEntry` (mask shape differs).
const Color _kTileRipple = Color(0x3DFFFFFF);

/// Font size so [kHomeQuickActionLabelSizeRef] fits [cardWidth] with equal
/// side inset (~11% each side) so the caption is not clipped.
double homeQuickActionLabelFontSize(double cardWidth) {
  const weight = FontWeight.w500;
  final targetWidth = cardWidth * 0.78;
  var lo = 12.0;
  var hi = 64.0;
  for (var i = 0; i < 14; i++) {
    final mid = (lo + hi) / 2;
    final probe = TextPainter(
      text: TextSpan(
        text: kHomeQuickActionLabelSizeRef,
        style: TextStyle(fontSize: mid, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (probe.width > targetWidth) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return lo;
}

/// Home quick-action tile — Flutter stand-in for lws-ui
/// `FrostQuickActionEntry` + nested `FrostCardView`.
///
/// Architecture (matches Android):
/// - Outer entry is the press target (card + caption) — like
///   `FrostQuickActionEntry` with `duplicateParentStateEnabled`.
/// - Glass [CyberCard] is appearance only (no own gestures).
/// - Transparent [_CardRippleHost] sits **above** the card and hosts
///   Material [InkRipple] (= Android `setForeground(RippleDrawable)`).
/// - Hotspot is mapped into host-local coords on press (`setHotspot`).
///
/// Not the looping Quick/Engineer WebP halo — those are separate assets.
class HomeQuickAction extends StatefulWidget {
  const HomeQuickAction({
    super.key,
    required this.cardWidth,
    required this.cardHeight,
    required this.label,
    required this.onPressed,
    required this.child,
    this.labelWidth,
    this.labelFontSize,
    this.cornerRadius = kHomeQuickActionCorner,
    this.labelMarginTop = kHomeQuickActionLabelMarginTop,
    this.sampleMode = CyberBlurSampleMode.realtime,
    this.blurIntensity = CyberBlurIntensity.extreme,
    this.blurTint = CyberBlurTint.warm,
    this.clickSoundEnabled = true,
  });

  final double cardWidth;
  final double cardHeight;
  final String label;
  final VoidCallback onPressed;
  final Widget child;

  /// Defaults to [cardWidth] (square tiles). Wide AI Vision passes its card width.
  final double? labelWidth;

  /// When null, sizes so [kHomeQuickActionLabelSizeRef] matches [cardWidth].
  final double? labelFontSize;
  final double cornerRadius;
  final double labelMarginTop;

  final CyberBlurSampleMode sampleMode;
  final CyberBlurIntensity blurIntensity;
  final CyberBlurTint blurTint;
  final bool clickSoundEnabled;

  @override
  State<HomeQuickAction> createState() => _HomeQuickActionState();
}

class _HomeQuickActionState extends State<HomeQuickAction> {
  final GlobalKey _rippleHostKey = GlobalKey();
  BuildContext? _rippleMaterialContext;
  InteractiveInkFeature? _splash;
  bool _pressed = false;

  void _activate() {
    if (widget.clickSoundEnabled) {
      CyberClickSoundRegistry.playClick();
    }
    widget.onPressed();
  }

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  /// Entry press → ripple-host local coords (lws-ui `updateRippleHotspot`).
  Offset _hotspotInHost(Offset globalPosition) {
    final box = _rippleHostKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return Offset(widget.cardWidth / 2, widget.cardHeight / 2);
    }
    final local = box.globalToLocal(globalPosition);
    return Offset(
      local.dx.clamp(0.0, box.size.width),
      local.dy.clamp(0.0, box.size.height),
    );
  }

  bool _tryCreateSplash(Offset globalPosition) {
    final inkContext = _rippleMaterialContext;
    final box = _rippleHostKey.currentContext?.findRenderObject() as RenderBox?;
    if (inkContext == null || box == null || !box.hasSize) {
      return false;
    }
    final controller = Material.maybeOf(inkContext);
    if (controller == null) {
      return false;
    }
    _splash?.dispose();
    final hotspot = _hotspotInHost(globalPosition);
    final radius = BorderRadius.circular(widget.cornerRadius);
    // InkRipple ≈ Android RippleDrawable (bounded by rounded mask).
    _splash = InkRipple.splashFactory.create(
      controller: controller,
      referenceBox: box,
      position: hotspot,
      color: _kTileRipple,
      textDirection: Directionality.of(inkContext),
      containedInkWell: true,
      borderRadius: radius,
      onRemoved: () {
        _splash = null;
      },
    );
    return true;
  }

  void _handleTapDown(TapDownDetails details) {
    _setPressed(true);
    if (_tryCreateSplash(details.globalPosition)) {
      return;
    }
    // First layout: Material/host may not be ready until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pressed) {
        return;
      }
      _tryCreateSplash(details.globalPosition);
    });
  }

  void _handleTapUp(TapUpDetails details) {
    _setPressed(false);
    _splash?.confirm();
  }

  void _handleTapCancel() {
    _setPressed(false);
    _splash?.cancel();
  }

  @override
  void dispose() {
    _splash?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final captionWidth = widget.labelWidth ?? widget.cardWidth;
    final radius = BorderRadius.circular(widget.cornerRadius);
    final labelColor = _pressed ? _kLabelPressed : _kLabelIdle;
    final fontSize =
        widget.labelFontSize ?? homeQuickActionLabelFontSize(widget.cardWidth);

    // Outer entry = press target (card + caption), like FrostQuickActionEntry.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _activate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.cardWidth,
            height: widget.cardHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Appearance only — CyberCard does not own gestures.
                CyberCard(
                  width: widget.cardWidth,
                  height: widget.cardHeight,
                  sampleMode: widget.sampleMode,
                  intensity: widget.blurIntensity,
                  blurTint: widget.blurTint,
                  borderRadius: radius,
                  child: widget.child,
                ),
                // CardRippleHost: transparent foreground above the glass card
                // (= Android FrameLayout + setForeground(RippleDrawable)).
                _CardRippleHost(
                  hostKey: _rippleHostKey,
                  borderRadius: radius,
                  onMaterialContext: (ctx) => _rippleMaterialContext = ctx,
                ),
              ],
            ),
          ),
          SizedBox(height: widget.labelMarginTop),
          SizedBox(
            width: captionWidth,
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Transparent ripple host above the glass card.
///
/// Ink paints on this [Material] only — content stays null (card unchanged),
/// clip + [borderRadius] act as the rounded white mask from
/// `FrostButtonTileRipple.createTileRippleForeground`.
final class _CardRippleHost extends StatelessWidget {
  const _CardRippleHost({
    required this.hostKey,
    required this.borderRadius,
    required this.onMaterialContext,
  });

  final GlobalKey hostKey;
  final BorderRadius borderRadius;
  final ValueChanged<BuildContext> onMaterialContext;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        key: hostKey,
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Builder(
          builder: (materialContext) {
            onMaterialContext(materialContext);
            // Empty child: ripple content is null; mask = this clipped Material.
            return const SizedBox.expand();
          },
        ),
      ),
    );
  }
}
