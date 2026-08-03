import 'package:cyber_ime/src/keyboard/cyber_ime_layout_preview.dart';
import 'package:cyber_ime/src/session/cyber_ime_regional_layout.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Product-ready regional layout chooser + soft keyboard preview.
///
/// Drop into any series App Settings page. Owns Segment labels, display name,
/// caption, footnote, and [CyberImeLayoutPreview] — not Apply / Restart / HAL /
/// HID (those stay product-specific).
class CyberImeLayoutChooser extends StatelessWidget {
  const CyberImeLayoutChooser({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.profiles = CyberImeRegionalProfile.values,
    this.previewCaption = '软件键盘布局预览',
    this.showDisplayName = true,
    this.showPreview = true,
    this.showFootnote = true,
  });

  /// Currently highlighted regional profile.
  final CyberImeRegionalProfile selected;

  /// Called when the operator picks another Segment value.
  final ValueChanged<CyberImeRegionalProfile> onSelected;

  /// When false, Segment interaction is ignored.
  final bool enabled;

  /// Profiles offered in the Segment (default: all three soft layouts).
  final List<CyberImeRegionalProfile> profiles;

  /// Small caption above the keyboard preview.
  final String previewCaption;

  /// Show [CyberImeRegionalProfile.displayName] under the Segment.
  final bool showDisplayName;

  /// Show the keyboard preview under the Segment.
  final bool showPreview;

  /// Show accent / romaji helper under the preview.
  final bool showFootnote;

  String get _footnote {
    return switch (selected) {
      CyberImeRegionalProfile.qwertz ||
      CyberImeRegionalProfile.azerty =>
        '长按可输入重音字符',
      CyberImeRegionalProfile.qwerty => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final footnote = _footnote;
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
        if (showPreview)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CyberImeLayoutPreviewCard(
              profile: selected,
              previewCaption: previewCaption,
            ),
          ),
        if (showPreview && showFootnote && footnote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              footnote,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

/// Border-only preview chrome around [CyberImeLayoutPreview].
///
/// Keep this outside opaque/frosted parent panels when possible. The keyboard
/// backdrop inside the preview can then sample the page backdrop directly
/// instead of sampling an already-frosted Settings group face.
class CyberImeLayoutPreviewCard extends StatelessWidget {
  const CyberImeLayoutPreviewCard({
    super.key,
    required this.profile,
    this.previewCaption = '软件键盘布局预览',
  });

  final CyberImeRegionalProfile profile;
  final String previewCaption;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        // Border only — opaque fill would block backdrop 透视.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
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
            CyberImeLayoutPreview(profile: profile),
          ],
        ),
      ),
    );
  }
}
