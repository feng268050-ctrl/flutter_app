import 'package:cyber_ime/src/keyboard/cyber_ime_keyboard_top_edge.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Single Gaussian blur plate for the CyberIME keyboard slot (lws-ui
/// `ImeKeyboardBackdropHost`).
///
/// Fills the keyboard band only — keycaps and panel chrome sit **above** this
/// layer and MUST NOT add their own [CyberBackdropBlur].
///
/// Sampling policy:
/// - With a [CyberBlurBackdropScope], use [CyberBlurSampleMode.followLayout]
///   so the keyboard band samples the page backdrop with aligned perspective.
/// - Without a scope, fall back to [CyberBlurSampleMode.realtime].
///
/// Root [Overlay] entries on Weston paint black with realtime blur, so callers
/// should pass [backdropScope] from the page scope instead of forcing realtime.
///
/// Paints a top center-bright gradient hairline (两边向中间渐变亮边).
class CyberImeKeyboardBackdrop extends StatelessWidget {
  const CyberImeKeyboardBackdrop({
    super.key,
    this.intensity = CyberBlurIntensity.high,
    this.blurTint = CyberBlurTint.dark,
    this.sampleMode,
    this.backdropScope,
    this.showTopEdge = true,
  });

  final CyberBlurIntensity intensity;
  final CyberBlurTint blurTint;

  /// Explicit sampling override. When null, the backdrop uses follow-layout
  /// sampling if a capture scope is available, otherwise realtime blur.
  final CyberBlurSampleMode? sampleMode;

  /// Page capture root when showing from a root Overlay (outside the scope).
  final CyberBlurBackdropScopeState? backdropScope;

  /// Top gradient bright edge on the frost plate.
  final bool showTopEdge;

  @override
  Widget build(BuildContext context) {
    final resolvedScope =
        backdropScope ?? CyberBlurBackdropScope.maybeOf(context);
    final resolvedSampleMode = sampleMode ??
        (resolvedScope != null
            ? CyberBlurSampleMode.followLayout
            : CyberBlurSampleMode.realtime);
    final blur = CyberBackdropBlur(
      sampleMode: resolvedSampleMode,
      intensity: intensity,
      blurTint: blurTint,
      backdropScope: resolvedScope,
      captureTarget: CyberBlurCaptureTarget.currentPage,
      // Empty child: blur + tint only; layout lives in [CyberImeKeyboardPanel].
      child: const SizedBox.expand(),
    );
    if (!showTopEdge) {
      return blur;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        blur,
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: CyberImeKeyboardTopEdge(),
        ),
      ],
    );
  }
}
