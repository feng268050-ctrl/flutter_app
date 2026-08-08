import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/ip_camera.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_demo_recording_paths.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_eth0_path.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_mediamtx_relay.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/ip_camera/presentation/ip_camera_preview.dart';
import 'package:lws_hmi/features/settings/presentation/pages/ip_camera_settings_page.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

class _FakePreviewPlayer extends ChangeNotifier implements IpCameraPreviewPlayer {
  @override
  Future<void> initialize() async => notifyListeners();

  @override
  Future<void> play() async {}

  @override
  Future<void> dispose() async => super.dispose();

  @override
  bool get isInitialized => true;

  @override
  double get aspectRatio => 16 / 9;

  @override
  String? get errorDescription => null;

  @override
  Widget buildVideo() => const ColoredBox(color: Colors.green);
}

class _FakeEth implements EthernetController {
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
  EthLinkState get currentLink => const EthLinkState(phase: EthLinkPhase.up);

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

class _FakeWifi implements WifiController {
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
  Future<void> setAutoJoin(String ssid, {required bool enabled}) async {}

  @override
  Future<bool> selectSaved(String ssid) async => false;

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

BoardProfile _testProfile() => BoardProfile.fromJsonString('''
{
  "board_id": "sim",
  "display_name": "sim",
  "capabilities": ["sysInfo", "ethernet"],
  "net_roles": {"ethernet": "eth0"},
  "configs": {},
  "storage_mounts": ["/"],
  "helpers": {}
}
''');

void main() {
  testWidgets(
    'Record shows preparing (not recording) then Stop reports exact path',
    (tester) async {
      final recorder = StubIpCameraRecordingController();
      final camera = StubIpCameraController(
        cameraHost: '192.168.1.100',
        initialPhase: IpCameraHealthPhase.healthy,
        recording: recorder,
      );
      final session = IpCameraProductSession(
        camera: camera,
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

      final services = AppServices(
        boardProfile: _testProfile(),
        sysInfo: StubSysInfo(
          snapshotData: const SysInfoSnapshot(
            serialNumber: 'test-sn',
            kernelRelease: '6.1.0-test',
            appVersion: kHmiVersion,
            memoryTotalBytes: 512 * 1024 * 1024,
            memoryAvailableBytes: 256 * 1024 * 1024,
            uptime: Duration(hours: 1),
            loadAverage: LoadAverage(one: 0.1, five: 0.1, fifteen: 0.1),
            uiFps: 60,
            rasterFps: 60,
            panelRefreshHz: 60,
            thermal: [],
          ),
        ),
        ethernetController: _FakeEth(),
        wifiController: _FakeWifi(),
        ipCamera: session,
      );

      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() async {
        await session.dispose();
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: IpCameraSettingsPage(
            services: services,
            recordingPaths: const IpCameraDemoRecordingPaths(root: '/tmp/Videos'),
            previewPlayerFactory: (_) => _FakePreviewPlayer(),
          ),
        ),
      );

      // Allow _boot() to finish without pumpAndSettle (preview tickers).
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byKey(const Key('ip-camera-record-button')).evaluate().isNotEmpty &&
            tester
                    .widget<HmiButton>(
                      find.byKey(const Key('ip-camera-record-button')),
                    )
                    .onPressed !=
                null) {
          break;
        }
      }

      expect(find.byKey(const Key('ip-camera-record-button')), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ip-camera-record-button')));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (recorder.currentStatus.phase == IpCameraRecordingPhase.preparing) {
          break;
        }
      }

      expect(recorder.currentStatus.phase, IpCameraRecordingPhase.preparing);
      expect(find.text('Waiting For RTSP Stream…'), findsOneWidget);
      expect(find.text('Recording…'), findsNothing);

      recorder.markReady();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (recorder.currentStatus.phase == IpCameraRecordingPhase.recording) {
          break;
        }
      }

      expect(recorder.currentStatus.phase, IpCameraRecordingPhase.recording);
      expect(find.text('Recording…'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ip-camera-record-button')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byKey(const Key('ip-camera-saved-path')).evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.byKey(const Key('ip-camera-saved-path')), findsOneWidget);
      final saved = tester
          .widget<Text>(find.byKey(const Key('ip-camera-saved-path')))
          .data!;
      expect(saved.startsWith('Saved: /tmp/Videos/movie/'), isTrue);
      expect(saved.endsWith('.mp4'), isTrue);

      // Cancel OsWallClock before Flutter's post-test timer invariant.
      services.wallClock.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
