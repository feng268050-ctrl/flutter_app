import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';

/// Anchored material list (lws-ui `DataPopupBuilder.materialsBuilder`).
///
/// Uses [CyberBlurSampleMode.realtime] Gaussian frost (same as
/// [CyberOverlayHost] IME / Engineer frost panels). Transparent barrier so
/// [BackdropFilter] samples the page, not a scrim.
Future<MaterialType?> showEngineerMaterialPopup({
  required BuildContext context,
  required Rect anchor,
  required MaterialType? selected,
  required ProcessType processType,
}) {
  return showGeneralDialog<MaterialType>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _EngineerMaterialPopup(
        anchor: anchor,
        selected: selected,
        processType: processType,
        animation: animation,
      );
    },
  );
}

final class _EngineerMaterialPopup extends StatelessWidget {
  const _EngineerMaterialPopup({
    required this.anchor,
    required this.selected,
    required this.processType,
    required this.animation,
  });

  final Rect anchor;
  final MaterialType? selected;
  final ProcessType processType;
  final Animation<double> animation;

  static const double _popupWidth = 350;
  static const double _gapBelowAnchor = 4;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final accent = ProcessModeTokens.tabActiveColor(processType);
    final selectedBg = accent.withOpacity(0.2);
    final top = (anchor.bottom + _gapBelowAnchor)
        .clamp(8.0, media.height - 340.0)
        .toDouble();
    final left = (anchor.right - _popupWidth)
        .clamp(8.0, media.width - _popupWidth - 8.0)
        .toDouble();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.pop(context),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: _popupWidth,
          child: FadeTransition(
            opacity: animation,
            child: CyberCard(
              // Realtime Gaussian — firstFrame needs CyberBlurBackdropScope and
              // falls back to opaque fake glass without it.
              sampleMode: CyberBlurSampleMode.realtime,
              intensity: CyberBlurIntensity.high,
              blurTint: CyberBlurTint.dark,
              width: _popupWidth,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 334),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: MaterialType.values.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final material = MaterialType.values[index];
                    final isSelected = material == selected;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          CyberClickSoundRegistry.playClick();
                          Navigator.pop(context, material);
                        },
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? selectedBg : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                ProcessModeAssets.materialIcon(material),
                                width: 40,
                                height: 20,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  material.englishName,
                                  style: TextStyle(
                                    color: isSelected ? accent : Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
