import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/ssh/ssh_debug_controller.dart';
import 'package:lws_hmi/platform/usb/usb_debug_controller.dart';
import 'package:lws_hmi/ui/demo/debug_demo_section.dart';

class _FakeUsbDebug implements UsbDebugController {
  bool enabled = true;
  int setCalls = 0;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
    setCalls++;
  }
}

class _FakeLanDebug implements SshDebugController {
  bool enabled = false;
  int setCalls = 0;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
    setCalls++;
  }
}

void main() {
  testWidgets('Debug group toggles USB and LAN controllers', (tester) async {
    final usb = _FakeUsbDebug();
    final lan = _FakeLanDebug();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DebugDemoSection(usbDebug: usb, lanDebug: lan),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Debug'), findsOneWidget);
    expect(find.text('Debug over USB'), findsOneWidget);
    expect(find.text('Debug over LAN'), findsOneWidget);
    expect(usb.enabled, isTrue);
    expect(lan.enabled, isFalse);

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));

    await tester.tap(switches.at(0));
    await tester.pumpAndSettle();
    expect(usb.enabled, isFalse);
    expect(usb.setCalls, 1);

    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(lan.enabled, isTrue);
    expect(lan.setCalls, 1);
  });
}
