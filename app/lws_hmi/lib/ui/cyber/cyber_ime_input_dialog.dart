import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

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
  String? confirmLabel,
  CyberImeSession? session,

  /// When true, Enter / confirm do nothing if the field is empty (lws-ui Wi‑Fi).
  bool requireNonEmpty = false,
  String? emptyErrorText,
}) async {
  final l10n = AppLocalizations.of(context);
  final imeSession = session ?? CyberImeSession.shared;
  final backdropScope = CyberBlurBackdropScope.maybeOf(context);
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
        confirmLabel: confirmLabel ?? l10n?.okText ?? 'OK',
        session: imeSession,
        backdropScope: backdropScope,
        requireNonEmpty: requireNonEmpty,
        emptyErrorText: emptyErrorText ?? l10n?.requiredFieldText ?? 'Required',
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
    this.backdropScope,
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
  final CyberBlurBackdropScopeState? backdropScope;

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
            backdropScope: widget.backdropScope,
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
            style:
                context.hmiTypography.body.copyWith(color: CyberColors.textPrimary),
            onAction: _trySubmit,
          ),
        ],
      ),
      actions: [
        HmiButton(
          label: AppLocalizations.of(context)!.cancelText,
          size: HmiButtonSize.medium,
          widthPolicy: HmiButtonWidthPolicy.equal,
          width: 196,
          variant: CyberButtonVariant.secondary,
          shape: CyberButtonShape.rounded,
          onPressed: () => Navigator.pop(context),
        ),
        HmiButton(
          label: widget.confirmLabel,
          size: HmiButtonSize.medium,
          widthPolicy: HmiButtonWidthPolicy.equal,
          width: 196,
          variant: CyberButtonVariant.primary,
          shape: CyberButtonShape.rounded,
          onPressed: _trySubmit,
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
  String? confirmLabel,
  CyberImeSession? session,
}) async {
  final l10n = AppLocalizations.of(context);
  final resolvedConfirm = confirmLabel ?? l10n?.httpProxySave ?? 'Save';
  final imeSession = session ?? CyberImeSession.shared;
  final backdropScope = CyberBlurBackdropScope.maybeOf(context);
  final ok = await CyberOverlayHost.show<bool>(
    context: context,
    sampleMode: CyberBlurSampleMode.realtime,
    freezePageBackdrop: false,
    barrierDismissible: false,
    keyboardHeight: imeSession.keyboardHeightListenable,
    keyboardMargin: imeSession.margin,
    builder: (ctx) {
      return CyberImeBackdropScope(
        backdropScope: backdropScope,
        child: CyberPromptContent(
          title: title,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields,
          ),
          actions: [
            HmiButton(
              label: AppLocalizations.of(ctx)?.cancelText ?? 'Cancel',
              size: HmiButtonSize.medium,
              widthPolicy: HmiButtonWidthPolicy.equal,
              width: 196,
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            HmiButton(
              label: resolvedConfirm,
              size: HmiButtonSize.medium,
              widthPolicy: HmiButtonWidthPolicy.equal,
              width: 196,
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
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
