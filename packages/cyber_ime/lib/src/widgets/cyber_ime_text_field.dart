import 'package:cyber_ime/src/field/cyber_ime_field_type.dart';
import 'package:cyber_ime/src/overlay/cyber_ime_overlay.dart';
import 'package:cyber_ime/src/session/cyber_ime_action.dart';
import 'package:cyber_ime/src/session/cyber_ime_session.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text field that suppresses the system soft keyboard and opens CyberIME.
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
  }

  void _hideIme({bool notify = true}) {
    final handle = _handle;
    _handle = null;
    handle?.hide(notify: notify);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _hideIme(notify: false);
    if (_ownedFocus) _focus.dispose();
    super.dispose();
  }

  void _toggleObscure() {
    CyberClickSoundRegistry.playClick();
    setState(() => _obscure = !_obscure);
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _showIme();
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
    _imeInteracting = true;
    if (!_focus.hasFocus) {
      _focus.requestFocus();
    }
    _handle?.bringToFront();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _imeInteracting = false;
    });
  }

  void _onImeHidden() {
    if (!mounted) {
      _handle = null;
      return;
    }
    setState(() => _handle = null);
  }

  void _showIme() {
    if (_handle != null && !_handle!.isClosed) return;
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    _handle = CyberImeOverlay.show(
      context: context,
      fieldType: widget.fieldType,
      controller: widget.controller,
      session: widget.session,
      action: widget.action,
      onKeyActivity: _onKeyActivity,
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

    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      readOnly: true,
      showCursor: true,
      enableInteractiveSelection: true,
      obscureText: _obscure,
      autofocus: widget.autofocus,
      decoration: decoration,
      style: widget.style,
      onTap: () {
        if (!_focus.hasFocus) {
          _focus.requestFocus();
        } else {
          // Focus kept after scrim dismiss — reopen IME on field tap.
          _showIme();
        }
      },
    );
  }
}
