import 'package:cyber_ime/src/keyboard/cyber_ime_alternate_popup.dart';
import 'package:flutter/material.dart';

/// Provides the IME overlay [Stack] so keycaps can host alternate popups above
/// dialog chrome (lws-ui `ImeKeyboardOverlay` elevation / bring-to-front).
class CyberImeOverlayScope extends InheritedWidget {
  const CyberImeOverlayScope({
    super.key,
    required this.stackKey,
    required this.popup,
    required this.bringToFront,
    required super.child,
  });

  final GlobalKey stackKey;
  final ValueNotifier<CyberImeAlternatePopupData?> popup;
  final VoidCallback bringToFront;

  static CyberImeOverlayScope? maybeOf(BuildContext context) {
    // getInherited* (not dependOn*) so keycaps can clear popup from dispose.
    return context.getInheritedWidgetOfExactType<CyberImeOverlayScope>();
  }

  @override
  bool updateShouldNotify(CyberImeOverlayScope oldWidget) {
    return stackKey != oldWidget.stackKey ||
        popup != oldWidget.popup ||
        bringToFront != oldWidget.bringToFront;
  }
}
