import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/presentation/home_clock.dart';

void main() {
  testWidgets('HomeClock shows HH:mm and keeps ValueKey', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: HomeClock(fontSize: 48)),
        ),
      ),
    );
    await tester.pump();

    final textFinder = find.byKey(const ValueKey('home-clock-text'));
    expect(textFinder, findsOneWidget);
    final label = tester.widget<Text>(textFinder).data!;
    expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(label), isTrue);
  });
}
