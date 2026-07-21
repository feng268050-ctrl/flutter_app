import 'package:cyber_ime/src/field/cyber_ime_bottom_row_profile.dart';
import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/field/cyber_ime_field_type.dart';
import 'package:cyber_ime/src/field/cyber_ime_numeric_policy.dart';

/// Maps [CyberImeFieldType] → keyboard profile (lws-ui ImeFieldProfileRegistry).
abstract final class CyberImeFieldProfileRegistry {
  static CyberImeFieldProfile profile(
    CyberImeFieldType type, {
    CyberImeNumericPolicy? numericPolicyOverride,
  }) {
    switch (type) {
      case CyberImeFieldType.text:
        return CyberImeFieldProfile(
          initialLayoutId: CyberImeLayoutId.qwertyGlobal,
          allowedLayoutIds: CyberImeFieldProfile.symbolLayersPlusQwerty(),
          bottomRowProfile: CyberImeBottomRowProfile.defaults,
        );
      case CyberImeFieldType.number:
        return CyberImeFieldProfile(
          initialLayoutId: CyberImeLayoutId.numericDedicatedB,
          allowedLayoutIds: const {CyberImeLayoutId.numericDedicatedB},
          numericPolicy:
              numericPolicyOverride ?? CyberImeNumericPolicy.integer,
        );
      case CyberImeFieldType.signedDecimal:
        return CyberImeFieldProfile(
          initialLayoutId: CyberImeLayoutId.numericDedicatedB,
          allowedLayoutIds: const {CyberImeLayoutId.numericDedicatedB},
          numericPolicy:
              numericPolicyOverride ?? CyberImeNumericPolicy.signedDecimal,
        );
      case CyberImeFieldType.email:
        return CyberImeFieldProfile(
          initialLayoutId: CyberImeLayoutId.qwertyGlobal,
          allowedLayoutIds: CyberImeFieldProfile.symbolLayersPlusQwerty(),
          bottomRowProfile: CyberImeBottomRowProfile.email,
        );
      case CyberImeFieldType.uri:
        return CyberImeFieldProfile(
          initialLayoutId: CyberImeLayoutId.qwertyGlobal,
          allowedLayoutIds: CyberImeFieldProfile.symbolLayersPlusQwerty(),
          bottomRowProfile: CyberImeBottomRowProfile.uri,
        );
      case CyberImeFieldType.password:
        return CyberImeFieldProfile(
          initialLayoutId: CyberImeLayoutId.qwertyGlobal,
          allowedLayoutIds: CyberImeFieldProfile.symbolLayersPlusQwerty(),
          bottomRowProfile: CyberImeBottomRowProfile.password,
          maskInput: true,
        );
      case CyberImeFieldType.wifi:
        return CyberImeFieldProfile(
          initialLayoutId: CyberImeLayoutId.qwertyGlobal,
          allowedLayoutIds: CyberImeFieldProfile.symbolLayersPlusQwerty(),
          bottomRowProfile: CyberImeBottomRowProfile.wifi,
          maskInput: true,
        );
    }
  }
}
