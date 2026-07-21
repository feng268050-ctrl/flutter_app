import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/system_status/presentation/system_status_card.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('SystemStatusCard paints placeholder rows without AppScope',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SystemStatusCard()),
      ),
    );
    await tester.pump();

    expect(find.byType(SystemStatusCard), findsOneWidget);
    expect(find.text('LOAD'), findsOneWidget);
    expect(find.text('--'), findsWidgets);
  });
}
