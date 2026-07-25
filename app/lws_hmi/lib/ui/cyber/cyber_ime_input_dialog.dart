import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Shows a Cyber frosted input dialog with CyberIME (system IME suppressed).
///
/// Uses [CyberBlurSampleMode.realtime] while open so glass tracks card lift.
Future<String?> showCyberImeInputDialog({
  required BuildContext context,
  required String title,
  required CyberImeFieldType fieldType,
  String initial = '',
  String? hint,
  String? label,
  bool obscureText = false,
  String confirmLabel = 'OK',
  CyberImeSession? session,
  /// When true, Enter / confirm do nothing if the field is empty (lws-ui Wi‑Fi).
  bool requireNonEmpty = false,
  String emptyErrorText = 'Required',
}) async {
  final imeSession = session ?? CyberImeSession.shared;
  final ctrl = TextEditingController(text: initial);
  final result = await CyberOverlayHost.show<String?>(
    context: context,
    sampleMode: CyberBlurSampleMode.realtime,
    freezePageBackdrop: false,
    barrierDismissible: false,
    keyboardHeight: imeSession.keyboardHeightListenable,
    keyboardMargin: imeSession.margin,
    builder: (ctx) {
      return _CyberImeInputDialogBody(
        title: title,
        fieldType: fieldType,
        controller: ctrl,
        obscureText: obscureText,
        label: label,
        hint: hint,
        confirmLabel: confirmLabel,
        session: imeSession,
        requireNonEmpty: requireNonEmpty,
        emptyErrorText: emptyErrorText,
      );
    },
  );
  ctrl.dispose();
  return result;
}

class _CyberImeInputDialogBody extends StatefulWidget {
  const _CyberImeInputDialogBody({
    required this.title,
    required this.fieldType,
    required this.controller,
    required this.obscureText,
    required this.confirmLabel,
    required this.session,
    required this.requireNonEmpty,
    required this.emptyErrorText,
    this.label,
    this.hint,
  });

  final String title;
  final CyberImeFieldType fieldType;
  final TextEditingController controller;
  final bool obscureText;
  final String? label;
  final String? hint;
  final String confirmLabel;
  final CyberImeSession session;
  final bool requireNonEmpty;
  final String emptyErrorText;

  @override
  State<_CyberImeInputDialogBody> createState() =>
      _CyberImeInputDialogBodyState();
}

class _CyberImeInputDialogBodyState extends State<_CyberImeInputDialogBody> {
  String? _error;

  bool _trySubmit() {
    if (widget.requireNonEmpty && widget.controller.text.trim().isEmpty) {
      setState(() => _error = widget.emptyErrorText);
      return false;
    }
    Navigator.pop(context, widget.controller.text);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return CyberPromptContent(
      title: widget.title,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CyberImeTextField(
            fieldType: widget.fieldType,
            controller: widget.controller,
            obscureText: widget.obscureText,
            autofocus: true,
            session: widget.session,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              errorText: _error,
              labelStyle: const TextStyle(color: CyberColors.textSecondary),
              hintStyle: const TextStyle(color: CyberColors.textSecondary),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: CyberColors.textSecondary),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: CyberColors.textPrimary),
              ),
            ),
            style: const TextStyle(color: CyberColors.textPrimary, fontSize: 18),
            onAction: _trySubmit,
          ),
        ],
      ),
      actions: [
        CyberButton(
          variant: CyberButtonVariant.secondary,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CyberButton(
          variant: CyberButtonVariant.primary,
          onPressed: _trySubmit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Multi-field CyberIME dialog (e.g. Manual IP). Returns true when saved.
Future<bool> showCyberImeFormDialog({
  required BuildContext context,
  required String title,
  required List<Widget> fields,
  String confirmLabel = 'Save',
  CyberImeSession? session,
}) async {
  final imeSession = session ?? CyberImeSession.shared;
  final ok = await CyberOverlayHost.show<bool>(
    context: context,
    sampleMode: CyberBlurSampleMode.realtime,
    freezePageBackdrop: false,
    barrierDismissible: false,
    keyboardHeight: imeSession.keyboardHeightListenable,
    keyboardMargin: imeSession.margin,
    builder: (ctx) {
      return CyberPromptContent(
        title: title,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: fields,
        ),
        actions: [
          CyberButton(
            variant: CyberButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CyberButton(
            variant: CyberButtonVariant.primary,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return ok == true;
}

/// Non-dismissible “Connecting…” (or similar) progress card while [work] runs.
Future<T> showCyberBusyDialog<T>({
  required BuildContext context,
  required String title,
  required Future<T> Function() work,
}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  // Push without awaiting dismiss — completes when we pop in finally.
  final dialogFuture = CyberOverlayHost.show<void>(
    context: context,
    barrierDismissible: false,
    freezePageBackdrop: false,
    sampleMode: CyberBlurSampleMode.realtime,
    builder: (ctx) {
      return CyberPromptContent(
        title: title,
        body: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: CyberColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    },
  );
  // Let the route mount before blocking work.
  await Future<void>.delayed(Duration.zero);
  try {
    return await work();
  } finally {
    if (nav.canPop()) {
      nav.pop();
    }
    await dialogFuture;
  }
}
