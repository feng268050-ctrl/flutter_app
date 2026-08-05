import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cyber_ui/src/blur/cyber_backdrop_blur.dart';
import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_sample_mode.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';
import 'package:cyber_ui/src/theme/cyber_glass_theme.dart';
import 'package:cyber_ui/src/widgets/cyber_keyboard_avoiding_lift.dart';
import 'package:cyber_ui/src/widgets/cyber_keyboard_insets.dart';
import 'package:cyber_ui/src/widgets/cyber_lifted_panel.dart';

/// Modal chrome with optional glass; full lws-ui capture-policy deferred.
class CyberModal extends StatelessWidget {
  const CyberModal({
    super.key,
    required this.child,
    this.sampleMode = CyberBlurSampleMode.realtime,
    this.intensity = CyberBlurIntensity.high,
    this.blurTint = CyberBlurTint.dark,
    this.useFakeGlass = false,
    this.borderRadius,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final CyberBlurSampleMode sampleMode;
  final CyberBlurIntensity intensity;
  final CyberBlurTint blurTint;

  /// When true (or when no backdrop scope), use translucent panel without blur.
  final bool useFakeGlass;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = CyberGlassTheme.of(context);
    final radius =
        borderRadius ?? BorderRadius.circular(theme.cornerRadius);

    final content = Padding(padding: padding, child: child);

    if (useFakeGlass) {
      // Opaque fills — no live page透视. Warm ≈ toast cream; dark ≈ error charcoal.
      final fill = blurTint == CyberBlurTint.warm
          ? const Color(0xF5FFFCFA)
          : const Color(0xFF1A1A1E);
      return ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: fill,
          child: content,
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: CyberBackdropBlur(
        sampleMode: sampleMode,
        intensity: intensity,
        blurTint: blurTint,
        child: content,
      ),
    );
  }
}

/// Shows a dialog wrapped in [CyberModal].
///
/// Defaults match Startup Self-Check / [CyberOverlayHost]: transparent barrier
/// and realtime wallpaper frost (no black54 scrim under the panel).
Future<T?> showCyberDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  CyberBlurSampleMode sampleMode = CyberBlurSampleMode.realtime,
  CyberBlurIntensity intensity = CyberBlurIntensity.high,
  CyberBlurTint blurTint = CyberBlurTint.dark,
  bool useFakeGlass = false,
  bool barrierDismissible = true,
  Color barrierColor = Colors.transparent,
  ValueListenable<double>? keyboardHeight,
  double keyboardMargin = CyberKeyboardInsets.defaultMargin,
  ValueListenable<double>? liftExtent,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    builder: (dialogContext) {
      Widget modal = CyberModal(
        sampleMode: sampleMode,
        intensity: intensity,
        blurTint: blurTint,
        useFakeGlass: useFakeGlass,
        child: builder(dialogContext),
      );
      if (keyboardHeight != null) {
        modal = CyberKeyboardAvoidingLift(
          keyboardHeight: keyboardHeight,
          margin: keyboardMargin,
          child: modal,
        );
      } else if (liftExtent != null) {
        modal = CyberLiftedPanel(liftExtent: liftExtent, child: modal);
      }
      return Material(
        type: MaterialType.transparency,
        child: Center(child: modal),
      );
    },
  );
}
