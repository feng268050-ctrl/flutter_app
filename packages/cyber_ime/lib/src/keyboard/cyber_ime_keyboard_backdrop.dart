import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Single Gaussian blur plate for the CyberIME keyboard slot (lws-ui
/// `ImeKeyboardBackdropHost`).
///
/// Fills the keyboard band only — keycaps and panel chrome sit **above** this
/// layer and MUST NOT add their own [CyberBackdropBlur].
class CyberImeKeyboardBackdrop extends StatelessWidget {
  const CyberImeKeyboardBackdrop({
    super.key,
    this.intensity = CyberBlurIntensity.high,
    this.blurTint = CyberBlurTint.dark,
    this.sampleMode = CyberBlurSampleMode.realtime,
  });

  final CyberBlurIntensity intensity;
  final CyberBlurTint blurTint;
  final CyberBlurSampleMode sampleMode;

  @override
  Widget build(BuildContext context) {
    return CyberBackdropBlur(
      sampleMode: sampleMode,
      intensity: intensity,
      blurTint: blurTint,
      // Empty child: blur + tint only; layout lives in [CyberImeKeyboardPanel].
      child: const SizedBox.expand(),
    );
  }
}
