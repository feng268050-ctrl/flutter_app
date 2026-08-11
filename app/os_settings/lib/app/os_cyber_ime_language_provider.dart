import 'package:cyber_hal/locale.dart';
import 'package:cyber_ime/cyber_ime.dart';

/// CyberIME language provider driven by HAL [LocaleSettings].
final class OsCyberImeLanguageProvider implements CyberImeLanguageProvider {
  OsCyberImeLanguageProvider(this._store);

  final LocaleSettings _store;

  @override
  CyberImeGlobalKind get globalKind => _store.language.isChinese
      ? CyberImeGlobalKind.chinese
      : CyberImeGlobalKind.english;
}
