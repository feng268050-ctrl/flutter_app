/// Global letter layout kind selected by the App language provider.
enum CyberImeGlobalKind {
  english,
  chinese,
}

/// App-registered language provider (no Settings dependency inside cyber_ime).
abstract class CyberImeLanguageProvider {
  CyberImeGlobalKind get globalKind;
}

/// Fixed provider for tests / English-only Apps.
class CyberImeFixedLanguageProvider implements CyberImeLanguageProvider {
  const CyberImeFixedLanguageProvider(this.globalKind);

  @override
  final CyberImeGlobalKind globalKind;
}

/// Registry for the App language provider.
abstract final class CyberImeLanguageRegistry {
  static CyberImeLanguageProvider _provider =
      const CyberImeFixedLanguageProvider(CyberImeGlobalKind.english);

  static CyberImeLanguageProvider get provider => _provider;

  static void register(CyberImeLanguageProvider? provider) {
    _provider = provider ??
        const CyberImeFixedLanguageProvider(CyberImeGlobalKind.english);
  }
}
