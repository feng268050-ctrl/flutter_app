import 'package:cyber_ime/src/field/cyber_ime_field_type.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_alternate_popup.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_keyboard_backdrop.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_keyboard_controller.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_keyboard_panel.dart';
import 'package:cyber_ime/src/overlay/cyber_ime_overlay_scope.dart';
import 'package:cyber_ime/src/session/cyber_ime_action.dart';
import 'package:cyber_ime/src/session/cyber_ime_commit.dart';
import 'package:cyber_ime/src/session/cyber_ime_session.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

export 'package:cyber_ime/src/overlay/cyber_ime_overlay_scope.dart';

/// Inserts a panel-sized CyberIME keyboard into the nearest [Overlay].
///
/// Hit-testing:
/// - Only the keyboard panel (bottom band) participates in hit testing.
/// - The region above the panel MUST pass through to underlying routes
///   (dialog chrome, password visibility toggle, etc.) — no full-screen
///   absorber (see cyber-ime session lift / touch requirement).
///
/// Glass layering (lws-ui `ImeKeyboardBackdropHost` + transparent panel):
/// ```
/// [ keyboard slot ]
///   ├─ CyberImeKeyboardBackdrop  ← one Gaussian blur of content behind slot
///   ├─ CyberImeKeyboardPanel      ← transparent layout + top stroke + keys
///   └─ alternate popup (optional)
/// ```
/// Keycaps are translucent light glass only — no per-key blur.
abstract final class CyberImeOverlay {
  /// Shows the keyboard for [fieldType] bound to [controller].
  static CyberImeOverlayHandle show({
    required BuildContext context,
    required CyberImeFieldType fieldType,
    required TextEditingController controller,
    CyberImeSession? session,
    CyberImeAction action = CyberImeAction.done,
    VoidCallback? onAction,
    VoidCallback? onPasswordReveal,
    double panelHeight = kCyberImePanelHeight,
    /// Called after each successful key commit so the host can keep focus.
    VoidCallback? onKeyActivity,
    /// Invoked when the keyboard is hidden (scrim tap or [CyberImeOverlayHandle.hide]).
    VoidCallback? onHidden,
  }) {
    final overlayState = Overlay.of(context, rootOverlay: true);
    // Overlay / dialog routes sit outside the page scope — resolve from tree.
    final backdropScope = CyberBlurBackdropScope.resolve(context);
    final imeSession = session ?? CyberImeSession.shared;
    final commit = CyberImeControllerCommit(controller);
    final kb = CyberImeKeyboardController(
      fieldType: fieldType,
      commit: commit,
      action: action,
      onAction: onAction,
      onPasswordReveal: onPasswordReveal,
    );
    final detach = imeSession.attach(panelHeight: panelHeight);
    final stackKey = GlobalKey(debugLabel: 'CyberImeOverlayStack');
    final popup = ValueNotifier<CyberImeAlternatePopupData?>(null);

    late OverlayEntry entry;
    late CyberImeOverlayHandle handle;

    void bringToFront() {
      if (handle._closed) return;
      entry.remove();
      overlayState.insert(entry);
    }

    entry = OverlayEntry(
      builder: (ctx) {
        return Material(
          type: MaterialType.transparency,
          child: CyberImeOverlayScope(
            stackKey: stackKey,
            popup: popup,
            bringToFront: bringToFront,
            child: Stack(
              key: stackKey,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: panelHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1) One blur plate — samples UI behind the keyboard band.
                      // Weston Overlay: use firstFrame capture (realtime → black).
                      CyberImeKeyboardBackdrop(
                        sampleMode: backdropScope != null
                            ? CyberBlurSampleMode.firstFrame
                            : CyberBlurSampleMode.realtime,
                        backdropScope: backdropScope,
                      ),
                      // 2) Transparent chrome + translucent keycaps (no blur).
                      Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) => onKeyActivity?.call(),
                        child: CyberImeKeyboardPanel(
                          controller: kb,
                          height: panelHeight,
                        ),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<CyberImeAlternatePopupData?>(
                  valueListenable: popup,
                  builder: (context, data, _) {
                    if (data == null) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: CustomSingleChildLayout(
                        delegate: CyberImeAlternatePopupPositionDelegate(
                          preferredKeyTopCenter: data.anchor,
                        ),
                        child: IgnorePointer(
                          child: CyberImeAlternatePopup(
                            options: data.options,
                            selectedIndex: data.selectedIndex,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    overlayState.insert(entry);

    handle = CyberImeOverlayHandle._(
      entry: entry,
      overlayState: overlayState,
      detachSession: detach,
      keyboard: kb,
      popup: popup,
      onHidden: onHidden,
    );
    handle.bringToFront();
    return handle;
  }
}

class CyberImeOverlayHandle {
  CyberImeOverlayHandle._({
    required OverlayEntry entry,
    required OverlayState overlayState,
    required VoidCallback detachSession,
    required this.keyboard,
    required ValueNotifier<CyberImeAlternatePopupData?> popup,
    VoidCallback? onHidden,
  })  : _entry = entry,
        _overlayState = overlayState,
        _detachSession = detachSession,
        _popup = popup,
        _onHidden = onHidden;

  final OverlayEntry _entry;
  final OverlayState _overlayState;
  final VoidCallback _detachSession;
  final ValueNotifier<CyberImeAlternatePopupData?> _popup;
  final VoidCallback? _onHidden;
  final CyberImeKeyboardController keyboard;
  bool _closed = false;

  bool get isClosed => _closed;

  void bringToFront() {
    if (_closed) return;
    _entry.remove();
    _overlayState.insert(_entry);
  }

  void hide({bool notify = true}) {
    if (_closed) return;
    _closed = true;
    _popup.value = null;
    _popup.dispose();
    _entry.remove();
    _detachSession();
    keyboard.dispose();
    if (notify) {
      _onHidden?.call();
    }
  }
}
