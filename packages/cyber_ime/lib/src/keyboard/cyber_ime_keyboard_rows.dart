import 'dart:math' as math;

import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_layout.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Builds one key face for [CyberImeKeyboardRows] (live KeyCap or preview button).
typedef CyberImeKeyFaceBuilder = Widget Function(CyberImeKeyDef keyDef);

/// Shared Keyboard A/B row chrome (live panel + layout preview).
///
/// Resolves ISO L-Enter (`rowSpan: 2`) into one inverted-L key: letter-row
/// Enter is full width; home row (longer Caps) shifts right and notches into it.
class CyberImeKeyboardRows extends StatelessWidget {
  const CyberImeKeyboardRows({
    super.key,
    required this.layout,
    required this.keyFace,
  });

  final CyberImeLayout layout;
  final CyberImeKeyFaceBuilder keyFace;

  static const double rowGap = 6;

  /// Horizontal inset on each key face; adjacent faces are [keyPadH]×2 apart.
  static const double keyPadH = 2;

  @override
  Widget build(BuildContext context) {
    final rows = layout.rows;
    final children = <Widget>[];
    for (var r = 0; r < rows.length; r++) {
      if (r > 0) children.add(const SizedBox(height: rowGap));
      final spanning = spanningEnterOf(rows[r]);
      if (spanning != null && r + 1 < rows.length) {
        children.add(
          Expanded(
            flex: 2,
            child: _IsoEnterBlock(
              upper: rows[r],
              lower: rows[r + 1],
              enter: spanning,
              keyFace: keyFace,
            ),
          ),
        );
        r++; // consume home row under L-Enter
        continue;
      }
      children.add(
        Expanded(
          child: CyberImeFlatKeyRow(row: rows[r], keyFace: keyFace),
        ),
      );
    }
    return Column(children: children);
  }

  /// Enter key with [CyberImeKeyDef.rowSpan] > 1, if present on [row].
  static CyberImeKeyDef? spanningEnterOf(CyberImeKeyboardRow row) {
    for (final k in row.keys) {
      if (k.id == CyberImeKeyId.enter && k.rowSpan > 1) return k;
    }
    return null;
  }
}

class _IsoEnterBlock extends StatelessWidget {
  const _IsoEnterBlock({
    required this.upper,
    required this.lower,
    required this.enter,
    required this.keyFace,
  });

  final CyberImeKeyboardRow upper;
  final CyberImeKeyboardRow lower;
  final CyberImeKeyDef enter;
  final CyberImeKeyFaceBuilder keyFace;

  @override
  Widget build(BuildContext context) {
    final upperKeys =
        upper.keys.where((k) => k.id != CyberImeKeyId.enter).toList();
    final lowerKeys =
        lower.keys.where((k) => k.id != CyberImeKeyId.enter).toList();
    final upperLeft = _flexSum(upperKeys, upper.leadingInsetWeight);
    final lowerLeft = _flexSum(lowerKeys, lower.leadingInsetWeight);
    final enterTop = (enter.widthWeight * 10).round().clamp(1, 100);
    final total = upperLeft + enterTop;
    // Longer Caps on home row → larger lowerLeft → narrower enter bottom (倒 L).
    final enterBottom = (total - lowerLeft).clamp(1, enterTop);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const gap = CyberImeKeyboardRows.rowGap;
        final rowH = (h - gap) / 2;
        final unit = w / total;
        final enterTopW = enterTop * unit;
        final enterBottomW = enterBottom * unit;
        final upperKeysW = upperLeft * unit;
        final lowerKeysW = lowerLeft * unit;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              width: upperKeysW,
              height: rowH,
              child: CyberImeFlatKeyRow(
                row: CyberImeKeyboardRow(
                  upperKeys,
                  leadingInsetWeight: upper.leadingInsetWeight,
                ),
                keyFace: keyFace,
              ),
            ),
            Positioned(
              top: rowH + gap,
              left: 0,
              width: lowerKeysW,
              height: rowH,
              child: CyberImeFlatKeyRow(
                row: CyberImeKeyboardRow(
                  lowerKeys,
                  leadingInsetWeight: lower.leadingInsetWeight,
                ),
                keyFace: keyFace,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              width: enterTopW,
              height: h,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CyberImeKeyboardRows.keyPadH,
                ),
                child: ClipPath(
                  clipper: _IsoInvertedLEnterClipper(
                    topHeight: rowH,
                    gap: gap,
                    // Match face gap above `#` to the gap on its right.
                    faceGap: CyberImeKeyboardRows.keyPadH * 2,
                    bottomWidthFraction: enterBottomW / enterTopW,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: keyFace(enter),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static int _flexSum(List<CyberImeKeyDef> keys, double leading) {
    var sum = (leading * 10).round();
    for (final k in keys) {
      sum += (k.widthWeight * 10).round();
    }
    return sum.clamp(1, 10000);
  }
}

/// Right-aligned inverted-L: full width on letter row, narrower bottom on home.
///
/// Notch corners (around `#` top-right) use the same radius as keycaps so the
/// cut is rounded rather than a sharp 90° bite. The overhang stops [faceGap]
/// above the home row so `#` has matching top/right gutters.
class _IsoInvertedLEnterClipper extends CustomClipper<Path> {
  const _IsoInvertedLEnterClipper({
    required this.topHeight,
    required this.gap,
    required this.faceGap,
    required this.bottomWidthFraction,
  });

  final double topHeight;
  final double gap;
  final double faceGap;
  final double bottomWidthFraction;

  static const double _corner =
      CyberDimens.rectangleButtonCornerRadius;

  @override
  Path getClip(Size size) {
    final topW = size.width;
    final bottomW = (topW * bottomWidthFraction).clamp(1.0, topW);
    final bottomLeft = topW - bottomW;
    // Home-row top is topHeight+gap; leave [faceGap] so top gutter == right gutter.
    final bottomTop =
        (topHeight + gap - faceGap).clamp(topHeight, topHeight + gap);
    final r = math.min(
      _corner,
      math.min(
        bottomLeft / 2,
        math.min(
          bottomW / 2,
          math.min(bottomTop / 2, (size.height - bottomTop) / 2),
        ),
      ),
    );
    if (r <= 0) {
      return Path()
        ..moveTo(0, 0)
        ..lineTo(topW, 0)
        ..lineTo(topW, size.height)
        ..lineTo(bottomLeft, size.height)
        ..lineTo(bottomLeft, bottomTop)
        ..lineTo(0, bottomTop)
        ..close();
    }
    final rad = Radius.circular(r);
    // Clockwise around Enter. Notch at (bottomLeft, bottomTop): concave fillet
    // (into the key). Outer corner at (0, bottomTop): convex round.
    return Path()
      ..moveTo(r, 0)
      ..lineTo(topW - r, 0)
      ..arcToPoint(Offset(topW, r), radius: rad)
      ..lineTo(topW, size.height - r)
      ..arcToPoint(Offset(topW - r, size.height), radius: rad)
      ..lineTo(bottomLeft + r, size.height)
      ..arcToPoint(Offset(bottomLeft, size.height - r), radius: rad)
      ..lineTo(bottomLeft, bottomTop + r)
      ..arcToPoint(
        Offset(bottomLeft - r, bottomTop),
        radius: rad,
        clockwise: false,
      )
      ..lineTo(r, bottomTop)
      ..arcToPoint(Offset(0, bottomTop - r), radius: rad)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: rad)
      ..close();
  }

  @override
  bool shouldReclip(covariant _IsoInvertedLEnterClipper oldClipper) {
    return oldClipper.topHeight != topHeight ||
        oldClipper.gap != gap ||
        oldClipper.faceGap != faceGap ||
        oldClipper.bottomWidthFraction != bottomWidthFraction;
  }
}

/// One horizontal key row (weights + optional leading/trailing insets).
class CyberImeFlatKeyRow extends StatelessWidget {
  const CyberImeFlatKeyRow({
    super.key,
    required this.row,
    required this.keyFace,
  });

  final CyberImeKeyboardRow row;
  final CyberImeKeyFaceBuilder keyFace;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (row.leadingInsetWeight > 0)
          Spacer(flex: (row.leadingInsetWeight * 10).round().clamp(1, 100)),
        for (final key in row.keys)
          Expanded(
            flex: (key.widthWeight * 10).round().clamp(1, 100),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CyberImeKeyboardRows.keyPadH,
              ),
              child: keyFace(key),
            ),
          ),
        if (row.trailingInsetWeight > 0)
          Spacer(flex: (row.trailingInsetWeight * 10).round().clamp(1, 100)),
      ],
    );
  }
}
