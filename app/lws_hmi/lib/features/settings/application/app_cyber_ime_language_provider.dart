import 'package:cyber_ime/cyber_ime.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';

/// CyberIME language provider driven by [CommonSettingsStore].
///
/// Reads live from the store so Language changes apply without re-registering.
final class AppCyberImeLanguageProvider implements CyberImeLanguageProvider {
  AppCyberImeLanguageProvider(this._store);

  final CommonSettingsStore _store;

  @override
  CyberImeGlobalKind get globalKind => _store.isChineseLanguage
      ? CyberImeGlobalKind.chinese
      : CyberImeGlobalKind.english;
}
