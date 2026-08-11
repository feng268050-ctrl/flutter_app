import 'dart:async';

import 'package:cyber_ime/src/field/cyber_ime_field_type.dart';
import 'package:cyber_ime/src/input/cyber_ime_physical_key_repeat.dart';
import 'package:cyber_ime/src/input/cyber_ime_physical_keyboard.dart';
import 'package:cyber_ime/src/overlay/cyber_ime_overlay.dart';
import 'package:cyber_ime/src/session/cyber_ime_action.dart';
import 'package:cyber_ime/src/session/cyber_ime_session.dart';
import 'package:cyber_ime/src/widgets/cyber_ime_trackpad_caret.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Carries the initiating page's blur scope across a dialog route.
class CyberImeBackdropScope extends InheritedWidget {
  const CyberImeBackdropScope({
    super.key,
    required this.backdropScope,
    required super.child,
  });

  final CyberBlurBackdropScopeState? backdropScope;

  static CyberBlurBackdropScopeState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CyberImeBackdropScope>()
      ?.backdropScope;

  @override
  bool updateShouldNotify(CyberImeBackdropScope oldWidget) =>
      backdropScope != oldWidget.backdropScope;
}

/// Text field that suppresses the system soft keyboard and opens CyberIME.
///
/// Editable (not [TextField.readOnly]) so physical USB/BT keys from
/// hardware / XKB still insert. Soft system IME is suppressed via
/// [SystemChannels.textInput] hide — do not use `readOnly: true` for that.
///
/// Soft CyberIME is skipped when [CyberImePhysicalKeyboard] reports present
/// (App wires HAL `Keyboard.isPresent`). Physical key-hold repeat is synthesized
/// by [CyberImePhysicalKeyRepeat] because flutter-elinux ignores Wayland
/// `repeat_info` (printable keys, Backspace, Delete, and arrows).
class CyberImeTextField extends StatefulWidget {
  const CyberImeTextField({
    super.key,
    required this.fieldType,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.obscureText = false,
    this.showVisibilityToggle,
    this.autofocus = false,
    this.session,
    this.action = CyberImeAction.done,
    this.onAction,
    this.style,
    this.textAlign = TextAlign.start,
    this.backdropScope,
  });

  final CyberImeFieldType fieldType;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final bool obscureText;

  /// Show eye icon to toggle obscure. Defaults to true when [obscureText] is true.
  final bool? showVisibilityToggle;
  final bool autofocus;
  final CyberImeSession? session;
  final CyberImeAction action;
  final VoidCallback? onAction;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Page scope to sample when this field is hosted by a dialog route.
  final CyberBlurBackdropScopeState? backdropScope;

  @override
  State<CyberImeTextField> createState() => _CyberImeTextFieldState();
}

class _CyberImeTextFieldState extends State<CyberImeTextField> {
  late FocusNode _focus;
  bool _ownedFocus = false;
  CyberImeOverlayHandle? _handle;
  bool _obscure = false;
  bool _imeInteracting = false;
  late final bool _revealSupported;
  int _showGeneration = 0;

  /// Sticky for this focus session after HAL says present or a HW key arrives.
  bool _preferPhysical = false;
  bool _hwHideScheduled = false;

  /// Soft Space Cursor Trackpad Mode: pause blink, force solid caret chrome.
  bool _spaceTrackpadActive = false;

  final _keyRepeat = CyberImePhysicalKeyRepeat();

  /// Eye toggle must not steal focus — that would dismiss CyberIME mid-entry.
  final FocusNode _revealFocus = FocusNode(
    debugLabel: 'CyberImePasswordReveal',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _revealSupported = widget.showVisibilityToggle ?? widget.obscureText;
    if (widget.focusNode != null) {
      _focus = widget.focusNode!;
    } else {
      _focus = FocusNode(debugLabel: 'CyberImeTextField');
      _ownedFocus = true;
    }
    _focus.addListener(_onFocusChange);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _keyRepeat.attach(focusNode: _focus, controller: widget.controller);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CyberImeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText &&
        widget.obscureText != _obscure &&
        !_revealSupported) {
      _obscure = widget.obscureText;
    }
    if (oldWidget.controller != widget.controller) {
      _keyRepeat.attach(focusNode: _focus, controller: widget.controller);
    }
  }

  void _hideIme({bool notify = true}) {
    final handle = _handle;
    _handle = null;
    handle?.hide(notify: notify);
  }

  @override
  void dispose() {
    _keyRepeat.detach();
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _focus.removeListener(_onFocusChange);
    _hideIme(notify: false);
    _revealFocus.dispose();
    if (_ownedFocus) _focus.dispose();
    super.dispose();
  }

  /// Soft-IME hide only. Never consume keys; never [setState] here.
  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    if (!_focus.hasFocus) {
      return false;
    }
    _preferPhysical = true;
    if (_handle == null || _handle!.isClosed || _hwHideScheduled) {
      return false;
    }
    _hwHideScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hwHideScheduled = false;
      if (!mounted || !_preferPhysical) {
        return;
      }
      _hideIme();
    });
    return false;
  }

  void _toggleObscure() {
    CyberClickSoundRegistry.playClick();
    setState(() => _obscure = !_obscure);
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _preferPhysical = false;
      unawaited(_showImeIfNeeded());
      return;
    }
    if (_imeInteracting) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focus.hasFocus && !_imeInteracting) {
        _hideIme();
      }
    });
  }

  void _onKeyActivity() {
    // Keep focus across soft-key presses. Do NOT reinsert the OverlayEntry
    // here — remove+insert mid-pointer cancels CyberImeKeyCap gestures on
    // flutter-elinux and can stall further commits after a couple of taps.
    _imeInteracting = true;
    if (!_focus.hasFocus) {
      _focus.requestFocus();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _imeInteracting = false;
    });
  }

  void _onImeHidden() {
    if (!mounted) {
      _handle = null;
      _spaceTrackpadActive = false;
      return;
    }
    setState(() {
      _handle = null;
      _spaceTrackpadActive = false;
    });
  }

  void _onSpaceTrackpadStart() {
    _onKeyActivity();
    if (!mounted) {
      return;
    }
    setState(() => _spaceTrackpadActive = true);
  }

  void _onSpaceTrackpadCursorMove(int _) {
    _onKeyActivity();
    // Selection already updated by commit; caret host listens to controller.
  }

  void _onSpaceTrackpadEnd() {
    _onKeyActivity();
    if (!mounted) {
      _spaceTrackpadActive = false;
      return;
    }
    setState(() => _spaceTrackpadActive = false);
  }

  Future<void> _showImeIfNeeded() async {
    final gen = ++_showGeneration;
    final physical =
        _preferPhysical || await CyberImePhysicalKeyboard.isPresent();
    if (!mounted || gen != _showGeneration || !_focus.hasFocus) {
      return;
    }
    if (physical) {
      _preferPhysical = true;
      _hideIme();
      // Keep TextInput client alive for embedders that route chars through it.
      return;
    }
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    _showIme();
  }

  void _showIme() {
    if (_preferPhysical) {
      return;
    }
    if (_handle != null && !_handle!.isClosed) return;
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    _handle = CyberImeOverlay.show(
      context: context,
      backdropScope: widget.backdropScope ??
          CyberImeBackdropScope.maybeOf(context) ??
          CyberBlurBackdropScope.maybeOf(context),
      fieldType: widget.fieldType,
      controller: widget.controller,
      session: widget.session,
      action: widget.action,
      onKeyActivity: _onKeyActivity,
      onSpaceTrackpadStart: _onSpaceTrackpadStart,
      onSpaceTrackpadCursorMove: _onSpaceTrackpadCursorMove,
      onSpaceTrackpadEnd: _onSpaceTrackpadEnd,
      onHidden: _onImeHidden,
      onAction: () {
        widget.onAction?.call();
      },
      onPasswordReveal: _revealSupported ? _toggleObscure : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.decoration ?? const InputDecoration();
    final decoration = base.copyWith(
      suffixIcon: _revealSupported
          ? IconButton(
              focusNode: _revealFocus,
              onPressed: _toggleObscure,
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: CyberColors.textSecondary,
              ),
            )
          : base.suffixIcon,
    );

    return CyberImeTrackpadCaretHost(
      active: _spaceTrackpadActive,
      controller: widget.controller,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        // Must stay editable: readOnly also blocks hardware / XKB hardware keys.
        readOnly: false,
        // Avoid connecting a system soft-IME client that can fight CyberIME
        // commits on flutter-elinux (composing / selection resets).
        keyboardType: TextInputType.none,
        // During Space trackpad, suppress framework blink; solid caret is
        // painted by [CyberImeTrackpadCaretHost] and tracks selection live.
        showCursor: !_spaceTrackpadActive,
        // Soft keys drive the caret via [CyberImeControllerCommit]. Interactive
        // selection lets obscureText/elinux spuriously select-all between taps.
        enableInteractiveSelection: false,
        obscureText: _obscure,
        autofocus: widget.autofocus,
        decoration: decoration,
        style: widget.style,
        textAlign: widget.textAlign,
        onTap: () {
          if (_preferPhysical) {
            // Physical typing — do not TextInput.hide (keeps client / caret path).
          } else {
            SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
          }
          if (!_focus.hasFocus) {
            _focus.requestFocus();
          } else {
            unawaited(_showImeIfNeeded());
          }
        },
      ),
    );
  }
}
