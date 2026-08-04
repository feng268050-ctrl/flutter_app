import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_anchored_popup_layout.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_frost_panel.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

/// Anchored favorites list (lws-ui `DataPopupBuilder.moreCommonBuilder`).
///
/// Frost menu under the “More Favorites” anchor — not a bottom sheet.
Future<ProcessPreset?> showEngineerFavoritesPopup({
  required BuildContext context,
  required Rect anchor,
  required List<ProcessPreset> presets,
  required String? selectedUuid,
  required String? selectedName,
  required ProcessType processType,
}) {
  return showGeneralDialog<ProcessPreset>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _EngineerFavoritesPopup(
        globalAnchor: anchor,
        presets: presets,
        selectedUuid: selectedUuid,
        selectedName: selectedName,
        processType: processType,
        animation: animation,
      );
    },
  );
}

final class _EngineerFavoritesPopup extends StatelessWidget {
  const _EngineerFavoritesPopup({
    required this.globalAnchor,
    required this.presets,
    required this.selectedUuid,
    required this.selectedName,
    required this.processType,
    required this.animation,
  });

  final Rect globalAnchor;
  final List<ProcessPreset> presets;
  final String? selectedUuid;
  final String? selectedName;
  final ProcessType processType;
  final Animation<double> animation;

  /// lws-ui `DataPopupBuilder` more-common width; height shows ~4 rows.
  static const double _popupWidth = 350;
  static const double _rowMinHeight = 56;
  static const double _rowVerticalPadding = 16;
  static const double _rowSpacing = 12;
  static const double _listVerticalPadding = 12;
  static const int _visibleRows = 4;

  static double get _maxHeight =>
      _listVerticalPadding * 2 +
      _visibleRows * _rowMinHeight +
      (_visibleRows - 1) * _rowSpacing;

  bool _isSelected(ProcessPreset preset) {
    if (selectedUuid != null && preset.uuid == selectedUuid) {
      return true;
    }
    if (selectedName != null && preset.name == selectedName) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final overlay = EngineerAnchoredPopupLayout.overlayBox(context);
    final media = MediaQuery.sizeOf(context);
    final overlaySize = overlay?.size ?? media;
    final localAnchor = overlay == null
        ? globalAnchor
        : EngineerAnchoredPopupLayout.localAnchor(
            overlay: overlay,
            globalAnchor: globalAnchor,
          );
    final origin = EngineerAnchoredPopupLayout.origin(
      overlaySize: overlaySize,
      localAnchorRect: localAnchor,
      popupWidth: _popupWidth,
    );
    final accent = ProcessModeTokens.tabActiveColor(processType);
    final selectedBg = accent.withOpacity(0.2);

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            left: origin.dx,
            top: origin.dy,
            width: _popupWidth,
            child: FadeTransition(
              opacity: animation,
              child: CyberCard(
                sampleMode: CyberBlurSampleMode.realtime,
                intensity: CyberBlurIntensity.high,
                blurTint: CyberBlurTint.dark,
                outlineStyle: CyberPanelOutlineStyle.uniform,
                borderWidth: EngineerFrostPanel.edgeWidth,
                borderColor: EngineerFrostPanel.edgeColor,
                width: _popupWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: _maxHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: _listVerticalPadding,
                    ),
                    itemCount: presets.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: _rowSpacing),
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      final isSelected = _isSelected(preset);
                      final material = preset.materialType;
                      return Material(
                        key: ValueKey('engineer-preset-${preset.uuid}'),
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            CyberClickSoundRegistry.playClick();
                            Navigator.pop(context, preset);
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: _rowMinHeight,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: _rowVerticalPadding,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? selectedBg : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Image.asset(
                                  material == null
                                      ? ProcessModeAssets.customizeIcon
                                      : ProcessModeAssets.materialIcon(
                                          material),
                                  width: 40,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    preset.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          isSelected ? accent : Colors.white,
                                      fontSize: AppTypography.bodySize,
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
      ),
    );
  }
}
