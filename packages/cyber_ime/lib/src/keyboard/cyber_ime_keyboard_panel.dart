import 'dart:async';

import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_alternate_popup.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_gestures.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_map.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_popup.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_keyboard_controller.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_keyboard_rows.dart';
import 'package:cyber_ime/src/overlay/cyber_ime_overlay_scope.dart';
import 'package:cyber_ime/src/session/cyber_ime_jp_input_mode.dart';
import 'package:cyber_ime/src/session/cyber_ime_regional_layout.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Default panel height used for lift (logical pixels).
/// Soft Keyboard A is 4 rows.
const double kCyberImePanelHeight = 300;

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
            child: Padding(
              padding: const EdgeInsets.all(CyberImeKeyboardRows.keyGap),
              child: CyberImeKeyboardRows(
                layout: layout,
                keyFace: (key) => CyberImeKeyCap(
                  keyDef: key,
                  kind: layout.kind,
                  shiftOn: controller.shiftActive,
                  capsLock: controller.capsLock,
                  altGrOn: controller.altGrOn,
                  jpInputMode: controller.jpInputMode,
                  onTap: () => controller.onKeyTap(key),
                  onShiftLongPress: key.id == CyberImeKeyId.shift
                      ? controller.onShiftLongPress
                      : null,
                  onPopupCommit: controller.commitPopupText,
                ),
              ),
            ),
          ),
        );
      },
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
    this.altGrOn = false,
    this.jpInputMode = CyberImeJpInputMode.english,
    required this.onTap,
    this.onShiftLongPress,
    this.onPopupCommit,
  });

  final CyberImeKeyDef keyDef;
  final CyberImeKeyboardKind kind;
  final bool shiftOn;
  final bool capsLock;
  final bool altGrOn;
  final CyberImeJpInputMode jpInputMode;
  final VoidCallback onTap;
  final VoidCallback? onShiftLongPress;
  final ValueChanged<String>? onPopupCommit;

  @override
  State<CyberImeKeyCap> createState() => _CyberImeKeyCapState();
}

class _CyberImeKeyCapState extends State<CyberImeKeyCap> {
  OverlayEntry? _fallbackPopupEntry;
  ValueNotifier<CyberImeAlternatePopupData?>? _scopedPopup;

  /// Drives [CyberButton] Frost ripple while parent owns the pointer
  /// (lws-ui `PressInteraction` emit for alternate long-press keys).
  final ValueNotifier<Offset?> _externalPress = ValueNotifier<Offset?>(null);
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
      widget.keyDef.id != CyberImeKeyId.altGr &&
      widget.keyDef.supportsAlternatePopup;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _externalPress.dispose();
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
    // Keycap top-center; vertical lift is applied after popup height is known.
    return Offset(origin.dx + keyBox.size.width / 2, origin.dy);
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
        final origin = keyBox.localToGlobal(Offset.zero, ancestor: overlayBox);
        return SizedBox.expand(
          child: CustomSingleChildLayout(
            delegate: CyberImeAlternatePopupPositionDelegate(
              preferredKeyTopCenter: Offset(
                origin.dx + keyBox.size.width / 2,
                origin.dy,
              ),
            ),
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
    // Hotspot for Frost LIGHT ripple (same as ImeKeyGestures PressInteraction).
    _externalPress.value = e.position;
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
    _externalPress.value = null;
    if (_popupActive) {
      final options = widget.keyDef.popupOptions();
      if (commitPopup && options.isNotEmpty) {
        final i = _selectedIndex.clamp(0, options.length - 1);
        CyberClickSoundRegistry.playClick();
        widget.onPopupCommit?.call(options[i]);
      }
      _removePopup();
    } else if (commitPopup) {
      // Short tap — parent owns gestures; play click like FrostButton.
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
    bool inkWellGestures = true,
    ValueNotifier<Offset?>? externalPress,
    bool clickSoundEnabled = true,
  }) {
    final variant =
        _isPrimary ? CyberButtonVariant.primary : CyberButtonVariant.light;
    final accent = _accentLabel ||
        (widget.keyDef.id == CyberImeKeyId.shift && widget.shiftOn) ||
        (widget.keyDef.id == CyberImeKeyId.altGr && widget.altGrOn) ||
        (widget.keyDef.id == CyberImeKeyId.kanaToggle &&
            widget.jpInputMode != CyberImeJpInputMode.english) ||
        (widget.keyDef.id == CyberImeKeyId.hankakuZenkaku &&
            widget.jpInputMode != CyberImeJpInputMode.english);

    return CyberButton(
      expand: true,
      variant: variant,
      onPressed: onPressed,
      onLongPress: onLongPress,
      inkWellGestures: inkWellGestures,
      externalPress: externalPress,
      clickSoundEnabled: clickSoundEnabled,
      foregroundColor: accent ? CyberColors.buttonPrimaryAccent : null,
      child: CyberImeKeyLabel(
        keyDef: widget.keyDef,
        shiftOn: widget.shiftOn,
        altGrOn: widget.altGrOn,
        jpInputMode: widget.jpInputMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    late final Widget keyBody;

    if (_usesAlternateGestures) {
      // Parent owns hit testing (long-press popup); CyberButton still shows
      // Frost LIGHT ripple via [externalPress] (lws-ui PressInteraction).
      keyBody = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: _buildButton(
          onPressed: () {},
          inkWellGestures: false,
          externalPress: _externalPress,
          clickSoundEnabled: false,
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

/// Shared keycap face used by the live panel and Settings preview.
///
/// Control keys (Shift / Backspace / Enter / Caps) use Material Icons; character
/// keys show the KeyMap primary plus an optional second-function secondary.
class CyberImeKeyLabel extends StatelessWidget {
  const CyberImeKeyLabel({
    super.key,
    required this.keyDef,
    required this.shiftOn,
    this.altGrOn = false,
    this.jpInputMode = CyberImeJpInputMode.english,
    this.profile,
  });

  final CyberImeKeyDef keyDef;
  final bool shiftOn;
  final bool altGrOn;
  final CyberImeJpInputMode jpInputMode;

  /// When set (e.g. Settings preview), KeyMap resolves against this profile
  /// instead of the live [CyberImeRegionalLayoutRegistry] selection.
  final CyberImeRegionalProfile? profile;

  CyberImeRegionalProfile get _mapProfile =>
      profile ?? CyberImeRegionalLayoutRegistry.provider.profile;

  @override
  Widget build(BuildContext context) {
    switch (keyDef.id) {
      case CyberImeKeyId.shift:
        return Icon(
          Icons.arrow_upward,
          size: 30,
          color: shiftOn ? CyberColors.buttonPrimaryAccent : null,
        );
      case CyberImeKeyId.altGr:
        return Text(
          'AltGr',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: altGrOn ? CyberColors.buttonPrimaryAccent : null,
          ),
        );
      case CyberImeKeyId.control:
        return const Text('Ctrl', style: TextStyle(fontSize: 20));
      case CyberImeKeyId.alt:
        return const Text('Alt', style: TextStyle(fontSize: 20));
      case CyberImeKeyId.capsLock:
        if (keyDef.primary.contains('英')) {
          return Text(
            '英数',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: shiftOn ? CyberColors.buttonPrimaryAccent : null,
            ),
          );
        }
        return Icon(
          Icons.keyboard_capslock,
          size: 28,
          color: shiftOn ? CyberColors.buttonPrimaryAccent : null,
        );
      case CyberImeKeyId.hankakuZenkaku:
        return const Text('半/全', style: TextStyle(fontSize: 19));
      case CyberImeKeyId.languageToggle:
        final jp = jpInputMode != CyberImeJpInputMode.english;
        return Text(
          jp ? 'ABC' : 'あ',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: jp ? CyberColors.buttonPrimaryAccent : null,
          ),
        );
      case CyberImeKeyId.muhenkan:
        return const Text('無変換', style: TextStyle(fontSize: 18));
      case CyberImeKeyId.henkan:
        return const Text('変換', style: TextStyle(fontSize: 19));
      case CyberImeKeyId.kanaToggle:
        final kanaLabel =
            jpInputMode == CyberImeJpInputMode.hiragana ? 'かな' : 'カナ';
        return Text(
          kanaLabel,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: jpInputMode != CyberImeJpInputMode.english
                ? CyberColors.buttonPrimaryAccent
                : null,
          ),
        );
      case CyberImeKeyId.tab:
        return const Text('Tab', style: TextStyle(fontSize: 20));
      case CyberImeKeyId.backspace:
        return const Icon(Icons.backspace_outlined, size: 30);
      case CyberImeKeyId.enter:
        return const Icon(Icons.keyboard_return, size: 30);
      case CyberImeKeyId.space:
        return const Text('space', style: TextStyle(fontSize: 22));
      default:
        break;
    }

    String label;
    String? faceSecondary;

    if (keyDef.keyCode != null) {
      final level = CyberImeKeyMaps.level(_mapProfile, keyDef.keyCode!);
      label = level.resolve(
        shiftOn: shiftOn,
        altGrOn: altGrOn,
        jpMode: jpInputMode,
      );
      faceSecondary = keyDef.secondary;
    } else if (keyDef.isLetter) {
      label =
          shiftOn ? keyDef.primary.toUpperCase() : keyDef.primary.toLowerCase();
      faceSecondary = keyDef.secondary ??
          _longPressSecondFunction(keyDef, uppercase: shiftOn);
    } else {
      label = keyDef.primary;
      faceSecondary = keyDef.secondary;
    }

    final showSecondary = !altGrOn &&
        faceSecondary != null &&
        faceSecondary.isNotEmpty &&
        // lws-ui `showSecondaryHint`: letters + comma/period only — custom
        // keys (e.g. quote → backtick) keep secondary for long-press popup.
        (keyDef.isLetter ||
            keyDef.id == CyberImeKeyId.commaPeriod ||
            keyDef.keyCode != null);

    if (!showSecondary) {
      final fontSize = label.length > 4
          ? 16.0
          : label.length > 2
              ? 21.0
              : kCyberImeKeyPrimaryTextSize;
      return Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      );
    }

    // lws-ui: secondary 14 + primary 28, lineHeight == fontSize, no gap →
    // content ≈ 42; FrostButton centers the column so each side ≈ 12.5 on a
    // ~67dp key face.
    final secondaryStyle = TextStyle(
      color: CyberColors.textSecondary,
      fontSize: kCyberImeKeySecondaryHintTextSize,
      fontWeight: FontWeight.w500,
      height: 1,
    );
    const primaryStyle = TextStyle(
      fontSize: kCyberImeKeyPrimaryTextSize,
      fontWeight: FontWeight.w600,
      height: 1,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          faceSecondary,
          textAlign: TextAlign.center,
          style: secondaryStyle,
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: primaryStyle,
        ),
      ],
    );
  }

  /// Exposes the first accented long-press option as the key's second
  /// function. The existing long-press popup still contains every candidate.
  String? _longPressSecondFunction(
    CyberImeKeyDef key, {
    required bool uppercase,
  }) {
    final options = key.longPressOptions;
    if (options == null || options.isEmpty) return null;

    final base =
        uppercase ? key.primary.toUpperCase() : key.primary.toLowerCase();
    String? fallback;
    for (final option in options) {
      final normalized =
          uppercase ? option.toUpperCase() : option.toLowerCase();
      if (normalized == base) continue;
      fallback ??= option;
      final matchesCase = uppercase
          ? option == option.toUpperCase()
          : option == option.toLowerCase();
      if (matchesCase) return option;
    }
    return fallback;
  }
}
