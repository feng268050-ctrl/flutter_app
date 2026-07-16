import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/input/mouse_settings.dart';
import 'package:lws_hmi/platform/input/usb_hid_mouse_probe.dart';
import 'package:lws_hmi/ui/demo/mouse_demo_section.dart';

class _FakeMouseSettings implements MouseSettingsController {
  MouseSettings settings = MouseSettings.defaults();
  int setCalls = 0;

  @override
  Future<MouseSettings> getSettings() async => settings;

  @override
  Future<void> setSettings(MouseSettings value) async {
    settings = value;
    setCalls++;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeProbe extends UsbHidMouseProbe {
  const _FakeProbe();

  @override
  Future<String> statusLine() async => 'detected: fake-mouse';
}

void main() {
  testWidgets('Mouse section loads and toggles natural scroll', (tester) async {
    final controller = _FakeMouseSettings();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MouseDemoSection(
              probe: const _FakeProbe(),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('USB mouse'), findsOneWidget);
    expect(find.text('detected: fake-mouse'), findsOneWidget);
    expect(find.text('Natural scrolling'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(controller.setCalls, 1);
    expect(controller.settings.naturalScroll, isTrue);
  });
}
