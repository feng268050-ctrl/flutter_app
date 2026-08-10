import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';

/// FrostNumericInputDialog parity: title → centered description → − / field / +.
///
/// Confirm via CyberIME Done (no Cancel/OK action bar). Scrim dismisses.
Future<String?> showCyberImeNumericInputDialog({
  required BuildContext context,
  required String title,
  required CyberImeFieldType fieldType,
  String initial = '',
  String? description,
  bool decimalStep = false,
  double decimalStepSize = 0.1,
  num minValue = 0,
  num maxValue = 100000,
  bool showStepper = true,
  CyberImeSession? session,
  String? Function(String raw)? validator,
}) async {
  final imeSession = session ?? CyberImeSession.shared;
  final backdropScope = CyberBlurBackdropScope.maybeOf(context);
  final formatted = CyberNumericInputLogic.formatDefaultInput(
    initial,
    decimalStep: decimalStep,
  );
  final ctrl = TextEditingController(text: formatted);
  final result = await CyberOverlayHost.show<String?>(
    context: context,
    sampleMode: CyberBlurSampleMode.realtime,
    freezePageBackdrop: false,
    barrierDismissible: true,
    keyboardHeight: imeSession.keyboardHeightListenable,
    keyboardMargin: imeSession.margin,
    constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
    builder: (ctx) {
      return _CyberImeNumericInputDialogBody(
        title: title,
        description: description,
        fieldType: fieldType,
        controller: ctrl,
        session: imeSession,
        backdropScope: backdropScope,
        decimalStep: decimalStep,
        decimalStepSize: decimalStepSize,
        minValue: minValue,
        maxValue: maxValue,
        showStepper: showStepper,
        validator: validator,
      );
    },
  );
  ctrl.dispose();
  return result;
}

/// Step / format helpers aligned with lws-ui [FrostNumericStepperLogic].
abstract final class CyberNumericInputLogic {
  static const metricDecimalStep = 0.1;

  static double parseInputNumber(String? input) {
    final trimmed = input?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 0;
    }
    return double.tryParse(trimmed) ?? 0;
  }

  static double clampNumeric(double value, num minValue, num maxValue) {
    return value.clamp(minValue.toDouble(), maxValue.toDouble()).toDouble();
  }

  static String formatNumericResult(
    double value, {
    required bool decimalStep,
    required double decimalStepSize,
  }) {
    if (!decimalStep) {
      return value.round().toString();
    }
    final scale = _scaleOf(decimalStepSize);
    final fixed = value.toStringAsFixed(scale);
    if (!fixed.contains('.')) {
      return fixed;
    }
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String applyStep({
    required String currentInput,
    required bool increment,
    required bool decimalStep,
    required double decimalStepSize,
    required num minValue,
    required num maxValue,
  }) {
    final current = parseInputNumber(currentInput);
    final delta = decimalStep ? decimalStepSize : 1.0;
    final next = clampNumeric(
      increment ? current + delta : current - delta,
      minValue,
      maxValue,
    );
    return formatNumericResult(
      next,
      decimalStep: decimalStep,
      decimalStepSize: decimalStepSize,
    );
  }

  static String formatDefaultInput(
    String? defaultInput, {
    required bool decimalStep,
  }) {
    if (defaultInput == null || defaultInput.isEmpty) {
      return '';
    }
    final value = double.tryParse(defaultInput.trim());
    if (value == null) {
      return defaultInput;
    }
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return formatNumericResult(
      value,
      decimalStep: decimalStep,
      decimalStepSize: metricDecimalStep,
    );
  }

  static int _scaleOf(double step) {
    if (step >= 1) {
      return 0;
    }
    var scale = 0;
    var t = step;
    while (scale < 6 && (t - t.roundToDouble()).abs() > 1e-9) {
      t *= 10;
      scale++;
    }
    return scale;
  }
}

class _CyberImeNumericInputDialogBody extends StatefulWidget {
  const _CyberImeNumericInputDialogBody({
    required this.title,
    required this.fieldType,
    required this.controller,
    required this.session,
    required this.decimalStep,
    required this.decimalStepSize,
    required this.minValue,
    required this.maxValue,
    required this.showStepper,
    this.description,
    this.backdropScope,
    this.validator,
  });

  final String title;
  final String? description;
  final CyberImeFieldType fieldType;
  final TextEditingController controller;
  final CyberImeSession session;
  final CyberBlurBackdropScopeState? backdropScope;
  final bool decimalStep;
  final double decimalStepSize;
  final num minValue;
  final num maxValue;
  final bool showStepper;
  final String? Function(String raw)? validator;

  @override
  State<_CyberImeNumericInputDialogBody> createState() =>
      _CyberImeNumericInputDialogBodyState();
}

class _CyberImeNumericInputDialogBodyState
    extends State<_CyberImeNumericInputDialogBody> {
  String? _error;

  void _bump(bool increment) {
    final next = CyberNumericInputLogic.applyStep(
      currentInput: widget.controller.text,
      increment: increment,
      decimalStep: widget.decimalStep,
      decimalStepSize: widget.decimalStepSize,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
    );
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    if (_error != null) {
      setState(() => _error = null);
    } else {
      setState(() {});
    }
  }

  bool _trySubmit() {
    final raw = widget.controller.text.trim();
    final error = widget.validator?.call(raw);
    if (error != null) {
      setState(() => _error = error);
      return false;
    }
    Navigator.pop(context, raw);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final description = widget.description;
    final typography = context.hmiTypography;
    final titleSize =
        typography.numericDialogTitle.fontSize ??
        HmiTypography.numericDialogTitleSize;
    final titleStyle = typography.numericDialogTitle.copyWith(
      color: CyberColors.textPrimary,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: 0.02 * titleSize,
      decoration: TextDecoration.none,
    );
    final descriptionStyle = typography.numericDialogDescription.copyWith(
      color: CyberColors.textSecondary,
      height: 1.25,
      fontWeight: FontWeight.w400,
      decoration: TextDecoration.none,
    );
    // WordBoundaryLabel: wrap only on whitespace (lws-ui / tip-dialog parity).
    // Plain Text + CyberPromptContent title ellipsis can cut mid-word on EN.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WordBoundaryLabel(
          text: widget.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: titleStyle,
        ),
        const SizedBox(height: CyberDimens.contentPadding),
        const CyberFrostDivider(),
        const SizedBox(height: CyberDimens.contentPadding),
        if (description != null && description.isNotEmpty) ...[
          WordBoundaryLabel(
            text: description,
            textAlign: TextAlign.center,
            maxLines: 5,
            style: descriptionStyle,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.showStepper)
              _StepButton(
                label: '−',
                onPressed: () => _bump(false),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 360,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(
                      CyberDimens.rectangleButtonCornerRadius,
                    ),
                    border: Border.all(
                      color: const Color(0x80FFFFFF),
                      width: 1,
                    ),
                  ),
                  child: CyberImeTextField(
                    fieldType: widget.fieldType,
                    controller: widget.controller,
                    autofocus: true,
                    session: widget.session,
                    backdropScope: widget.backdropScope,
                    textAlign: TextAlign.center,
                    style: typography.numericInputValue.copyWith(
                      color: CyberColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      errorText: _error,
                      errorStyle: typography.caption.copyWith(
                        color: CyberColors.buttonSecondaryText,
                      ),
                    ),
                    onAction: _trySubmit,
                  ),
                ),
              ),
            ),
            if (widget.showStepper)
              _StepButton(
                label: '+',
                onPressed: () => _bump(true),
              ),
          ],
        ),
      ],
    );
  }
}

/// Material step chrome sized to lws-ui frost stepper (72×72, 41sp glyph).
final class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: FilledButton(
        onPressed: () {
          CyberClickSoundRegistry.playClick();
          onPressed();
        },
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xE518181A),
          foregroundColor: CyberColors.textPrimary,
          disabledBackgroundColor: const Color(0x8018181A),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              CyberDimens.rectangleButtonCornerRadius,
            ),
            side: const BorderSide(color: CyberColors.buttonRim),
          ),
        ),
        child: Text(
          label,
          style: context.hmiTypography.numericStepperGlyph.copyWith(
            color: CyberColors.textPrimary,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ),
    );
  }
}
