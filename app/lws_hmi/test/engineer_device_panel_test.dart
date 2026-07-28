import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/ip_camera.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_eth0_path.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_mediamtx_relay.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/application/record_work_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_device_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/manual_wire_gesture.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(ProcessModeToast.resetForTest);

  AppServices servicesWith(
    ModbusRtuClient modbus, {
    IpCameraProductSession? ipCamera,
  }) {
    return AppServices(
      boardProfile: BoardProfile.fromJsonString('''
{
  "schema_version": 1,
  "board_id": "test",
  "display_name": "Test",
  "bindings": {"sys_info": "stub"}
}
'''),
      sysInfo: StubSysInfo(),
      modbusClient: modbus,
      ipCamera: ipCamera,
    );
  }

  ProcessPreset presetFor(ProcessType type) => ProcessPreset(
        uuid: 'p-$type',
        name: 'P',
        kind: ProcessPresetKind.engineerPreset,
        source: 'test',
        isBuiltin: true,
        processType: type,
        materialType: MaterialType.stainlessSteel,
        thickness: 1,
        gear: 1,
        parameters: ProcessParameters({}),
        createdAtMs: 1,
        updatedAtMs: 1,
      );

  Future<IpCameraProductSession> connectedCameraSession() async {
    final session = IpCameraProductSession(
      camera: StubIpCameraController(
        cameraHost: '192.168.1.100',
        initialPhase: IpCameraHealthPhase.healthy,
        recording: StubIpCameraRecordingController(
          autoReadyAfter: Duration.zero,
        ),
      ),
      ethernet: _FakeEth(),
      wifi: _FakeWifi(),
      eth0Path: StubIpCameraEth0Path(ok: true, pingOk: true),
      relay: StubIpCameraMediaMtxRelay(),
      attemptBudget: 2,
      eventDebounce: Duration.zero,
      failedRetryInterval: const Duration(days: 1),
    );
    final connected = session.status.firstWhere(
      (s) => s.phase == IpCameraUiPhase.connected,
    );
    await session.start();
    await connected.timeout(const Duration(seconds: 5));
    return session;
  }

  testWidgets('continuous weld enables Auto Wire / Feed / Retract',
      (tester) async {
    addTearDown(ProcessModeToast.resetForTest);
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus))
      ..keySwitchOn = true
      ..autoWireFeed = false;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: EngineerDevicePanel(
              controller: controller,
              recordWork: RecordWorkController(deviceControl: controller),
              processType: ProcessType.continuousWelding,
              preset: presetFor(ProcessType.continuousWelding),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('engineer-panel-auto-wire')));
    await tester.pump();
    expect(controller.autoWireFeed, isTrue);
    expect(
      modbus.writes.any((e) => e.$1 == DeviceControlIds.wireManualMode),
      isTrue,
    );

    expect(find.byKey(const ValueKey('engineer-panel-feed')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('engineer-panel-retract')), findsOneWidget);
    ProcessModeToast.resetForTest();
  });

  testWidgets('spot welding greys Auto Wire / Feed / Retract', (tester) async {
    final controller =
        DeviceControlController(servicesWith(_RecordingModbus()))
          ..keySwitchOn = true
          ..autoWireFeed = false;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessModeToastLayer(
          child: Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: EngineerDevicePanel(
                controller: controller,
                recordWork: RecordWorkController(deviceControl: controller),
                processType: ProcessType.spotWelding,
                preset: presetFor(ProcessType.spotWelding),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('engineer-panel-auto-wire')));
    await tester.pump();
    expect(controller.autoWireFeed, isFalse);
    expect(find.text('Wire feed unavailable in this mode'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('engineer-panel-feed')));
    await tester.pump();
    expect(controller.wireWork, isFalse);
    expect(find.text('Wire feed unavailable in this mode'), findsNothing);
  });

  testWidgets('Record Work enables when camera is connected', (tester) async {
    final session = await connectedCameraSession();
    addTearDown(session.dispose);
    final services = servicesWith(_RecordingModbus(), ipCamera: session);
    final controller = DeviceControlController(services)..keySwitchOn = true;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: EngineerDevicePanel(
                controller: controller,
              recordWork: RecordWorkController(deviceControl: controller),
                processType: ProcessType.continuousWelding,
                preset: presetFor(ProcessType.continuousWelding),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final record = find.byKey(const ValueKey('engineer-panel-record-work'));
    expect(record, findsOneWidget);
    // Product default: armed when camera is connected.
    expect(
      find.descendant(
        of: record,
        matching: find.byWidgetPredicate(
          (w) => w is CyberCheckbox && w.value == true,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Record Work stays disabled without camera', (tester) async {
    final controller =
        DeviceControlController(servicesWith(_RecordingModbus()))
          ..keySwitchOn = true;
    final record = RecordWorkController(deviceControl: controller);
    addTearDown(record.dispose);
    await record.start(null);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: EngineerDevicePanel(
              controller: controller,
              recordWork: record,
              processType: ProcessType.continuousWelding,
              preset: presetFor(ProcessType.continuousWelding),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('engineer-panel-record-work')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('engineer-panel-record-work')),
        matching: find.byWidgetPredicate(
          (w) => w is CyberCheckbox && w.value == true,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('left panel checkboxes use standard green fill', (tester) async {
    final controller =
        DeviceControlController(servicesWith(_RecordingModbus()))
          ..keySwitchOn = true;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: EngineerDevicePanel(
              controller: controller,
              recordWork: RecordWorkController(deviceControl: controller),
              processType: ProcessType.continuousWelding,
              preset: presetFor(ProcessType.continuousWelding),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CyberCheckbox), findsWidgets);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(checkbox.activeColor, const Color(0xFF34C759));
  });

  test('ManualWireGesture short press pulses wire work', () {
    fakeAsync((async) {
      final modbus = _RecordingModbus();
      final controller = DeviceControlController(servicesWith(modbus))
        ..keySwitchOn = true;
      final gesture = ManualWireGesture(
        controller: controller,
        retract: false,
        isEnabled: () => true,
        isActive: () => false,
        onMessage: (_) {},
        onVisualChanged: () {},
      );

      gesture.pointerDown();
      gesture.pointerUp();
      async.flushMicrotasks();
      async.elapse(DeviceControlTiming.wirePulseDuration);
      async.flushMicrotasks();

      final wireWrites = modbus.writes
          .where((e) => e.$1 == DeviceControlIds.wireWork)
          .map((e) => e.$2)
          .toList();
      expect(wireWrites, containsAllInOrder([true, false]));
      gesture.dispose();
    });
  });
}

final class _RecordingModbus extends ModbusRtuClient {
  final writes = <(String, Object?)>[];

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    writes.add((id, value));
    return true;
  }

  @override
  Future<Map<String, Object?>> readGroup(String group) async => {};

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}

final class _FakeEth implements EthernetController {
  final _link = StreamController<EthLinkState>.broadcast();

  @override
  String get interfaceName => 'eth0';

  @override
  Stream<EthAdminState> get admin => const Stream.empty();

  @override
  Stream<EthLinkState> get link => _link.stream;

  @override
  EthAdminState get currentAdmin => EthAdminState.on;

  @override
  EthLinkState get currentLink =>
      const EthLinkState(phase: EthLinkPhase.up, ipv4: '192.168.1.234');

  @override
  Future<void> setInterfaceEnabled(bool enabled) async {}

  @override
  Future<EthIpv4Config> getIpv4Config() async => EthIpv4Config.dhcpDefault;

  @override
  Future<void> setIpv4Config(EthIpv4Config config) async {}

  @override
  Future<EthLinkState> linkDetails() async => currentLink;

  @override
  Future<void> syncFromSystem() async {}

  @override
  Future<void> dispose() => _link.close();
}

final class _FakeWifi implements WifiController {
  @override
  Stream<WifiRadioState> get radio => const Stream.empty();

  @override
  Stream<WifiConnectionState> get connection => const Stream.empty();

  @override
  String get interfaceName => 'wlan0';

  @override
  WifiRadioState get currentRadio => WifiRadioState.off;

  @override
  WifiConnectionState get currentConnection => WifiConnectionState.disconnected;

  @override
  Future<void> setRadioEnabled(bool enabled) async {}

  @override
  Future<List<WifiAccessPoint>> scan(
          {Duration timeout = const Duration(seconds: 8)}) async =>
      const [];

  @override
  Future<void> connect({
    required String ssid,
    String? psk,
    String? bssid,
    bool hidden = false,
    bool requiresPsk = false,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> forget(String ssid) async {}

  @override
  Future<List<WifiSavedNetwork>> savedNetworks() async => const [];

  @override
  Future<WlanIpv4Config> getIpv4Config() async => WlanIpv4Config.dhcpDefault;

  @override
  Future<void> setIpv4Config(WlanIpv4Config config) async {}

  @override
  Future<WifiConnectionState> linkDetails() async => currentConnection;

  @override
  Future<void> syncFromSystem() async {}

  @override
  Future<void> dispose() async {}
}
