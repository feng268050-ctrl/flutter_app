import 'package:cyber_ime/src/field/cyber_ime_bottom_row_profile.dart';
import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_keyboard_panel.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_keyboard_rows.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_layout.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_layouts.dart';
import 'package:cyber_ime/src/session/cyber_ime_regional_layout.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Read-only CyberIME letter-layout preview (Settings / chooser chrome).
///
/// Builds the same soft Keyboard A geometry and [CyberImeKeyLabel] faces as the
/// live panel for [profile], without input, popups, or session wiring.
class CyberImeLayoutPreview extends StatelessWidget {
  const CyberImeLayoutPreview({
    super.key,
    required this.profile,
    this.height = kCyberImePanelHeight,
    this.bottomRow = CyberImeBottomRowProfile.defaults,
    this.kind = CyberImeKeyboardKind.englishGlobal,
    this.layout,
  });

  /// Regional soft layout to preview (may differ from the live registry).
  final CyberImeRegionalProfile profile;

  final double height;
  final CyberImeBottomRowProfile bottomRow;
  final CyberImeKeyboardKind kind;

  /// Optional explicit layout; when null, built from [profile] / [bottomRow].
  final CyberImeLayout? layout;

  CyberImeLayout get _layout =>
      layout ??
      CyberImeLayouts.letters(
        profile: profile,
        bottomRow: bottomRow,
        kind: kind,
      );

  @override
  Widget build(BuildContext context) {
    final resolved = _layout;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(CyberImeKeyboardRows.keyGap),
          child: CyberImeKeyboardRows(
            layout: resolved,
            keyFace: (key) => CyberButton(
              onPressed: null,
              expand: true,
              variant: key.id == CyberImeKeyId.enter
                  ? CyberButtonVariant.primary
                  : CyberButtonVariant.light,
              child: CyberImeKeyLabel(
                keyDef: key,
                shiftOn: false,
                profile: profile,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
