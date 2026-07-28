import 'package:flutter/foundation.dart';

/// Soft-keyboard layout profile (Settings Segment + CyberIME Keyboard A).
///
/// Labels: QWERTY / QWERTZ / AZERTY / JIS.
/// Distinct from [CyberImeGlobalKind] (english/chinese input language).
enum CyberImeRegionalProfile {
  /// US QWERTY phone soft keyboard (default).
  qwerty,

  /// German QWERTZ phone soft keyboard.
  qwertz,

  /// French AZERTY phone soft keyboard.
  azerty,

  /// Japanese romaji 26-key phone soft keyboard.
  jis;

  /// Short Segment label for product Settings choosers.
  String get segmentLabel => switch (this) {
        CyberImeRegionalProfile.qwerty => 'QWERTY',
        CyberImeRegionalProfile.qwertz => 'QWERTZ',
        CyberImeRegionalProfile.azerty => 'AZERTY',
        CyberImeRegionalProfile.jis => 'JIS',
      };

  /// Operator-facing name (same as [segmentLabel]).
  String get displayName => segmentLabel;

  /// Persist id written as `profile=` (only the four soft values).
  String get confId => name;

  /// Parse persisted / legacy ids. Unknown and empty → [qwerty].
  ///
  /// Accepts legacy `default` / `defaultSoft` / `ansi`.
  static CyberImeRegionalProfile parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case null:
      case '':
      case 'default':
      case 'defaultsoft':
      case 'ansi':
      case 'qwerty':
      case 'us':
        return CyberImeRegionalProfile.qwerty;
      case 'qwertz':
      case 'de':
        return CyberImeRegionalProfile.qwertz;
      case 'azerty':
      case 'fr':
        return CyberImeRegionalProfile.azerty;
      case 'jis':
      case 'jp':
        return CyberImeRegionalProfile.jis;
      default:
        return CyberImeRegionalProfile.qwerty;
    }
  }
}

/// App-registered regional layout provider.
abstract class CyberImeRegionalLayoutProvider {
  CyberImeRegionalProfile get profile;
}

/// Fixed provider for tests / Default.
class CyberImeFixedRegionalLayoutProvider
    implements CyberImeRegionalLayoutProvider {
  const CyberImeFixedRegionalLayoutProvider(this.profile);

  @override
  final CyberImeRegionalProfile profile;
}

/// Mutable provider the App can update when Settings persists a layout.
class CyberImeMutableRegionalLayoutProvider extends ChangeNotifier
    implements CyberImeRegionalLayoutProvider {
  CyberImeMutableRegionalLayoutProvider([
    CyberImeRegionalProfile initial = CyberImeRegionalProfile.qwerty,
  ]) : _profile = initial;

  CyberImeRegionalProfile _profile;

  @override
  CyberImeRegionalProfile get profile => _profile;

  set profile(CyberImeRegionalProfile value) {
    if (_profile == value) return;
    _profile = value;
    notifyListeners();
  }
}

/// Registry for the App regional layout provider.
abstract final class CyberImeRegionalLayoutRegistry {
  static CyberImeRegionalLayoutProvider _provider =
      const CyberImeFixedRegionalLayoutProvider(
    CyberImeRegionalProfile.qwerty,
  );

  static CyberImeRegionalLayoutProvider get provider => _provider;

  static void register(CyberImeRegionalLayoutProvider? provider) {
    _provider = provider ??
        const CyberImeFixedRegionalLayoutProvider(
          CyberImeRegionalProfile.qwerty,
        );
  }
}
