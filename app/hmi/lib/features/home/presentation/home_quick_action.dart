import 'package:flutter/material.dart';
import 'package:lws_hmi/ui/cyber/cyber_backdrop_blur.dart';
import 'package:lws_hmi/ui/cyber/cyber_blur_intensity.dart';
import 'package:lws_hmi/ui/cyber/cyber_blur_sample_mode.dart';
import 'package:lws_hmi/ui/cyber/cyber_blur_tint.dart';

/// Design tokens from lws-ui `home_quick_action_*` / `home_stat_card_corner_radius`.
const double kHomeQuickActionCorner = 18;
const double kHomeQuickActionLabelMarginTop = 10;

/// Home quick-action tile — Material stand-in for lws-ui
/// `FrostQuickActionEntry` + nested `FrostCardView`.
///
/// lws-ui XML uses live frost with `frostedGlassBlurIntensity=extreme` and
/// `frostedGlassBlurTint=warm` (white mist, not black).
class HomeQuickAction extends StatelessWidget {
  const HomeQuickAction({
    super.key,
    required this.cardWidth,
    required this.cardHeight,
    required this.label,
    required this.onPressed,
    required this.child,
    this.labelWidth,
    this.cornerRadius = kHomeQuickActionCorner,
    this.labelMarginTop = kHomeQuickActionLabelMarginTop,
    this.sampleMode = CyberBlurSampleMode.realtime,
    this.blurIntensity = CyberBlurIntensity.extreme,
    this.blurTint = CyberBlurTint.warm,
  });

  final double cardWidth;
  final double cardHeight;
  final String label;
  final VoidCallback onPressed;
  final Widget child;

  /// Defaults to [cardWidth] (square tiles). Wide AI Vision passes its card width.
  final double? labelWidth;
  final double cornerRadius;
  final double labelMarginTop;

  final CyberBlurSampleMode sampleMode;
  final CyberBlurIntensity blurIntensity;
  final CyberBlurTint blurTint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(cornerRadius);
    final captionWidth = labelWidth ?? cardWidth;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: const Color(0x55FFFFFF),
                    width: 1,
                  ),
                ),
                child: CyberBackdropBlur(
                  sampleMode: sampleMode,
                  intensity: blurIntensity,
                  blurTint: blurTint,
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: child,
                  ),
                ),
              ),
            ),
            SizedBox(height: labelMarginTop),
            SizedBox(
              width: captionWidth,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (16 * (cardHeight / 108)).clamp(12, 20),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
