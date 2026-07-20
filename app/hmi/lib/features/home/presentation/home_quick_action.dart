import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Design tokens from lws-ui `home_quick_action_*` / `home_stat_card_corner_radius`.
const double kHomeQuickActionCorner = 18;
const double kHomeQuickActionLabelMarginTop = 10;

/// lws-ui `home_quick_action_label_text` ColorStateList.
const Color _kLabelIdle = Color(0xFFFFFFFF);
const Color _kLabelPressed = Color(0xB3FFFFFF);

/// Frost tile ripple: `FrostButtonTileRipple` → argb(0x3D, 255, 255, 255).
const Color _kTileRipple = Color(0x3DFFFFFF);

/// Home quick-action tile — Material stand-in for lws-ui
/// `FrostQuickActionEntry` + nested `FrostCardView`.
///
/// Matches Android behavior:
/// - Whole entry is the press target (card + caption).
/// - Ripple lives only on the card host (`CardRippleHost`), from the press
///   hotspot (`setHotspot`), clipped to the rounded card — not the label.
/// - Caption uses pressed → `#B3FFFFFF` (duplicate-parent-state ColorStateList).
class HomeQuickAction extends StatefulWidget {
  const HomeQuickAction({
    super.key,
    required this.cardWidth,
    required this.cardHeight,
    required this.label,
    required this.onPressed,
    required this.child,
    this.labelWidth,
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
  final GlobalKey _cardKey = GlobalKey();
  BuildContext? _inkContext;
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

  void _createSplash(Offset globalPosition) {
    final inkContext = _inkContext;
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (inkContext == null || box == null || !box.hasSize) {
      return;
    }
    final controller = Material.maybeOf(inkContext);
    if (controller == null) {
      return;
    }
    _splash?.dispose();
    final local = box.globalToLocal(globalPosition);
    final radius = BorderRadius.circular(widget.cornerRadius);
    _splash = InkRipple.splashFactory.create(
      controller: controller,
      referenceBox: box,
      position: local,
      color: _kTileRipple,
      textDirection: Directionality.of(inkContext),
      containedInkWell: true,
      borderRadius: radius,
      onRemoved: () {
        _splash = null;
      },
    );
  }

  void _handleTapDown(TapDownDetails details) {
    _setPressed(true);
    // Card Material must be laid out before Material.of / referenceBox.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pressed) {
        return;
      }
      _createSplash(details.globalPosition);
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _activate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CardRippleHost: glass chrome + ink clipped to rounded card.
          Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: Builder(
              builder: (inkContext) {
                _inkContext = inkContext;
                return SizedBox(
                  key: _cardKey,
                  width: widget.cardWidth,
                  height: widget.cardHeight,
                  child: CyberCard(
                    width: widget.cardWidth,
                    height: widget.cardHeight,
                    sampleMode: widget.sampleMode,
                    intensity: widget.blurIntensity,
                    blurTint: widget.blurTint,
                    borderRadius: radius,
                    child: widget.child,
                  ),
                );
              },
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
                fontSize: (16 * (widget.cardHeight / 108)).clamp(12, 20),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
