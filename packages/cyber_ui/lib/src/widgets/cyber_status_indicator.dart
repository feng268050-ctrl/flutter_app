import 'package:flutter/material.dart';

/// CyberUI status light (Material stand-in for lws-ui FrostStatusIndicator).
///
/// Four common presentations (as in product reference shots):
/// 1. [CyberStatusState.idle] — gray disc
/// 2. [CyberStatusState.success] + [CyberStatusVariant.dot] — solid green disc
///    (fills the idle gray circle when monitoring passes)
/// 3. [CyberStatusState.success] + [CyberStatusVariant.icon] — green disc + white check
/// 4. [CyberStatusState.failure] + [CyberStatusVariant.icon] — red disc + white cross
///
/// Also supports [CyberStatusState.inProgress] (gray + yellow center) from Frost.
enum CyberStatusState { idle, inProgress, success, failure }

enum CyberStatusVariant { dot, icon }

/// Colors aligned with lws-ui `frost_status_*`.
abstract final class CyberStatusColors {
  static const idle = Color(0x99FFFFFF);
  static const inProgressDot = Color(0xFFFFCC00);
  static const success = Color(0xFF34C759);
  static const failure = Color(0xFFFF3B30);
  static const glyph = Colors.white;
}

class CyberStatusIndicator extends StatelessWidget {
  const CyberStatusIndicator({
    super.key,
    required this.state,
    this.variant = CyberStatusVariant.icon,
    this.size = 36,
  });

  final CyberStatusState state;
  final CyberStatusVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolve(state, variant);
    final glyphSize = size * 0.55;

    // Solid disc (no soft radial fade): idle/success/failure must share the
    // same painted diameter at [size]. A fade-to-transparent edge made idle
    // gray look smaller than solid red/green on Alarm Comm cards.
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: resolved.background,
        ),
        child: Center(
          child: switch (resolved.kind) {
            _GlyphKind.none => const SizedBox.shrink(),
            _GlyphKind.dot => Container(
                width: size * 0.42,
                height: size * 0.42,
                decoration: BoxDecoration(
                  color: resolved.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            _GlyphKind.check => Icon(
                Icons.check_rounded,
                size: glyphSize,
                color: CyberStatusColors.glyph,
              ),
            _GlyphKind.cross => Icon(
                Icons.close_rounded,
                size: glyphSize,
                color: CyberStatusColors.glyph,
              ),
          },
        ),
      ),
    );
  }
}

enum _GlyphKind { none, dot, check, cross }

class _Resolved {
  const _Resolved({
    required this.background,
    required this.kind,
    this.dotColor,
  });

  final Color background;
  final _GlyphKind kind;
  final Color? dotColor;
}

_Resolved _resolve(CyberStatusState state, CyberStatusVariant variant) {
  switch (state) {
    case CyberStatusState.idle:
      return const _Resolved(
        background: CyberStatusColors.idle,
        kind: _GlyphKind.none,
      );
    case CyberStatusState.inProgress:
      return const _Resolved(
        background: CyberStatusColors.idle,
        kind: _GlyphKind.dot,
        dotColor: CyberStatusColors.inProgressDot,
      );
    case CyberStatusState.success:
      if (variant == CyberStatusVariant.dot) {
        // Machine Status tiles: green fills the whole gray circle on pass.
        return const _Resolved(
          background: CyberStatusColors.success,
          kind: _GlyphKind.none,
        );
      }
      return const _Resolved(
        background: CyberStatusColors.success,
        kind: _GlyphKind.check,
      );
    case CyberStatusState.failure:
      if (variant == CyberStatusVariant.dot) {
        return const _Resolved(
          background: CyberStatusColors.idle,
          kind: _GlyphKind.dot,
          dotColor: CyberStatusColors.failure,
        );
      }
      return const _Resolved(
        background: CyberStatusColors.failure,
        kind: _GlyphKind.cross,
      );
  }
}
