import 'dart:async';

import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_alternate_popup.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_gestures.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_popup.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_keyboard_controller.dart';
import 'package:cyber_ime/src/overlay/cyber_ime_overlay_scope.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Default panel height used for lift (logical pixels).
const double kCyberImePanelHeight = 280;

const Color _kCapsLockDotActive = Color(0xFF32D74B);

/// Visual + interactive CyberIME keyboard panel (panel-sized hit target only).
///
/// Glass model (lws-ui):
/// - Blur lives in a **sibling** [CyberImeKeyboardBackdrop] under this panel.
/// - This panel is transparent (layout + top edge stroke only).
/// - Keycaps are translucent light glass ([CyberButtonVariant.light]) with no
///   per-key blur — gaps and key faces share the same base frost.
class CyberImeKeyboardPanel extends StatelessWidget {
  const CyberImeKeyboardPanel({
    super.key,
    required this.controller,
    this.height = kCyberImePanelHeight,
  });

  final CyberImeKeyboardController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final layout = controller.layout;
        return Material(
          type: MaterialType.transparency,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: CyberColors.borderHighlight,
                    width: 0.5,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                child: Column(
                  children: [
                    for (var r = 0; r < layout.rows.length; r++) ...[
                      if (r > 0) const SizedBox(height: 6),
                      Expanded(
                        child: _KeyRow(
                          row: layout.rows[r],
                          kind: layout.kind,
                          shiftOn: controller.shiftActive,
                          capsLock: controller.capsLock,
                          onTap: controller.onKeyTap,
                          onShiftLongPress: controller.onShiftLongPress,
                          onPopupCommit: controller.commitPopupText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.row,
    required this.kind,
    required this.shiftOn,
    required this.capsLock,
    required this.onTap,
    required this.onShiftLongPress,
    required this.onPopupCommit,
  });

  final CyberImeKeyboardRow row;
  final CyberImeKeyboardKind kind;
  final bool shiftOn;
  final bool capsLock;
  final ValueChanged<CyberImeKeyDef> onTap;
  final VoidCallback onShiftLongPress;
  final ValueChanged<String> onPopupCommit;

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
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: CyberImeKeyCap(
                keyDef: key,
                kind: kind,
                shiftOn: shiftOn,
                capsLock: capsLock,
                onTap: () => onTap(key),
                onShiftLongPress: key.id == CyberImeKeyId.shift
                    ? onShiftLongPress
                    : null,
                onPopupCommit: onPopupCommit,
              ),
            ),
          ),
        if (row.trailingInsetWeight > 0)
          Spacer(flex: (row.trailingInsetWeight * 10).round().clamp(1, 100)),
      ],
    );
  }
}

/// Single keycap — [CyberButton] chrome + lws-ui alternate long-press gestures.
class CyberImeKeyCap extends StatefulWidget {
  const CyberImeKeyCap({
    super.key,
    required this.keyDef,
    required this.kind,
    required this.shiftOn,
    required this.capsLock,
    required this.onTap,
    this.onShiftLongPress,
    this.onPopupCommit,
  });

  final CyberImeKeyDef keyDef;
  final CyberImeKeyboardKind kind;
  final bool shiftOn;
  final bool capsLock;
  final VoidCallback onTap;
  final VoidCallback? onShiftLongPress;
  final ValueChanged<String>? onPopupCommit;

  @override
  State<CyberImeKeyCap> createState() => _CyberImeKeyCapState();
}

class _CyberImeKeyCapState extends State<CyberImeKeyCap> {
  OverlayEntry? _fallbackPopupEntry;
  ValueNotifier<CyberImeAlternatePopupData?>? _scopedPopup;
  int _selectedIndex = 0;
  Timer? _longPressTimer;
  int? _activePointer;
  double _keyWidth = 0;
  bool _popupActive = false;

  bool get _accentLabel {
    switch (widget.keyDef.id) {
      case CyberImeKeyId.backspace:
        return true;
      case CyberImeKeyId.clear:
      case CyberImeKeyId.minus:
        return widget.kind == CyberImeKeyboardKind.numericDedicated ||
            widget.kind == CyberImeKeyboardKind.symbolsPrimary;
      default:
        return false;
    }
  }

  bool get _isPrimary => widget.keyDef.id == CyberImeKeyId.enter;

  bool get _usesAlternateGestures =>
      widget.keyDef.id != CyberImeKeyId.shift &&
      widget.keyDef.supportsAlternatePopup;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _removePopup();
    super.dispose();
  }

  void _removePopup() {
    _scopedPopup?.value = null;
    _scopedPopup = null;
    _fallbackPopupEntry?.remove();
    _fallbackPopupEntry = null;
    _popupActive = false;
  }

  Offset? _popupAnchorInStack(CyberImeOverlayScope scope) {
    final keyBox = context.findRenderObject() as RenderBox?;
    final stackCtx = scope.stackKey.currentContext;
    final stackBox = stackCtx?.findRenderObject() as RenderBox?;
    if (keyBox == null ||
        !keyBox.attached ||
        !keyBox.hasSize ||
        stackBox == null ||
        !stackBox.hasSize) {
      return null;
    }
    final origin = stackBox.globalToLocal(keyBox.localToGlobal(Offset.zero));
    return Offset(
      origin.dx + keyBox.size.width / 2,
      origin.dy - kCyberImeAlternatePopupOffsetAboveKey,
    );
  }

  void _showAlternatePopup() {
    final options = widget.keyDef.popupOptions();
    if (options.isEmpty) return;
    _removePopup();
    _selectedIndex = cyberImeDefaultPopupIndex(options.length);
    _popupActive = true;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      _keyWidth = box.size.width;
    }

    final scope = CyberImeOverlayScope.maybeOf(context);
    if (scope != null) {
      final anchor = _popupAnchorInStack(scope);
      if (anchor == null) {
        _popupActive = false;
        return;
      }
      // Popup lives in the IME overlay Stack (above the keyboard panel).
      _scopedPopup = scope.popup;
      _scopedPopup!.value = CyberImeAlternatePopupData(
        options: options,
        selectedIndex: _selectedIndex,
        anchor: anchor,
      );
      return;
    }

    // Test / standalone panel: fall back to a root Overlay entry.
    final overlay = Overlay.of(context, rootOverlay: true);
    _fallbackPopupEntry = OverlayEntry(
      builder: (ctx) {
        final keyBox = context.findRenderObject() as RenderBox?;
        if (keyBox == null || !keyBox.attached || !keyBox.hasSize) {
          return const SizedBox.shrink();
        }
        final overlayBox =
            Overlay.of(ctx).context.findRenderObject() as RenderBox?;
        if (overlayBox == null || !overlayBox.hasSize) {
          return const SizedBox.shrink();
        }
        final origin =
            keyBox.localToGlobal(Offset.zero, ancestor: overlayBox);
        return Positioned(
          left: origin.dx + keyBox.size.width / 2,
          top: origin.dy - kCyberImeAlternatePopupOffsetAboveKey,
          child: FractionalTranslation(
            translation: const Offset(-0.5, 0),
            child: IgnorePointer(
              child: CyberImeAlternatePopup(
                options: options,
                selectedIndex: _selectedIndex,
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_fallbackPopupEntry!);
  }

  void _updateSelection(double localX) {
    final options = widget.keyDef.popupOptions();
    if (!_popupActive || options.isEmpty || _keyWidth <= 0) return;
    final next = cyberImeSelectionIndexForX(
      x: localX,
      keyWidth: _keyWidth,
      optionCount: options.length,
    );
    if (next == _selectedIndex) return;
    _selectedIndex = next;
    final current = _scopedPopup?.value;
    if (current != null) {
      _scopedPopup!.value = current.copyWith(selectedIndex: _selectedIndex);
    } else {
      _fallbackPopupEntry?.markNeedsBuild();
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!_usesAlternateGestures) return;
    _activePointer = e.pointer;
    _longPressTimer?.cancel();
    final box = context.findRenderObject() as RenderBox?;
    _keyWidth = box?.size.width ?? 0;
    _longPressTimer = Timer(kLongPressTimeout, () {
      if (!mounted || _activePointer != e.pointer) return;
      CyberClickSoundRegistry.playClick();
      _showAlternatePopup();
      _updateSelection(e.localPosition.dx);
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_activePointer != e.pointer) return;
    if (_popupActive) {
      _updateSelection(e.localPosition.dx);
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_activePointer != e.pointer) return;
    _finishPointer(commitPopup: true);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (_activePointer != e.pointer) return;
    _finishPointer(commitPopup: false);
  }

  void _finishPointer({required bool commitPopup}) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _activePointer = null;
    if (_popupActive) {
      final options = widget.keyDef.popupOptions();
      if (commitPopup && options.isNotEmpty) {
        final i = _selectedIndex.clamp(0, options.length - 1);
        CyberClickSoundRegistry.playClick();
        widget.onPopupCommit?.call(options[i]);
      }
      _removePopup();
    } else if (commitPopup) {
      // Short tap — AbsorbPointer blocks CyberButton sound; play here.
      CyberClickSoundRegistry.playClick();
      widget.onTap();
    }
  }

  void _onShiftLongPress() {
    CyberClickSoundRegistry.playClick();
    widget.onShiftLongPress?.call();
  }

  Widget _buildButton({
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
  }) {
    final variant =
        _isPrimary ? CyberButtonVariant.primary : CyberButtonVariant.light;
    final accent = _accentLabel ||
        (widget.keyDef.id == CyberImeKeyId.shift && widget.shiftOn);

    return CyberButton(
      expand: true,
      variant: variant,
      onPressed: onPressed,
      onLongPress: onLongPress,
      foregroundColor: accent ? CyberColors.buttonPrimaryAccent : null,
      child: _KeyLabel(
        keyDef: widget.keyDef,
        shiftOn: widget.shiftOn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    late final Widget keyBody;

    if (_usesAlternateGestures) {
      keyBody = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: AbsorbPointer(
          child: _buildButton(onPressed: () {}),
        ),
      );
    } else if (widget.keyDef.id == CyberImeKeyId.shift) {
      keyBody = _buildButton(
        onPressed: widget.onTap,
        onLongPress: _onShiftLongPress,
      );
    } else {
      keyBody = _buildButton(onPressed: widget.onTap);
    }

    if (widget.keyDef.id != CyberImeKeyId.shift) {
      return keyBody;
    }

    const corner = CyberDimens.rectangleButtonCornerRadius;
    const dot = 8.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: keyBody),
        Positioned(
          right: corner - dot / 2,
          top: corner - dot / 2,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.capsLock
                  ? _kCapsLockDotActive
                  : CyberColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyLabel extends StatelessWidget {
  const _KeyLabel({required this.keyDef, required this.shiftOn});

  final CyberImeKeyDef keyDef;
  final bool shiftOn;

  @override
  Widget build(BuildContext context) {
    switch (keyDef.id) {
      case CyberImeKeyId.shift:
        return Icon(
          Icons.arrow_upward,
          size: 22,
          color: shiftOn ? CyberColors.buttonPrimaryAccent : null,
        );
      case CyberImeKeyId.backspace:
        return const Icon(Icons.backspace_outlined, size: 22);
      case CyberImeKeyId.enter:
        return const Icon(Icons.keyboard_return, size: 22);
      case CyberImeKeyId.space:
        return const Text('space', style: TextStyle(fontSize: 14));
      default:
        break;
    }

    final label = keyDef.isLetter
        ? (shiftOn ? keyDef.primary.toUpperCase() : keyDef.primary.toLowerCase())
        : keyDef.primary;

    // lws-ui showSecondaryHint: letters + comma/period dual key.
    final showSecondary = keyDef.secondary != null &&
        keyDef.secondary!.isNotEmpty &&
        (keyDef.isLetter || keyDef.id == CyberImeKeyId.commaPeriod);

    if (showSecondary) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            keyDef.secondary!,
            style: const TextStyle(
              color: CyberColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return Text(
      label,
      style: TextStyle(
        fontSize: label.length > 2 ? 13 : 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
