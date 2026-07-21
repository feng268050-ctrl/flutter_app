import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';

/// Gates Keyboard B commits for sign / decimal / double-zero.
class CyberImeNumericPolicy {
  const CyberImeNumericPolicy({
    this.allowSign = false,
    this.allowDecimal = false,
    this.allowDoubleZero = true,
  });

  final bool allowSign;
  final bool allowDecimal;
  final bool allowDoubleZero;

  static const CyberImeNumericPolicy integer = CyberImeNumericPolicy();

  static const CyberImeNumericPolicy signedDecimal = CyberImeNumericPolicy(
    allowSign: true,
    allowDecimal: true,
  );

  bool shouldCommit(CyberImeKeyDef key, String currentText) {
    switch (key.id) {
      case CyberImeKeyId.digit:
        return true;
      case CyberImeKeyId.custom:
        if (key.primary == '00') return allowDoubleZero;
        return true;
      case CyberImeKeyId.minus:
        return allowSign && _canInsertSign(currentText);
      case CyberImeKeyId.decimalPeriod:
        return allowDecimal && !currentText.contains('.');
      default:
        return true;
    }
  }

  static bool _canInsertSign(String text) {
    if (text.isEmpty) return true;
    return !text.contains('-');
  }
}
