import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cyber_ui/src/blur/cyber_backdrop_blur_controller.dart';
import 'package:cyber_ui/src/blur/cyber_blur_intensity.dart';
import 'package:cyber_ui/src/blur/cyber_blur_sample_mode.dart';
import 'package:cyber_ui/src/blur/cyber_blur_tint.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';
import 'package:cyber_ui/src/theme/cyber_panel_border.dart';
import 'package:cyber_ui/src/theme/cyber_panel_outline.dart';
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
    /// Defaults match Startup Self-Check (realtime wallpaper frost).
    CyberBlurSampleMode sampleMode = CyberBlurSampleMode.realtime,
    CyberBlurIntensity intensity = CyberBlurIntensity.high,
    CyberBlurTint blurTint = CyberBlurTint.dark,
    CyberTone tone = CyberTone.dark,
    bool useFakeGlass = false,
    bool barrierDismissible = true,
    /// Full-screen color behind the panel. Prefer transparent for realtime frost.
    Color barrierColor = Colors.transparent,
    bool freezePageBackdrop = false,
    CyberBackdropBlurController? pageBackdropController,
    /// Override the default 720×640 panel cap (e.g. wide Important Reminder).
    BoxConstraints? constraints,
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
    final panelConstraints =
        constraints ?? const BoxConstraints(maxWidth: 720, maxHeight: 640);
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: (dialogContext) {
        // Orange rim painted above ClipRRect (Manual Gas / Feed / Retract style).
        Widget chrome = ConstrainedBox(
          constraints: panelConstraints,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              ClipRRect(
                borderRadius: panel.borderRadius,
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
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: CyberFrostPanelOutlinePainter(panel.tipRimOutline),
                  ),
                ),
              ),
            ],
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

/// Simple title + body + actions prompt content for tip / Cyber overlays.
///
/// Layout matches lws-ui `dialog_frost_prompt.xml`: title → divider → body →
/// divider → actions.
class CyberPromptContent extends StatelessWidget {
  const CyberPromptContent({
    super.key,
    required this.title,
    this.body,
    this.actions = const <Widget>[],
    this.tone = CyberTone.dark,
  });

  final String title;
  final Widget? body;
  final List<Widget> actions;

  /// [CyberTone.light] uses dark ink on cream success tips.
  final CyberTone tone;

  static const _titleDark = Color(0xFF1A1A1A);
  static const _bodyDark = Color(0xCC1A1A1A);

  /// Product tip chrome — keep in sync with App `tipPromptTitleSize`.
  static const titleSize = 40.0;

  /// Product tip chrome — keep in sync with App `tipPromptBodySize`.
  static const bodySize = 32.0;

  @override
  Widget build(BuildContext context) {
    final light = tone == CyberTone.light;
    final titleColor = light ? _titleDark : CyberColors.textPrimary;
    final bodyColor = light ? _bodyDark : CyberColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: titleColor,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: 0.02 * titleSize,
            decoration: TextDecoration.none,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: CyberDimens.contentPadding),
          const _CyberPromptDivider(),
          const SizedBox(height: CyberDimens.contentPadding),
          DefaultTextStyle(
            style: TextStyle(
              color: bodyColor,
              fontSize: bodySize,
              height: 1.2,
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.none,
            ),
            child: body!,
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: CyberDimens.contentPadding),
          const _CyberPromptDivider(),
          const SizedBox(height: CyberDimens.contentPadding),
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

class _CyberPromptDivider extends StatelessWidget {
  const _CyberPromptDivider();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x0068686C),
            CyberColors.dividerCenter,
            Color(0x0068686C),
          ],
        ),
      ),
      child: SizedBox(height: 1, width: double.infinity),
    );
  }
}
