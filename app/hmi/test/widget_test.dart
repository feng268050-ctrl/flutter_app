import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/device/device_sn_reader.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/ui/demo/p2_demo_page.dart';

class _FakeSnReader extends DeviceSnReader {
  const _FakeSnReader() : super();

  @override
  Future<String> read() async => 'test-sn';
}

class _OfflineModbus extends ModbusRtuClient {
  _OfflineModbus() : super();

  @override
  Future<bool> open() async => false;

  @override
  Future<ModbusDeviceInfoSnapshot> readDeviceInfo() async {
    return ModbusDeviceInfoSnapshot.unavailable;
  }

  @override
  Future<ModbusAlarmTemperaturesSnapshot> readAlarmTemperatures() async {
    return ModbusAlarmTemperaturesSnapshot.unavailable;
  }
}

void main() {
  testWidgets('shows P2 device information labels', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: P2DemoPage(
          deviceSnReader: const _FakeSnReader(),
          modbusClient: _OfflineModbus(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Device SN:'), findsOneWidget);
    expect(find.textContaining('Gunhead SN: $kUnavailableDisplay'), findsOneWidget);
    expect(find.text('Alarm Information'), findsOneWidget);
    expect(find.textContaining('Motor Temperature:'), findsOneWidget);
    expect(find.textContaining('Collimator Temperature:'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('RGB LED'), 200);
    expect(find.text('Steady'), findsWidgets);
    expect(find.text('Blink'), findsWidgets);
    expect(find.text('Off'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Speaker'), 200);
    expect(find.text('Play'), findsOneWidget);
    expect(find.textContaining('Volume:'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Portrait'), 300);
    expect(find.text('Portrait'), findsOneWidget);
    expect(find.text('Landscape'), findsOneWidget);
    expect(find.textContaining('Brightness:'), findsOneWidget);
    expect(find.textContaining('Volume:'), findsWidgets);
  });

  testWidgets('app demo shows Device Information title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: P2DemoPage(
          deviceSnReader: const _FakeSnReader(),
          modbusClient: _OfflineModbus(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Device Information'), findsOneWidget);
  });
}
