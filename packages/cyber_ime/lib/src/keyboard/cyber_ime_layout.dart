import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';

/// Immutable keyboard layout for one panel state.
class CyberImeLayout {
  const CyberImeLayout({
    required this.kind,
    required this.rows,
  });

  final CyberImeKeyboardKind kind;
  final List<CyberImeKeyboardRow> rows;
}
