import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_navigation.dart';

void main() {
  testWidgets('buildAppSlideRoute keeps L/R slide and edge pop gesture',
      (tester) async {
    late CupertinoPageRoute<void> route;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                route = buildAppSlideRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Text('nested'),
                  ),
                ) as CupertinoPageRoute<void>;
                Navigator.of(context).push(route);
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('nested'), findsOneWidget);
    expect(route.popGestureEnabled, isTrue);
    expect(route.canPop, isTrue);

    // Drag past mid-screen so Cupertino commits the pop (see route_test.dart).
    await tester.dragFrom(const Offset(5, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('nested'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
