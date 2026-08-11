import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/chrome/settings_chrome.dart';

/// One row in a [SettingsPillDropdown] menu.
final class SettingsPillOption<T> {
  const SettingsPillOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Value pill + frost anchored menu (matches product HMI Settings chrome).
final class SettingsPillDropdown<T> extends StatelessWidget {
  const SettingsPillDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.width = 240,
    this.height = 52,
  });

  final T value;
  final String label;
  final List<SettingsPillOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final double width;
  final double height;

  static const accent = Color(0xFFFD7632);

  Future<void> _open(BuildContext pillContext) async {
    if (!enabled) {
      return;
    }
    final box = pillContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final selected = await showSettingsPillPopup<T>(
      context: pillContext,
      anchor: anchor,
      selected: value,
      options: options,
    );
    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Builder(
        builder: (pillContext) {
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(height / 2),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled
                  ? () {
                      CyberClickSoundRegistry.playClick();
                      unawaited(_open(pillContext));
                    }
                  : null,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF3A3D45),
                      Color(0xFF252830),
                    ],
                  ),
                  border: Border.all(color: CyberColors.borderMid),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SettingsTextStyles.title.copyWith(
                            fontSize: SettingsDimens.subtitleSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<T?> showSettingsPillPopup<T>({
  required BuildContext context,
  required Rect anchor,
  required T? selected,
  required List<SettingsPillOption<T>> options,
  double popupWidth = 280,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _SettingsPillPopup<T>(
        globalAnchor: anchor,
        selected: selected,
        options: options,
        animation: animation,
        popupWidth: popupWidth,
      );
    },
  );
}

final class _SettingsPillPopup<T> extends StatelessWidget {
  const _SettingsPillPopup({
    required this.globalAnchor,
    required this.selected,
    required this.options,
    required this.animation,
    required this.popupWidth,
  });

  final Rect globalAnchor;
  final T? selected;
  final List<SettingsPillOption<T>> options;
  final Animation<double> animation;
  final double popupWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    const gap = 8.0;
    var left = globalAnchor.left;
    if (left + popupWidth > media.width - SettingsDimens.inset) {
      left = media.width - SettingsDimens.inset - popupWidth;
    }
    left = left.clamp(SettingsDimens.inset, media.width - popupWidth);
    final top = (globalAnchor.bottom + gap)
        .clamp(SettingsDimens.inset, media.height - 280);
    const accent = SettingsPillDropdown.accent;
    final selectedBg = accent.withValues(alpha: 0.2);

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
            left: left,
            top: top,
            width: popupWidth,
            child: FadeTransition(
              opacity: animation,
              child: CyberCard(
                sampleMode: CyberBlurSampleMode.realtime,
                intensity: CyberBlurIntensity.high,
                blurTint: CyberBlurTint.dark,
                outlineStyle: CyberPanelOutlineStyle.uniform,
                borderWidth: 1,
                borderColor: CyberColors.borderUniform,
                width: popupWidth,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = option.value == selected;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            CyberClickSoundRegistry.playClick();
                            Navigator.pop(context, option.value);
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
                            child: Text(
                              option.label,
                              style: SettingsTextStyles.title.copyWith(
                                color: isSelected ? accent : Colors.white,
                                fontWeight: FontWeight.w400,
                                fontSize: SettingsDimens.subtitleSize,
                              ),
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
