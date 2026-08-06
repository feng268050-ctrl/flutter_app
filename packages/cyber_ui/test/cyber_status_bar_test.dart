import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home status bar lays out items in order', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberHomeStatusBar(
            items: const [
              SizedBox(key: ValueKey('a'), width: 10, height: 10),
              SizedBox(key: ValueKey('b'), width: 10, height: 10),
              SizedBox(key: ValueKey('c'), width: 10, height: 10),
            ],
          ),
        ),
      ),
    );
    final row = tester.widget<Row>(
      find.descendant(
        of: find.byKey(const ValueKey('cyber-home-status-bar')),
        matching: find.byType(Row),
      ),
    );
    expect(row.children.length, 5);
    expect(find.byKey(const ValueKey('a')), findsOneWidget);
    expect(find.byKey(const ValueKey('b')), findsOneWidget);
    expect(find.byKey(const ValueKey('c')), findsOneWidget);
  });

  testWidgets('Home status bar accepts more than three items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberHomeStatusBar(
            items: List.generate(
              4,
              (i) => SizedBox(key: ValueKey('i$i'), width: 8, height: 8),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('i0')), findsOneWidget);
    expect(find.byKey(const ValueKey('i3')), findsOneWidget);
  });

  testWidgets('Home status bar background is transparent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberHomeStatusBar(items: []),
        ),
      ),
    );
    final box = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('cyber-home-status-bar')),
    );
    expect(box.color, Colors.transparent);
  });

  testWidgets('Page status bar regions and back callback', (tester) async {
    var back = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          splashFactory: NoSplash.splashFactory,
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF112233)),
        ),
        home: Scaffold(
          appBar: CyberPageStatusBar(
            title: 'Settings',
            onBack: () => back++,
            clockNow: () => DateTime(2026, 8, 5, 17, 39),
            statusItems: const [
              SizedBox(key: ValueKey('s0'), width: 8, height: 8),
              SizedBox(key: ValueKey('s1'), width: 8, height: 8),
              SizedBox(key: ValueKey('s2'), width: 8, height: 8),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-bar-clock')), findsOneWidget);
    // Default page chrome: weekday + date left of time (e.g. Wed Aug 5 17:39).
    final clock = tester.widget<Text>(
      find.byKey(const ValueKey('cyber-status-bar-clock')),
    );
    expect(clock.data, 'Wed Aug 5 17:39');
    expect(find.byKey(const ValueKey('s0')), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFF112233));
    // Clock end inset matches Home Quick/Engineer mode entry top (55).
    final clockRect = tester.getRect(
      find.byKey(const ValueKey('cyber-status-bar-clock')),
    );
    expect(tester.getSize(find.byType(MaterialApp)).width - clockRect.right, 55);

    await tester.tap(find.byKey(const ValueKey('cyber-page-status-bar-back')));
    await tester.pump();
    expect(back, 1);
  });

  testWidgets('Page status bar can hide date prefix', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: CyberPageStatusBar(
            title: 'X',
            showClockDate: false,
            clockNow: () => DateTime(2026, 8, 5, 17, 39),
            statusItems: const [],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('cyber-status-bar-clock'))).data,
      '17:39',
    );
  });

  testWidgets('Page status bar explicit background override', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF112233)),
        ),
        home: Scaffold(
          appBar: CyberPageStatusBar(
            title: 'Monitor',
            backgroundColor: const Color(0xFF445566),
            statusItems: const [],
          ),
        ),
      ),
    );
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFF445566));
  });

  testWidgets('Page bar trailing accepts four icons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: CyberPageStatusBar(
            title: 'X',
            statusItems: List.generate(
              4,
              (i) => SizedBox(key: ValueKey('p$i'), width: 6, height: 6),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('p3')), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-bar-clock')), findsOneWidget);
  });
}
