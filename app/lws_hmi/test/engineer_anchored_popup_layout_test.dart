import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_anchored_popup_layout.dart';

void main() {
  test('FrostPopupMenu-style origin right-aligns under anchor', () {
    const overlay = Size(1280, 800);
    const anchor = Rect.fromLTWH(900, 120, 180, 40);
    final origin = EngineerAnchoredPopupLayout.origin(
      overlaySize: overlay,
      localAnchorRect: anchor,
      popupWidth: 350,
    );
    // anchor.right (1080) - width (350)
    expect(origin.dx, closeTo(730, 0.01));
    // anchor.bottom (160) + 4dp gap
    expect(origin.dy, closeTo(164, 0.01));
  });

  test('origin clamps to overlay left edge', () {
    const overlay = Size(400, 800);
    const anchor = Rect.fromLTWH(50, 100, 80, 30);
    final origin = EngineerAnchoredPopupLayout.origin(
      overlaySize: overlay,
      localAnchorRect: anchor,
      popupWidth: 350,
    );
    expect(origin.dx, 0);
    expect(origin.dy, 134);
  });
}
