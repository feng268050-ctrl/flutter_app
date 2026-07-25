import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Layout helpers matching lws-ui [FrostPopupMenu.show].
///
/// Converts a screen-space anchor into the [overlay]'s local coordinates
/// (required when [MaterialApp.builder] applies FittedBox density scaling on
/// Weston / DPR≈1), then right-aligns the popup under the anchor.
abstract final class EngineerAnchoredPopupLayout {
  static const double gapBelowAnchor = 4;

  /// [globalAnchor] from [RenderBox.localToGlobal] + size.
  static Rect localAnchor({
    required RenderBox overlay,
    required Rect globalAnchor,
  }) {
    final topLeft = overlay.globalToLocal(globalAnchor.topLeft);
    final bottomRight = overlay.globalToLocal(globalAnchor.bottomRight);
    return Rect.fromPoints(topLeft, bottomRight);
  }

  /// Right edge of popup aligns to right edge of [localAnchorRect] (+ [xOffset]).
  static Offset origin({
    required Size overlaySize,
    required Rect localAnchorRect,
    required double popupWidth,
    double gapBelow = gapBelowAnchor,
    double xOffset = 0,
  }) {
    final anchorRight = localAnchorRect.right;
    var left = anchorRight - popupWidth + xOffset;
    final maxLeft =
        (overlaySize.width - popupWidth).clamp(0.0, double.infinity);
    left = left.clamp(0.0, maxLeft).toDouble();
    final top = localAnchorRect.bottom + gapBelow;
    return Offset(left, top);
  }

  static RenderBox? overlayBox(BuildContext context) {
    final renderObject =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderObject == null || !renderObject.hasSize) {
      return null;
    }
    return renderObject;
  }
}
