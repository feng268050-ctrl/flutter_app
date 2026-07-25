import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/l10n/app_locales.dart';

void main() {
  testWidgets('AppLocalizations resolves EN and ZH for seed keys', (tester) async {
    late AppLocalizations en;
    late AppLocalizations zh;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: kAppSupportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            en = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(en.languageSettingText, 'Language');
    expect(en.settingsTitle, 'Settings');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: kAppSupportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            zh = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(zh.languageSettingText, isNot(equals('Language')));
    expect(zh.languageSettingText.isNotEmpty, isTrue);
  });
}
