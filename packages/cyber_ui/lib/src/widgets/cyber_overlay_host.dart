import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cyber_ui/src/blur/cyber_backdrop_blur_controller.dart';
import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_sample_mode.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';
import 'package:cyber_ui/src/theme/cyber_panel_border.dart';
import 'package:cyber_ui/src/theme/cyber_tone.dart';
import 'package:cyber_ui/src/widgets/cyber_dialog.dart';
import 'package:cyber_ui/src/widgets/cyber_keyboard_avoiding_lift.dart';
import 'package:cyber_ui/src/widgets/cyber_keyboard_insets.dart';
import 'package:cyber_ui/src/widgets/cyber_lifted_panel.dart';

/// Overlay host for Cyber dialogs (lws-ui `FrostOverlayHost` stand-in).
///
/// Panel chrome matches [CyberCard]: **border only** around [CyberModal] blur.
/// An opaque fill behind the blur would make BackdropFilter sample the fill
/// instead of the page (no visible Gaussian frost).
///
/// **Barrier:** default is [Colors.transparent]. A dark [barrierColor] sits
/// under the panel in the dialog route, so realtime [BackdropFilter] would
/// blur the scrim instead of Home — killing background透视. Dim the page
/// via a punched-hole scrim later if needed; do not put a full-screen opaque
/// barrier under frosted panels.
///
/// When [freezePageBackdrop] is true and a [CyberBackdropBlurController] is
/// provided, bumps generation so onChange consumers can freeze/re-sample.
abstract final class CyberOverlayHost {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    CyberBlurSampleMode sampleMode = CyberBlurSampleMode.firstFrame,
    CyberBlurIntensity intensity = CyberBlurIntensity.high,
    CyberBlurTint blurTint = CyberBlurTint.dark,
    CyberTone tone = CyberTone.dark,
    bool useFakeGlass = false,
    bool barrierDismissible = true,
    /// Full-screen color behind the panel. Prefer transparent for realtime frost.
    Color barrierColor = Colors.transparent,
    bool freezePageBackdrop = true,
    CyberBackdropBlurController? pageBackdropController,
    /// Keyboard panel height. When non-null, card is recentered / pinned in the
    /// remaining viewport (not blindly translated by full keyboard height).
    ValueListenable<double>? keyboardHeight,
    double keyboardMargin = CyberKeyboardInsets.defaultMargin,
    /// Raw upward translation (legacy). Prefer [keyboardHeight].
    ValueListenable<double>? liftExtent,
  }) {
    if (freezePageBackdrop) {
      pageBackdropController?.requestSample();
    }
    final panel = CyberPanelBorder(tone: tone);
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: (dialogContext) {
        Widget chrome = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: ClipRRect(
            borderRadius: panel.borderRadius,
            child: DecoratedBox(
              // Border only — fill would occlude backdrop sampling.
              decoration: BoxDecoration(
                borderRadius: panel.borderRadius,
                border: Border.all(
                  color: panel.flatBorderColor,
                  width: panel.width,
                ),
              ),
              child: CyberModal(
                sampleMode: sampleMode,
                intensity: intensity,
                blurTint: blurTint,
                useFakeGlass: useFakeGlass,
                borderRadius: panel.borderRadius,
                padding: const EdgeInsets.all(CyberDimens.contentPadding),
                child: builder(dialogContext),
              ),
            ),
          ),
        );
        if (keyboardHeight != null) {
          chrome = CyberKeyboardAvoidingLift(
            keyboardHeight: keyboardHeight,
            margin: keyboardMargin,
            child: chrome,
          );
        } else if (liftExtent != null) {
          chrome = CyberLiftedPanel(liftExtent: liftExtent, child: chrome);
        }
        // showDialog builder is not wrapped in [Dialog]/[Material] — without
        // this, titles/body Text get the yellow double-underline fallback style.
        return Material(
          type: MaterialType.transparency,
          child: Center(child: chrome),
        );
      },
    ).whenComplete(() {
      if (freezePageBackdrop) {
        pageBackdropController?.requestSample();
      }
    });
  }
}

/// Simple title + actions prompt content for [CyberOverlayHost].
class CyberPromptContent extends StatelessWidget {
  const CyberPromptContent({
    super.key,
    required this.title,
    this.body,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: CyberColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 16),
          DefaultTextStyle(
            style: const TextStyle(color: CyberColors.textSecondary, fontSize: 16),
            child: body!,
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                actions[i],
              ],
            ],
          ),
        ],
      ],
    );
  }
}
