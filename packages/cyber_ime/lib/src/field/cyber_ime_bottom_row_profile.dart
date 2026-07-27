import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';

/// Bottom-row (4th row) profiles for Keyboard A.
enum CyberImeBottomRowProfile {
  /// Mode · space · enter
  defaults,

  /// Mode · space · .com · @ · enter
  email,

  /// Mode · space · / · : · enter
  uri,

  /// Mode · space · reveal · enter
  password,

  /// Same as [defaults] (reveal lives on the text field for Wi‑Fi).
  wifi,
}

/// Soft phone bottom row (123 / optional language / Space / extras / confirm).
List<CyberImeKeyDef> cyberImeSoftBottomRowKeys(
  CyberImeBottomRowProfile profile, {
  bool includeLanguageToggle = false,
  bool numericModeLabel = false,
}) {
  CyberImeKeyDef modeSwitch() => CyberImeKeyDef(
        id: CyberImeKeyId.modeSwitch,
        primary: numericModeLabel ? 'ABC' : '123',
        widthWeight: 1.5,
      );

  CyberImeKeyDef language() => const CyberImeKeyDef(
        id: CyberImeKeyId.languageToggle,
        primary: 'あ',
        widthWeight: 1.25,
      );

  CyberImeKeyDef space() => const CyberImeKeyDef(
        id: CyberImeKeyId.space,
        primary: ' ',
        widthWeight: 5,
      );

  CyberImeKeyDef enter() => const CyberImeKeyDef(
        id: CyberImeKeyId.enter,
        primary: '⏎',
        widthWeight: 1.8,
      );

  final lead = <CyberImeKeyDef>[
    modeSwitch(),
    if (includeLanguageToggle) language(),
    space(),
  ];

  switch (profile) {
    case CyberImeBottomRowProfile.defaults:
    case CyberImeBottomRowProfile.wifi:
      return [...lead, enter()];
    case CyberImeBottomRowProfile.email:
      return [
        ...lead,
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
        ...lead,
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
        ...lead,
        const CyberImeKeyDef(
          id: CyberImeKeyId.passwordReveal,
          primary: '👁',
          widthWeight: 1,
        ),
        enter(),
      ];
  }
}

/// Legacy alias used by older call sites / typewriter helpers.
List<CyberImeKeyDef> cyberImeBottomRowKeys(
  CyberImeBottomRowProfile profile, {
  bool numericModeLabel = false,
}) =>
    cyberImeSoftBottomRowKeys(
      profile,
      numericModeLabel: numericModeLabel,
    );
