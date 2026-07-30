import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Wi‑Fi icon hidden when phase hidden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberWifiStatusIcon(phase: CyberConnectivityIconPhase.hidden),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('cyber-status-wifi')), findsNothing);
  });

  testWidgets('Wi‑Fi icon shows connected bars', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberWifiStatusIcon(
            phase: CyberConnectivityIconPhase.connected,
            signalDbm: -50,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('cyber-status-wifi')), findsOneWidget);
    expect(find.byType(CyberWifiSignalBars), findsOneWidget);
  });

  testWidgets('Cloud icon dim when not linked', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberCloudStatusIcon(linked: false),
        ),
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.cloud));
    expect(icon.color, Colors.white54);
  });

  testWidgets('Cloud icon lit when linked', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberCloudStatusIcon(linked: true),
        ),
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.cloud));
    expect(icon.color, Colors.white);
  });

  testWidgets('Bluetooth connected glyph', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberBluetoothStatusIcon(
            phase: CyberConnectivityIconPhase.connected,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('cyber-status-bt')), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth_connected), findsOneWidget);
  });

  testWidgets('Camera failed shows cancel mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberCameraStatusIcon(status: CyberCameraLinkStatus.failed),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('cyber-status-camera')), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  test('cyberWifiSignalBarsFromDbm thresholds', () {
    expect(cyberWifiSignalBarsFromDbm(null, linked: false), 0);
    expect(cyberWifiSignalBarsFromDbm(null, linked: true), 4);
    expect(cyberWifiSignalBarsFromDbm(-50, linked: true), 4);
    expect(cyberWifiSignalBarsFromDbm(-60, linked: true), 3);
    expect(cyberWifiSignalBarsFromDbm(-70, linked: true), 2);
    expect(cyberWifiSignalBarsFromDbm(-80, linked: true), 1);
  });
}
