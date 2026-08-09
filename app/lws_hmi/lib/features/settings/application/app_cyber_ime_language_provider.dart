import 'package:cyber_hal/locale.dart';
import 'package:cyber_ime/cyber_ime.dart';

/// CyberIME language provider driven by HAL [LocaleSettings].
///
/// Reads live from the store so Language changes apply without re-registering.
final class AppCyberImeLanguageProvider implements CyberImeLanguageProvider {
  AppCyberImeLanguageProvider(this._store);

  final LocaleSettings _store;

  @override
  CyberImeGlobalKind get globalKind => _store.language.isChinese
      ? CyberImeGlobalKind.chinese
      : CyberImeGlobalKind.english;
}
