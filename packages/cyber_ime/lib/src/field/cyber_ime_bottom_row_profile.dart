import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';

/// Bottom-row (4th row) profiles for Keyboard A.
enum CyberImeBottomRowProfile {
  /// Mode · space · ./, · enter
  defaults,

  /// Mode · space · .com · @ · enter
  email,

  /// Mode · space · / · : · enter
  uri,

  /// Mode · space · ./, · reveal · enter
  password,

  /// Same as [defaults] (reveal lives on the text field for Wi‑Fi).
  wifi,
}

List<CyberImeKeyDef> cyberImeBottomRowKeys(
  CyberImeBottomRowProfile profile, {
  bool numericModeLabel = false,
}) {
  CyberImeKeyDef modeSwitch() => CyberImeKeyDef(
        id: CyberImeKeyId.modeSwitch,
        primary: numericModeLabel ? 'abc' : '123',
        widthWeight: 1.2,
      );

  CyberImeKeyDef space() => const CyberImeKeyDef(
        id: CyberImeKeyId.space,
        primary: ' ',
        widthWeight: 5,
      );

  CyberImeKeyDef commaPeriod() => const CyberImeKeyDef(
        id: CyberImeKeyId.commaPeriod,
        primary: '.',
        secondary: ',',
        widthWeight: 1,
      );

  CyberImeKeyDef enter() => const CyberImeKeyDef(
        id: CyberImeKeyId.enter,
        primary: '⏎',
        widthWeight: 1.4,
      );

  switch (profile) {
    case CyberImeBottomRowProfile.defaults:
    case CyberImeBottomRowProfile.wifi:
      return [modeSwitch(), space(), commaPeriod(), enter()];
    case CyberImeBottomRowProfile.email:
      return [
        modeSwitch(),
        space(),
        const CyberImeKeyDef(
          id: CyberImeKeyId.custom,
          primary: '.com',
          widthWeight: 1,
        ),
        const CyberImeKeyDef(id: CyberImeKeyId.at, primary: '@', widthWeight: 1),
        enter(),
      ];
    case CyberImeBottomRowProfile.uri:
      return [
        modeSwitch(),
        space(),
        const CyberImeKeyDef(
          id: CyberImeKeyId.custom,
          primary: '/',
          widthWeight: 1,
        ),
        const CyberImeKeyDef(
          id: CyberImeKeyId.custom,
          primary: ':',
          widthWeight: 1,
        ),
        enter(),
      ];
    case CyberImeBottomRowProfile.password:
      return [
        modeSwitch(),
        space(),
        commaPeriod(),
        const CyberImeKeyDef(
          id: CyberImeKeyId.passwordReveal,
          primary: '👁',
          widthWeight: 1,
        ),
        enter(),
      ];
  }
}
