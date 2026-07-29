import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/ip_camera.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_demo_recording_paths.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_eth0_path.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_mediamtx_relay.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/application/record_work_controller.dart';
import 'package:lws_hmi/features/process_video/application/process_video_save_handler.dart';
import 'package:lws_hmi/features/process_video/application/process_video_snapshot_source.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  late Database database;
  late SqliteProcessVideoRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rw-save-');
    database = sqlite3.openInMemory();
    repo = SqliteProcessVideoRepository(database: database);
  });

  tearDown(() async {
    await repo.close();
    await tmp.delete(recursive: true);
  });

  AppServices servicesWith({IpCameraProductSession? ipCamera}) {
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
      modbusClient: _IdleModbus(),
      ipCamera: ipCamera,
    );
  }

  Future<IpCameraProductSession> connectedSession({
    required StubIpCameraRecordingController recording,
  }) async {
    final session = IpCameraProductSession(
      camera: StubIpCameraController(
        cameraHost: '192.168.1.100',
        initialPhase: IpCameraHealthPhase.healthy,
        recording: recording,
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

  test('laser enable starts encode; stop persists snapshot row', () async {
    final recording = StubIpCameraRecordingController(
      autoReadyAfter: Duration.zero,
    );
    final session = await connectedSession(recording: recording);
    addTearDown(session.dispose);

    final paths = IpCameraDemoRecordingPaths(root: '${tmp.path}/Videos');
    final messages = <String>[];
    final snap = ProcessVideoSnapshot(
      processType: ProcessType.continuousWelding,
      materialType: MaterialType.stainlessSteel,
      parameters: ProcessParameters({'process.laser_power': 55}),
      presetUuid: 'preset-1',
    );
    final device = DeviceControlController(servicesWith(ipCamera: session))
      ..keySwitchOn = true
      ..laserEnable = true;
    final record = RecordWorkController(
      deviceControl: device,
      recordingPaths: paths,
      snapshotSource: CallbackProcessVideoSnapshotSource(() => snap),
      saveHandler: ProcessVideoSaveHandler(repository: repo),
      onMessage: messages.add,
    );
    addTearDown(record.dispose);

    await record.start(servicesWith(ipCamera: session));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(recording.currentStatus.phase, IpCameraRecordingPhase.recording);
    final out = recording.currentStatus.outputPath;
    expect(out, isNotNull);
    await File(out!).writeAsBytes(List<int>.filled(256, 7));

    // Keep recording ≥1s wall time for duration gate.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await record.setArmed(false);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(await repo.count(), 1);
    final row = (await repo.list()).single;
    expect(row.videoPath, out);
    expect(row.processType, ProcessType.continuousWelding);
    expect(row.materialType, MaterialType.stainlessSteel);
    expect(row.snapshot?.presetUuid, 'preset-1');
    expect(messages, isEmpty);
  });

  test('too-short recording is discarded with message', () async {
    final recording = StubIpCameraRecordingController(
      autoReadyAfter: Duration.zero,
    );
    final session = await connectedSession(recording: recording);
    addTearDown(session.dispose);

    final paths = IpCameraDemoRecordingPaths(root: '${tmp.path}/Videos');
    final messages = <String>[];
    final snap = ProcessVideoSnapshot(
      processType: ProcessType.spotWelding,
      parameters: ProcessParameters({'process.laser_power': 20}),
    );
    final device = DeviceControlController(servicesWith(ipCamera: session))
      ..keySwitchOn = true
      ..laserEnable = true;
    final record = RecordWorkController(
      deviceControl: device,
      recordingPaths: paths,
      snapshotSource: CallbackProcessVideoSnapshotSource(() => snap),
      saveHandler: ProcessVideoSaveHandler(repository: repo),
      onMessage: messages.add,
    );
    addTearDown(record.dispose);

    await record.start(servicesWith(ipCamera: session));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final out = recording.currentStatus.outputPath!;
    await File(out).writeAsBytes(List<int>.filled(64, 1));

    await record.setArmed(false);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(await repo.count(), 0);
    expect(messages, contains('Recording too short — not saved'));
  });

  test('no insert when snapshot source missing', () async {
    final recording = StubIpCameraRecordingController(
      autoReadyAfter: Duration.zero,
    );
    final session = await connectedSession(recording: recording);
    addTearDown(session.dispose);

    final paths = IpCameraDemoRecordingPaths(root: '${tmp.path}/Videos');
    final device = DeviceControlController(servicesWith(ipCamera: session))
      ..keySwitchOn = true
      ..laserEnable = true;
    final record = RecordWorkController(
      deviceControl: device,
      recordingPaths: paths,
      saveHandler: ProcessVideoSaveHandler(repository: repo),
    );
    addTearDown(record.dispose);

    await record.start(servicesWith(ipCamera: session));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final out = recording.currentStatus.outputPath!;
    await File(out).writeAsBytes(List<int>.filled(128, 2));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await record.stopRecordingForExit();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await repo.count(), 0);
  });
}

final class _IdleModbus extends ModbusRtuClient {
  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeAttribute(String id, Object? value) async => true;

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
