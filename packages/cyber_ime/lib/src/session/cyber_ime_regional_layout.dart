import 'package:flutter/foundation.dart';

/// Soft-keyboard layout profile (Settings Segment + CyberIME Keyboard A).
///
/// Labels: Default / QWERTY / QWERTZ / AZERTY / JIS.
/// Distinct from [CyberImeGlobalKind] (english/chinese input language).
enum CyberImeRegionalProfile {
  /// Original CyberIME phone letter pad (3 letter rows + bottom).
  defaultSoft,

  /// US QWERTY typewriter block (ANSI Enter geometry).
  ansi,

  /// German QWERTZ ISO typewriter block.
  qwertz,

  /// French AZERTY ISO typewriter block.
  azerty,

  /// Japanese JIS typewriter (英数 + hiragana/katakana modes).
  jis;

  /// Short Segment label for product Settings choosers.
  String get segmentLabel => switch (this) {
        CyberImeRegionalProfile.defaultSoft => 'Default',
        CyberImeRegionalProfile.ansi => 'QWERTY',
        CyberImeRegionalProfile.qwertz => 'QWERTZ',
        CyberImeRegionalProfile.azerty => 'AZERTY',
        CyberImeRegionalProfile.jis => 'JIS',
      };

  /// Operator-facing name (same as [segmentLabel] for the five profiles).
  String get displayName => segmentLabel;
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
    CyberImeRegionalProfile initial = CyberImeRegionalProfile.defaultSoft,
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
    CyberImeRegionalProfile.defaultSoft,
  );

  static CyberImeRegionalLayoutProvider get provider => _provider;

  static void register(CyberImeRegionalLayoutProvider? provider) {
    _provider = provider ??
        const CyberImeFixedRegionalLayoutProvider(
          CyberImeRegionalProfile.defaultSoft,
        );
  }
}
