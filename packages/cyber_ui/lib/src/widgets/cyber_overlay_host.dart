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

/// Overlay host for Cyber dialogs (lws-ui `FrostOverlayHost` stand-in).
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
    bool freezePageBackdrop = true,
    CyberBackdropBlurController? pageBackdropController,
  }) {
    if (freezePageBackdrop) {
      pageBackdropController?.requestSample();
    }
    final panel = CyberPanelBorder(tone: tone);
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: CyberColors.scrim,
      builder: (dialogContext) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: DecoratedBox(
              decoration: panel.chromeDecoration(),
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
