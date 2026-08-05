import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/presentation/home_clock.dart';

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

  testWidgets('HomeClock shows date and weekday under time', (tester) async {
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
    expect(date, contains('08-05'));
    expect(date, isNot(contains('2026')));
    expect(date, contains('Wednesday'));

    // Date line left/right edges match the time line (letter-spacing fit).
    final timeRect = tester.getRect(find.byKey(const ValueKey('home-clock-text')));
    final dateRect = tester.getRect(find.byKey(const ValueKey('home-clock-date')));
    expect(dateRect.width, closeTo(timeRect.width, 1.0));
    expect(dateRect.left, closeTo(timeRect.left, 1.0));
    expect(dateRect.right, closeTo(timeRect.right, 1.0));
  });
}
