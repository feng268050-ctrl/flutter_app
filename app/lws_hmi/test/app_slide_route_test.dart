import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_navigation.dart';

void main() {
  testWidgets('AppSlidePageRoute keeps L/R slide but disables edge pop gesture',
      (tester) async {
    late AppSlidePageRoute<void> route;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                route = AppSlidePageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Text('nested'),
                  ),
                );
                Navigator.of(context).push(route);
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('nested'), findsOneWidget);
    expect(route.popGestureEnabled, isFalse);
    expect(route.canPop, isTrue);

    // Edge drag must not pop — Back / maybePop is the exit path.
    await tester.dragFrom(const Offset(8, 400), const Offset(320, 0));
    await tester.pumpAndSettle();
    expect(find.text('nested'), findsOneWidget);
  });
}
