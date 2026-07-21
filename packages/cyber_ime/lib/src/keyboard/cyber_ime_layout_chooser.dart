import 'package:cyber_ime/src/keyboard/cyber_ime_layout_preview.dart';
import 'package:cyber_ime/src/session/cyber_ime_regional_layout.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Product-ready regional layout chooser + typewriter preview.
///
/// Drop into any series App Settings page. Owns Segment labels, display name,
/// caption, and [CyberImeLayoutPreview] — not Apply / Restart / HAL / HID
/// (those stay product-specific).
///
/// Example:
/// ```dart
/// CyberImeLayoutChooser(
///   selected: selected,
///   onSelected: (p) => setState(() => selected = p),
/// )
/// ```
class CyberImeLayoutChooser extends StatelessWidget {
  const CyberImeLayoutChooser({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.profiles = CyberImeRegionalProfile.values,
    this.previewCaption = 'Typewriter block (no F-keys / NumPad)',
    this.showDisplayName = true,
  });

  /// Currently highlighted regional profile.
  final CyberImeRegionalProfile selected;

  /// Called when the operator picks another Segment value.
  final ValueChanged<CyberImeRegionalProfile> onSelected;

  /// When false, Segment interaction is ignored.
  final bool enabled;

  /// Profiles offered in the Segment (default: all five).
  final List<CyberImeRegionalProfile> profiles;

  /// Small caption above the keyboard preview.
  final String previewCaption;

  /// Show [CyberImeRegionalProfile.displayName] under the Segment.
  final bool showDisplayName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: CyberSegmentedControl<CyberImeRegionalProfile>(
            segments: [
              for (final p in profiles)
                ButtonSegment<CyberImeRegionalProfile>(
                  value: p,
                  label: Text(p.segmentLabel),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (s) {
              if (!enabled || s.isEmpty) return;
              onSelected(s.first);
            },
          ),
        ),
        if (showDisplayName)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selected.displayName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    previewCaption,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ),
                CyberImeLayoutPreview(profile: selected),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
