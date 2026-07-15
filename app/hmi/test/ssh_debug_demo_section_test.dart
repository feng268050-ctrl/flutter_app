import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/ssh/ssh_debug_controller.dart';
import 'package:lws_hmi/ui/demo/ssh_debug_demo_section.dart';

class _FakeSshDebugController implements SshDebugController {
  bool enabled = false;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
    if (value) {
      enableCalls++;
    } else {
      disableCalls++;
    }
  }
}

void main() {
  testWidgets('LAN SSH debug toggle calls controller', (tester) async {
    final ctrl = _FakeSshDebugController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SshDebugDemoSection(controller: ctrl)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('LAN SSH debug'), findsOneWidget);
    expect(ctrl.enabled, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(ctrl.enabled, isTrue);
    expect(ctrl.enableCalls, 1);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(ctrl.enabled, isFalse);
    expect(ctrl.disableCalls, 1);
  });
}
