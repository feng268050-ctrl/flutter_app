import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/presentation/home_clock.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  testWidgets('HomeClock shows HH:mm and keeps ValueKey', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: HomeClock(fontSize: 48, showDateLine: false)),
        ),
      ),
    );
    await tester.pump();

    final textFinder = find.byKey(const ValueKey('home-clock-text'));
    expect(textFinder, findsOneWidget);
    final label = tester.widget<Text>(textFinder).data!;
    expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(label), isTrue);
  });

  testWidgets('HomeClock EN date is Wed Aug 5 plain text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        home: Scaffold(
          body: Center(
            child: HomeClock(
              fontSize: 48,
              now: () => DateTime(2026, 8, 5, 15, 30),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('home-clock-text')), findsOneWidget);
    final dateFinder = find.byKey(const ValueKey('home-clock-date'));
    expect(dateFinder, findsOneWidget);
    final date = tester.widget<Text>(dateFinder).data!;
    expect(date, 'Wed Aug 5');
    // Plain Text — no CustomPaint sibling for the date line.
    expect(
      find.descendant(of: dateFinder, matching: find.byType(CustomPaint)),
      findsNothing,
    );
  });

  testWidgets('HomeClock ZH date is 8月5日 周三 with space', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: HomeClock(
              fontSize: 48,
              now: () => DateTime(2026, 8, 5, 15, 30),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final date = tester.widget<Text>(
      find.byKey(const ValueKey('home-clock-date')),
    ).data!;
    expect(date, '8月5日 周三');
  });
}
