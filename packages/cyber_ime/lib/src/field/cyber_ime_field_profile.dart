import 'package:cyber_ime/src/field/cyber_ime_bottom_row_profile.dart';
import 'package:cyber_ime/src/field/cyber_ime_numeric_policy.dart';

/// Layout identifiers aligned with lws-ui KeyboardLayoutId.
enum CyberImeLayoutId {
  qwertyGlobal,
  symbolsPrimaryA,
  symbolsExtendedA,
  numericDedicatedB,
}

/// Runtime keyboard kind presented by the panel.
enum CyberImeKeyboardKind {
  englishGlobal,
  chineseGlobal,
  symbolsPrimary,
  symbolsExtended,
  numericDedicated,
}

/// Resolved profile for a [CyberImeFieldType].
class CyberImeFieldProfile {
  const CyberImeFieldProfile({
    required this.initialLayoutId,
    required this.allowedLayoutIds,
    this.bottomRowProfile = CyberImeBottomRowProfile.defaults,
    this.numericPolicy,
    this.maskInput = false,
  });

  final CyberImeLayoutId initialLayoutId;
  final Set<CyberImeLayoutId> allowedLayoutIds;
  final CyberImeBottomRowProfile bottomRowProfile;
  final CyberImeNumericPolicy? numericPolicy;
  final bool maskInput;

  CyberImeKeyboardKind get initialKind => kindFor(initialLayoutId);

  Set<CyberImeKeyboardKind> get allowedKinds =>
      allowedLayoutIds.map(kindFor).toSet();

  bool allowsKind(CyberImeKeyboardKind kind) => allowedKinds.contains(kind);

  static CyberImeKeyboardKind kindFor(CyberImeLayoutId id) {
    switch (id) {
      case CyberImeLayoutId.qwertyGlobal:
        return CyberImeKeyboardKind.englishGlobal;
      case CyberImeLayoutId.symbolsPrimaryA:
        return CyberImeKeyboardKind.symbolsPrimary;
      case CyberImeLayoutId.symbolsExtendedA:
        return CyberImeKeyboardKind.symbolsExtended;
      case CyberImeLayoutId.numericDedicatedB:
        return CyberImeKeyboardKind.numericDedicated;
    }
  }

  static Set<CyberImeLayoutId> symbolLayersPlusQwerty() => {
        CyberImeLayoutId.qwertyGlobal,
        CyberImeLayoutId.symbolsPrimaryA,
        CyberImeLayoutId.symbolsExtendedA,
      };
}
