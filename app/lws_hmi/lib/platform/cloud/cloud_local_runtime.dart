import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_demo_recording_paths.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:cyber_hal/ip_camera.dart';
import 'package:lws_hmi/features/process_library/application/engineer_preset_deriver.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_store.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';
import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';
import 'package:lws_hmi/platform/cloud/device_ai_report_client.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_prober.dart';
import 'package:lws_hmi/platform/cloud/device_r2_put_object_client.dart';
import 'package:lws_hmi/platform/cloud/device_r2_sts_client.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';
import 'package:lws_hmi/platform/cloud/device_remote_snapshot.dart';
import 'package:lws_hmi/platform/cloud/device_remote_snapshot_modbus_mapper.dart';
import 'package:lws_hmi/platform/cloud/device_users_client.dart';
import 'package:lws_hmi/platform/cloud/device_video_metadata_client.dart';
import 'package:lws_hmi/platform/cloud/device_ws_connection_manager.dart';
import 'package:lws_hmi/platform/cloud/device_ws_dispatcher.dart';
import 'package:lws_hmi/platform/cloud/device_ws_envelope.dart';
import 'package:lws_hmi/platform/cloud/process_parameters_cloud_codec.dart';
import 'package:lws_hmi/platform/cloud/process_parameters_snapshot_store.dart';
import 'package:lws_hmi/platform/cloud/device_remote_live_cache.dart';
import 'package:lws_hmi/platform/datetime/date_time_controller.dart';
import 'package:lws_hmi/platform/local_http/device_local_http_server.dart';
import 'package:lws_hmi/platform/local_http/monitor_alerts_sse_hub.dart';
import 'package:lws_hmi/platform/local_http/monitor_stat_sse_hub.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/sqlite_alarm_log_repository.dart';
import 'package:lws_hmi/platform/mdns/device_mdns_advertise.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

/// Post–first-frame cloud + LAN orchestrator (probe → WS, local HTTP, mDNS).
final class CloudLocalRuntime {
  CloudLocalRuntime({
    required this.services,
    required this.cloudSettings,
    required this.lockStore,
    this.processLibrary,
    this.processVideoRepository,
    this.commonSettings,
    this.miscSettings,
    this.soundEffectStore,
    this.warnLogQuery,
    this.cameraVersionFetch,
  }) {
    cloudHttp = CloudHttpClient(http: services.http);
    prober = DeviceApiOriginProber(http: services.http);
    usersClient = DeviceUsersClient(cloudHttp: cloudHttp);
    r2StsClient = DeviceR2StsClient(cloudHttp: cloudHttp);
    r2PutClient = DeviceR2PutObjectClient(cloudHttp: cloudHttp);
    videoMetadataClient = DeviceVideoMetadataClient(cloudHttp: cloudHttp);
    aiReportClient = DeviceAiReportClient(cloudHttp: cloudHttp);
    snapshotPacker = DeviceRemoteSnapshotPacker(lockStore: lockStore);
    ws = DeviceWsConnectionManager(
      cloudHttp: cloudHttp,
      onAuthError: _notifyRegistrationNeeded,
      onStateChanged: (s) {
        if (s == DeviceWsState.connected) {
          _clearRegistrationPromptLatch();
          unawaited(_onWsConnected());
        }
      },
    );
    dispatcher = DeviceWsDispatcher(
      ws: ws,
      lockStore: lockStore,
      snapshotPacker: snapshotPacker,
      snapshotLoader: _loadSnapshot,
    );
    ws.onMessage = dispatcher.handle;
    monitorStatHub = MonitorStatSseHub();
    monitorAlertsHub = MonitorAlertsSseHub(
      listSupplier: () async {
        final query = warnLogQuery;
        if (query == null) {
          return const <Object?>[];
        }
        try {
          final rows = await query(limit: MonitorAlertsSseHub.listLimit);
          return DeviceRemoteSnapshotModbusMapper.warnsFromAlarmLogs(rows);
        } catch (e) {
          debugPrint('local-http: alerts load failed: $e');
          return const <Object?>[];
        }
      },
    );
    liveCache = DeviceRemoteLiveCache(
      services: services,
      statHub: monitorStatHub,
    );
    monitorStatHub.snapshotSupplier = liveCache.currentSnapshot;
    localHttp = DeviceLocalHttpServer(
      processVideoRepository: processVideoRepository,
      processLibrary: processLibrary,
      sshDebug: services.sshDebug,
      monitorStatHub: monitorStatHub,
      monitorAlertsHub: monitorAlertsHub,
    );
    mdns = DeviceMdnsAdvertise();
    _wireLocalHttpHandlers();
    _installDefaultHandlers();
  }

  final AppServices services;
  final CloudSettingsStore cloudSettings;
  final DeviceRemoteLockStore lockStore;
  final ProcessLibraryController? processLibrary;
  final ProcessVideoRepository? processVideoRepository;
  final CommonSettingsStore? commonSettings;
  final MiscSettingsStore? miscSettings;
  final SoundEffectStore? soundEffectStore;

  /// Newest-first alarm history for `warns` (lws-ui WarnTable list).
  final Future<List<AlarmLogEntry>> Function({int? limit})? warnLogQuery;

  /// Optional camera version lookup (`GET …/System/deviceinfo`).
  final Future<String> Function(String cameraHost)? cameraVersionFetch;

  late final CloudHttpClient cloudHttp;
  late final DeviceApiOriginProber prober;
  late final DeviceUsersClient usersClient;
  late final DeviceR2StsClient r2StsClient;
  late final DeviceR2PutObjectClient r2PutClient;
  late final DeviceVideoMetadataClient videoMetadataClient;
  late final DeviceAiReportClient aiReportClient;
  late final DeviceRemoteSnapshotPacker snapshotPacker;
  late final DeviceWsConnectionManager ws;
  late final DeviceWsDispatcher dispatcher;
  late final MonitorStatSseHub monitorStatHub;
  late final MonitorAlertsSseHub monitorAlertsHub;
  late final DeviceRemoteLiveCache liveCache;
  late final DeviceLocalHttpServer localHttp;
  late final DeviceMdnsAdvertise mdns;

  void Function()? onAuthError;
  void Function(DeviceUsersProbeResult result)? onUsersProbe;
  Future<bool> Function()? onClearAlerts;
  Future<void> Function(bool locked)? onRemoteLockChanged;
  Future<void> Function(String reason)? onForcedDisconnect;

  bool _started = false;
  bool _originPinned = false;
  bool _linkInFlight = false;
  /// Dedupes registration prompt when users 401 and WS auth fail race.
  bool _registrationPromptNotified = false;
  /// Request another probe as soon as the in-flight attempt finishes.
  bool _linkFollowUpPending = false;
  StreamSubscription<WifiConnectionState>? _wifiWaitSub;
  StreamSubscription<WifiConnectionState>? _mdnsWifiSub;
  /// Short retries measured from Wi‑Fi-up / probe-miss (not from first frame).
  final List<Timer> _postWifiLinkTimers = <Timer>[];
  Timer? _linkFollowUpTimer;

  void _wireLocalHttpHandlers() {
    localHttp.cameraAiAvailable = () async => false;
    localHttp.cameraShowOverlayHandler = null;
    localHttp.cameraRecordHandler = (switchValue) async {
      try {
        final session = await services.ensureIpCamera();
        final recorder = session.camera.recording;
        if (switchValue == 'on') {
          if (recorder.currentStatus.isActive) {
            return LocalHttpCameraActionResult.fail(
              'recording_in_progress',
              httpStatus: HttpStatus.conflict,
            );
          }
          final source = session.previewPr0;
          if (source == null) {
            return LocalHttpCameraActionResult.fail(
              'camera_unavailable',
              httpStatus: HttpStatus.serviceUnavailable,
            );
          }
          final path = const IpCameraDemoRecordingPaths().nextMp4Path();
          await Directory(File(path).parent.path).create(recursive: true);
          final status = await recorder.start(
            IpCameraRecordingRequest(
              sourceCandidates: [source],
              outputPath: path,
              codec: IpCameraVideoCodec.h264,
            ),
          );
          if (status.phase == IpCameraRecordingPhase.failed) {
            return LocalHttpCameraActionResult.fail(
              status.detail ?? 'record_failed',
              httpStatus: HttpStatus.internalServerError,
            );
          }
          return LocalHttpCameraActionResult.success(
            data: {'switch': 'on'},
          );
        }
        // off
        if (!recorder.currentStatus.isActive) {
          return LocalHttpCameraActionResult.success(
            data: {'switch': 'off'},
          );
        }
        await recorder.stop();
        return LocalHttpCameraActionResult.success(
          data: {'switch': 'off'},
        );
      } catch (e) {
        debugPrint('local-http: camera record failed: $e');
        return LocalHttpCameraActionResult.fail(
          'camera_unavailable',
          httpStatus: HttpStatus.serviceUnavailable,
        );
      }
    };
  }

  void _installDefaultHandlers() {
    dispatcher.onClearAlerts = () async => await onClearAlerts?.call() ?? false;

    dispatcher.onLockSafetyStop = _applyRemoteLockSafetyStop;
    dispatcher.onRemoteLockChanged = (locked) async {
      await onRemoteLockChanged?.call(locked);
    };
    dispatcher.onForcedDisconnect = (reason) async {
      await onForcedDisconnect?.call(reason);
    };

    dispatcher.onProcessParam = _importCloudProcessParam;
    dispatcher.onProcessLib = _importCloudProcessLib;

    dispatcher.onVideoListRequest = _handleVideoListRequest;
    dispatcher.onUploadVideo = _handleUploadVideo;
    dispatcher.onDeleteVideo = _handleDeleteVideo;

    dispatcher.onProcessLibraryRequest = _handleProcessLibraryRequest;
    dispatcher.onProcessParametersRequest = _handleProcessParametersRequest;
    dispatcher.onProcessParametersCreate = _handleProcessParametersCreate;
    dispatcher.onProcessParametersUpdate = _handleProcessParametersUpdate;
    dispatcher.onProcessParametersDelete = _handleProcessParametersDelete;
    dispatcher.onProcessParametersSetDefault =
        _handleProcessParametersSetDefault;
  }

  Future<void> _applyRemoteLockSafetyStop() async {
    try {
      await services.ensureModbusLive();
      await services.modbus.exclusiveSession(() async {
        final raw =
            await services.modbus.readAttribute(DeviceControlIds.controlField1);
        final word = switch (raw) {
          int i => i,
          num n => n.toInt(),
          _ => 0,
        };
        final next = word & ~DeviceControlIds.controlField1JobBitsMask & 0xFFFF;
        return services.modbus.writeAttribute(
          DeviceControlIds.controlField1,
          next,
        );
      });
    } catch (e) {
      debugPrint('cloud-runtime: remote lock safety stop failed: $e');
    }
  }

  Future<String?> _importCloudProcessParam(Object? payload) async {
    final library = processLibrary;
    if (library == null) {
      return 'process_library_unavailable';
    }
    final data = ProcessParametersCloudCodec.unwrapParamPayload(payload);
    if (data == null) {
      return 'invalid_process_param_payload';
    }
    try {
      await library.initialize();
      final preset = ProcessParametersCloudCodec.presetFromCloud(
        data,
        kind: ProcessPresetKind.user,
        source: 'cloud',
        isBuiltin: false,
        uuid: _newUuid(),
      );
      ProcessParameterValidator.validate(preset);
      await library.saveUser(preset);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> _importCloudProcessLib(Object? payload) async {
    final library = processLibrary;
    if (library == null) {
      return 'process_library_unavailable';
    }
    final lib = ProcessParametersCloudCodec.unwrapLibPayload(payload);
    if (lib == null || lib.dataList.isEmpty) {
      return 'invalid_process_lib_payload';
    }
    try {
      await library.initialize();
      final version = '${lib.versionCode ?? 0}';
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final quick = <ProcessPreset>[];
      for (var i = 0; i < lib.dataList.length; i++) {
        final row = lib.dataList[i];
        quick.add(
          ProcessParametersCloudCodec.presetFromCloud(
            row,
            kind: ProcessPresetKind.quick,
            source: 'cloud',
            isBuiltin: true,
            uuid: 'cloud-$version-$i',
            libraryVersion: version,
            nowMs: now,
          ),
        );
      }
      final presets = EngineerPresetDeriver.withDerivedEngineerPresets(
        quick,
        libraryVersion: version,
        nowMs: now,
      );
      final digest = sha256.convert(utf8.encode(jsonEncode(lib.dataList)));
      await library.repository.replaceBuiltins(
        source: 'cloud',
        wipeAllBuiltinSources: true,
        meta: ProcessLibraryMeta(
          source: 'cloud',
          libraryVersion: version,
          schemaVersion: 1,
          contentSha256: digest.toString(),
          installedAtMs: now,
          rowCount: presets.length,
        ),
        presets: presets,
      );
      await library.reloadPresets();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Idempotent post–first-frame start.
  Future<void> startAfterFirstFrame() async {
    if (_started) {
      return;
    }
    _started = true;
    cloudSettings.warmRead();
    lockStore.warmRead();
    commonSettings?.warmRead();
    miscSettings?.warmRead();

    final httpOk = await localHttp.start();
    if (httpOk) {
      await _publishMdns();
    }
    _armMdnsWifiWatch();

    unawaited(liveCache.start());

    // Cloud HTTP/WS need uplink DNS + route — wait for Wi‑Fi (or link now if
    // already connected). Do not probe origins while radio/IP is down.
    _armCloudLinkRetries();
  }

  /// Wire SQLite alarm log → alerts SSE `new` / `clear`.
  void attachAlarmLog(SqliteAlarmLogRepository log) {
    log.onWarnInserted = (entry) {
      monitorAlertsHub.publishNew(
        DeviceRemoteSnapshotModbusMapper.warnTableFromAlarmLog(entry),
      );
    };
    log.onWarnCleared = monitorAlertsHub.publishClear;
  }

  Future<void> refreshUsersBindingProbe({
    bool notifyAuthError = true,
  }) async {
    var pin = prober.pinnedBase;
    pin ??= await prober.probe(cloudSettings.environmentTier);
    if (pin == null) {
      debugPrint('cloud-runtime: refresh users — no API origin');
      _armCloudLinkRetries();
      return;
    }
    _originPinned = true;
    final product = await services.ensureProductInfo();
    final sn = product.sn.trim();
    if (sn.isEmpty) {
      debugPrint('cloud-runtime: refresh users — empty sn');
      return;
    }
    await _emitUsersProbe(
      pin,
      sn,
      notifyAuthError: notifyAuthError,
      resumeWsIfOk: true,
    );
  }

  Future<void> reprobeAndReconnect() async {
    await ws.disconnect();
    prober.clearPin();
    _originPinned = false;
    _clearRegistrationPromptLatch();
    final pin = await prober.probe(cloudSettings.environmentTier);
    if (pin == null) {
      debugPrint('cloud-runtime: reprobe — no API origin; resume last WS URL');
      await ws.reconnectClearingAuthLatch();
      _armCloudLinkRetries();
      return;
    }
    _originPinned = true;
    _cancelCloudLinkRetries();
    final product = await services.ensureProductInfo();
    final sn = product.sn.trim().isEmpty ? 'UNKNOWN' : product.sn.trim();
    if (sn != 'UNKNOWN') {
      await _emitUsersProbe(
        pin,
        sn,
        notifyAuthError: true,
        resumeWsIfOk: false,
      );
    }
    if (ws.state != DeviceWsState.connected) {
      await ws.connect(
        DeviceApiOriginConfig.deviceWebSocketUri(
          pinnedHttpBase: pin,
          deviceSn: sn,
        ),
        resumeAfterAuth: true,
      );
    }
  }

  Future<void> _ensureCloudLinked({required String reason}) async {
    final wifiPhase = services.wifi.currentConnection.phase;
    if (wifiPhase != WifiConnectionPhase.connected) {
      return;
    }
    if (_originPinned || _linkInFlight) {
      if (!_originPinned) {
        _linkFollowUpPending = true;
      }
      return;
    }
    _linkInFlight = true;
    try {
      debugPrint('cloud-runtime: ensure link ($reason)');
      await _ensureClockForCloud(reason: reason);
      final pin = await prober.probe(cloudSettings.environmentTier);
      if (pin == null) {
        debugPrint('cloud-runtime: no API origin pinned');
        // Wi‑Fi may report connected before DNS/default route is ready; do not
        // wait for boot-scoped 3/8/20/45s timers — retry from this moment.
        if (services.wifi.currentConnection.phase ==
            WifiConnectionPhase.connected) {
          _linkFollowUpPending = true;
          _armPostWifiLinkRetries(why: 'probe-miss:$reason');
        }
        return;
      }
      _originPinned = true;
      _linkFollowUpPending = false;
      _cancelCloudLinkRetries();
      _cancelPostWifiLinkRetries();
      _linkFollowUpTimer?.cancel();
      _linkFollowUpTimer = null;
      debugPrint('cloud-runtime: pinned $pin');
      final product = await services.ensureProductInfo();
      final sn = product.sn.trim();
      debugPrint('cloud-runtime: device sn="$sn" (chipId=${product.chipId})');
      final wsUrl = DeviceApiOriginConfig.deviceWebSocketUri(
        pinnedHttpBase: pin,
        deviceSn: sn.isEmpty ? 'UNKNOWN' : sn,
      );

      // Origin pin is enough to open WS; users binding runs in parallel so a
      // slow GET /users does not delay device.online / live channel.
      final futures = <Future<void>>[];
      if (ws.state != DeviceWsState.connected) {
        debugPrint('cloud-runtime: connecting ws $wsUrl');
        futures.add(() async {
          await ws.connect(wsUrl);
        }());
      }
      if (sn.isNotEmpty) {
        futures.add(() async {
          await _emitUsersProbe(
            pin,
            sn,
            notifyAuthError: true,
            resumeWsIfOk: false,
          );
        }());
      } else {
        debugPrint('cloud-runtime: empty sn — skip users probe');
      }
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
    } catch (e) {
      debugPrint('cloud-runtime: ensure link failed: $e');
      _originPinned = false;
      if (services.wifi.currentConnection.phase ==
          WifiConnectionPhase.connected) {
        _linkFollowUpPending = true;
      }
    } finally {
      _linkInFlight = false;
      _scheduleLinkFollowUpIfNeeded();
    }
  }

  void _scheduleLinkFollowUpIfNeeded() {
    if (_originPinned || !_linkFollowUpPending) {
      return;
    }
    if (services.wifi.currentConnection.phase !=
        WifiConnectionPhase.connected) {
      _linkFollowUpPending = false;
      return;
    }
    _linkFollowUpPending = false;
    _linkFollowUpTimer?.cancel();
    // Brief gap so DNS/default-route can settle after a failed probe.
    _linkFollowUpTimer = Timer(const Duration(milliseconds: 400), () {
      if (_originPinned || _linkInFlight) {
        if (!_originPinned) {
          _linkFollowUpPending = true;
        }
        return;
      }
      if (services.wifi.currentConnection.phase !=
          WifiConnectionPhase.connected) {
        return;
      }
      unawaited(_ensureCloudLinked(reason: 'wifi-followup'));
    });
  }

  /// HTTPS / WSS need a sane wall clock (RTC often boots in 2024). Sync before
  /// origin probe so we do not burn fail-fast rounds on TLS/DNS while time is
  /// still wrong — especially right after Wi‑Fi comes up.
  Future<void> _ensureClockForCloud({required String reason}) async {
    final before = DateTime.now().toUtc();
    if (TimeSyncPrefs.isSaneUtcYear(before.year)) {
      return;
    }
    try {
      await services.dateTime.ensureSaneForTls();
    } catch (e) {
      debugPrint('cloud-runtime: clock sync failed: $e');
    }
  }

  void _armCloudLinkRetries() {
    if (_originPinned) {
      return;
    }
    _wifiWaitSub ??= services.wifi.connection.listen((state) {
      if (state.phase == WifiConnectionPhase.connected) {
        // Arm short retries from Wi‑Fi-up even if the immediate probe races
        // DNS and fails with a full timeout.
        _linkFollowUpPending = true;
        _armPostWifiLinkRetries(why: 'wifi-connected');
        unawaited(_ensureCloudLinked(reason: 'wifi-connected'));
      }
    });
    if (services.wifi.currentConnection.phase ==
        WifiConnectionPhase.connected) {
      _armPostWifiLinkRetries(why: 'wifi-already');
      unawaited(_ensureCloudLinked(reason: 'wifi-already'));
    }
    // No boot-clock retries: probing without Wi‑Fi only burns DNS failures.
    // Retries are armed from Wi‑Fi-up / probe-miss via [_armPostWifiLinkRetries].
  }

  void _cancelCloudLinkRetries() {
    final sub = _wifiWaitSub;
    _wifiWaitSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
  }

  /// Event-driven retries after Wi‑Fi is up (or after a probe miss while up).
  ///
  /// Boot timers are anchored at first frame; if Wi‑Fi connects at ~8s and the
  /// first probe times out (~6s), the next boot timer may be 20s/45s later.
  /// These intervals restart from the Wi‑Fi/probe-miss moment instead.
  void _armPostWifiLinkRetries({required String why}) {
    if (_originPinned) {
      return;
    }
    // Avoid resetting the cadence when Wi‑Fi emits duplicate "connected".
    if (_postWifiLinkTimers.isNotEmpty) {
      return;
    }
    for (final sec in <int>[1, 2, 4, 8, 15, 30]) {
      _postWifiLinkTimers.add(
        Timer(Duration(seconds: sec), () {
          if (_originPinned) {
            return;
          }
          if (services.wifi.currentConnection.phase !=
              WifiConnectionPhase.connected) {
            return;
          }
          unawaited(_ensureCloudLinked(reason: 'wifi-retry-${sec}s'));
        }),
      );
    }
  }

  void _cancelPostWifiLinkRetries() {
    for (final t in _postWifiLinkTimers) {
      t.cancel();
    }
    _postWifiLinkTimers.clear();
  }

  void _armMdnsWifiWatch() {
    _mdnsWifiSub ??= services.wifi.connection.listen((state) {
      if (state.phase == WifiConnectionPhase.disconnected ||
          state.phase == WifiConnectionPhase.failed) {
        // Spec: withdraw when LAN address disappears (Wi‑Fi drop).
        unawaited(mdns.withdraw());
        // Spec: connectivity loss MUST close/reset the WS session so we do
        // not sit on a half-open "connected" socket with no reconnect.
        if (ws.state == DeviceWsState.connected ||
            ws.state == DeviceWsState.connecting) {
          debugPrint('cloud-runtime: wifi lost — reset device ws');
          unawaited(ws.disconnect());
        }
      } else if (state.phase == WifiConnectionPhase.connected) {
        if (localHttp.isRunning) {
          unawaited(_publishMdns());
        }
        if (_originPinned) {
          debugPrint('cloud-runtime: wifi connected — resume device ws');
          unawaited(ws.reconnectIfIdle());
        }
      }
    });
  }

  Future<DeviceUsersProbeResult> _emitUsersProbe(
    Uri pin,
    String sn, {
    required bool notifyAuthError,
    bool resumeWsIfOk = false,
  }) async {
    final users = await usersClient.probeUsers(pinnedBase: pin, deviceSn: sn);
    debugPrint(
      'cloud-runtime: users probe ok=${users.ok} count=${users.userCount} '
      'status=${users.statusCode} errorCode=${users.errorCode} '
      'unbound=${users.unbound} needsRegistration=${users.needsRegistration}',
    );
    onUsersProbe?.call(users);
    if (users.ok) {
      _clearRegistrationPromptLatch();
    }
    if (notifyAuthError && users.needsRegistration) {
      _notifyRegistrationNeeded();
    }
    if (resumeWsIfOk && users.ok) {
      final wsUrl = DeviceApiOriginConfig.deviceWebSocketUri(
        pinnedHttpBase: pin,
        deviceSn: sn,
      );
      debugPrint('cloud-runtime: users ok — resume ws $wsUrl');
      await ws.connect(wsUrl, resumeAfterAuth: true);
    }
    return users;
  }

  void _notifyRegistrationNeeded() {
    if (_registrationPromptNotified) {
      debugPrint('cloud-runtime: registration prompt already notified — skip');
      return;
    }
    _registrationPromptNotified = true;
    onAuthError?.call();
  }

  void _clearRegistrationPromptLatch() {
    _registrationPromptNotified = false;
  }

  Future<void> dispose() async {
    _cancelCloudLinkRetries();
    _cancelPostWifiLinkRetries();
    _linkFollowUpTimer?.cancel();
    _linkFollowUpTimer = null;
    final mdnsSub = _mdnsWifiSub;
    _mdnsWifiSub = null;
    await mdnsSub?.cancel();
    await mdns.withdraw();
    await liveCache.dispose();
    monitorStatHub.resetForTest();
    monitorAlertsHub.resetForTest();
    await localHttp.stop();
    await ws.dispose();
  }

  Future<void> _onWsConnected() async {
    dispatcher.snapshotLoader = _loadSnapshot;
    await dispatcher.sendOnline();
  }

  Future<Map<String, Object?>> _loadSnapshot() async {
    final product = await services.ensureProductInfo();
    WifiConnectionState? wifi;
    try {
      wifi = services.wifi.currentConnection;
    } catch (_) {}

    final common = commonSettings;
    final misc = miscSettings;
    final sound = soundEffectStore;
    final focusRaw = product.focusScaleRef().trim();
    final focus = int.tryParse(focusRaw) ?? 0;
    final cameraIp = effectiveCameraHost(product);

    var cameraStatus = 0;
    try {
      final session = await services.ensureIpCamera();
      cameraStatus = session.camera.currentHealth.isHealthy ? 1 : 0;
    } catch (_) {}

    var cameraVersion = kUnavailableDisplay;
    final versionFetch = cameraVersionFetch;
    if (versionFetch != null) {
      try {
        cameraVersion = await versionFetch(cameraIp);
      } catch (_) {}
    }

    Map<String, Object?> deviceStatus = {'cameraStatus': cameraStatus};
    Map<String, Object?> deviceData = const <String, Object?>{};
    Map<String, Object?> infoGroup = const <String, Object?>{};
    Map<String, Object?> statusAttrs = const <String, Object?>{};
    Map<String, Object?>? processParameters =
        ProcessParametersSnapshotStore.instance.snapshot;
    try {
      await services.ensureModbusLive();
      Object? lastErr;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final statusGroup = await services.modbus.readGroup('status');
          statusAttrs = statusGroup;
          deviceStatus = DeviceRemoteSnapshotModbusMapper.deviceStatusFromGroup(
            statusGroup,
            cameraStatus: cameraStatus,
          );
          final dataGroup = await services.modbus.readGroup('data');
          deviceData =
              DeviceRemoteSnapshotModbusMapper.deviceDataFromGroup(dataGroup);
          try {
            infoGroup = await services.modbus.readGroup('info');
          } catch (_) {}
          if (processParameters == null) {
            try {
              final processGroup = await services.modbus.readGroup('process');
              final control = await services.modbus.readGroup('control');
              final typeRaw = control['control.process_type'];
              processParameters =
                  DeviceRemoteSnapshotModbusMapper.processParametersFromGroup(
                processGroup,
                processType: typeRaw is num ? typeRaw.toInt() : null,
              );
            } catch (_) {}
          }
          lastErr = null;
          break;
        } catch (e) {
          lastErr = e;
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: 120 * (attempt + 1)),
            );
          }
        }
      }
      if (lastErr != null) {
        debugPrint('cloud-runtime: snapshot modbus fill failed: $lastErr');
      }
    } catch (e) {
      debugPrint('cloud-runtime: snapshot modbus ensure failed: $e');
    }

    List<Object?> warns = const <Object?>[];
    final logQuery = warnLogQuery;
    if (logQuery != null) {
      try {
        // lws-ui WarnListLoader first page is typically small; keep bound.
        final rows = await logQuery(limit: 50);
        warns = DeviceRemoteSnapshotModbusMapper.warnsFromAlarmLogs(rows);
      } catch (e) {
        debugPrint('cloud-runtime: warns load failed: $e');
      }
    }

    final hostFromIni = product.get('host_ip').trim();
    final hostIp = hostFromIni.isNotEmpty
        ? hostFromIni
        : ((wifi?.ipv4 ?? '').trim());

    String? processLibVersion;
    final library = processLibrary;
    if (library != null) {
      for (final p in library.presets) {
        final v = p.libraryVersion?.trim();
        if (v != null && v.isNotEmpty) {
          processLibVersion = v;
          break;
        }
      }
    }

    final deviceInfo = DeviceRemoteSnapshotModbusMapper.deviceInfoFromSources(
      deviceSn: product.sn,
      brand: product.brand,
      model: product.model,
      systemVersion: kSystemVersion,
      cameraIp: cameraIp,
      cameraVersion: cameraVersion,
      hostIp: hostIp,
      focusScaleRef: focus,
      infoGroup: infoGroup,
      statusGroup: statusAttrs,
      processLibVersion: processLibVersion,
    );

    return snapshotPacker.pack(
      deviceSn: product.sn,
      brand: product.brand,
      model: product.model,
      cameraIp: cameraIp,
      cameraVersion: cameraVersion,
      hostIp: hostIp,
      focusScaleRef: focus,
      commonUseText: ProcessParametersSnapshotStore.instance.commonUseText,
      wifi: wifi,
      deviceInfo: deviceInfo,
      commonSettings: {
        'language': common?.language ?? CommonSettingsStore.defaultLanguage,
        'unit': common?.unit ?? CommonSettingsStore.defaultUnit,
        'soundEffect': sound?.index ?? SoundEffectStore.defaultIndex,
        'showBootSelfCheck': misc?.showStartupSelfCheck ?? true,
        'showSafetyGroundLockAlarm': misc?.showGroundLockAlarm ?? true,
      },
      deviceStatus: deviceStatus,
      deviceData: deviceData,
      processParameters: processParameters,
      warns: warns,
    );
  }

  Future<void> _publishMdns() async {
    try {
      final product = await services.ensureProductInfo();
      final model = [
        product.brand.trim(),
        product.model.trim(),
      ].where((s) => s.isNotEmpty).join(' ');
      await mdns.publish(
        sn: product.sn,
        model: model.isEmpty ? product.model : model,
        systemVersion: kSystemVersion,
      );
    } catch (e) {
      debugPrint('cloud-runtime: mdns publish failed: $e');
    }
  }

  // --- Video WS -----------------------------------------------------------

  Future<void> _handleVideoListRequest(DeviceWsEnvelope request) async {
    final repo = processVideoRepository;
    if (repo == null) {
      await ws.send(
        DeviceWsEnvelope.build(
          type: 'command.video_list_response',
          payload: {
            'request_id': request.id,
            'data': {'list': <Object?>[], 'total': 0},
          },
        ),
      );
      return;
    }
    await repo.open();
    final payload = request.payload is Map
        ? Map<String, Object?>.from(request.payload as Map)
        : <String, Object?>{};
    int page = 1;
    int pageSize = 10;
    final pageRaw = payload['page'];
    if (pageRaw is num) {
      page = pageRaw.toInt();
    } else if (pageRaw != null) {
      page = int.tryParse(pageRaw.toString()) ?? 1;
    }
    final sizeRaw = payload['page_size'] ?? payload['pageSize'];
    if (sizeRaw is num) {
      pageSize = sizeRaw.toInt();
    } else if (sizeRaw != null) {
      pageSize = int.tryParse(sizeRaw.toString()) ?? 10;
    }
    int? processType;
    final pt = payload['process_type'] ?? payload['processType'];
    if (pt is num) {
      processType = pt.toInt();
    } else if (pt != null) {
      processType = int.tryParse(pt.toString());
    }
    int? materialType;
    final mt = payload['material_type'] ?? payload['materialType'];
    if (mt is num) {
      materialType = mt.toInt();
    } else if (mt != null) {
      materialType = int.tryParse(mt.toString());
    }
    int? uploadStatus;
    final us = payload['upload_status'] ?? payload['uploadStatus'];
    if (us is num) {
      uploadStatus = us.toInt();
    } else if (us != null) {
      uploadStatus = int.tryParse(us.toString());
    }
    final order = (payload['order'] ?? 'date_desc').toString();
    final pageResult = await repo.query(
      ProcessVideoListQuery(
        page: page,
        pageSize: pageSize,
        processType: processType,
        materialType: materialType,
        startDateYmd: payload['start_date']?.toString() ??
            payload['startDate']?.toString(),
        endDateYmd:
            payload['end_date']?.toString() ?? payload['endDate']?.toString(),
        orderAsc: order == 'date_asc',
        uploadStatus: uploadStatus,
      ),
    );
    await ws.send(
      DeviceWsEnvelope.build(
        type: 'command.video_list_response',
        payload: {
          'request_id': request.id,
          'data': {
            'list': [
              for (final r in pageResult.list) _videoListItem(r),
            ],
            'total': pageResult.total,
          },
        },
      ),
    );
  }

  Map<String, Object?> _videoListItem(ProcessVideoRecord r) => {
        'videoId': r.videoId,
        'processType': r.processType.wireValue,
        'materialType': r.materialType?.storageValue,
        'createTime': r.createTimeMs,
        'fileSize': r.fileSize,
        'duration': r.durationMs,
        'resolution': r.resolution,
        'uploadStatus': r.uploadStatus,
        'uploadProgress': r.uploadProgress,
        'coverUrl': r.coverUrl,
        'videoUrl': r.videoUrl,
        'processParametersJson': r.snapshot?.toJsonString(),
      };

  Map<String, Object?> _videoMetadataPayload(
    ProcessVideoRecord r, {
    required String videoUrl,
  }) =>
      {
        'videoId': r.videoId,
        'processParametersJson': r.snapshot?.toJsonString(),
        'processType': r.processType.wireValue,
        'materialType': r.materialType?.storageValue,
        'fileSize': r.fileSize,
        'duration': r.durationMs,
        'createTime': r.createTimeMs,
        'resolution': r.resolution,
        'uploadStatus': ProcessVideoUploadStatus.videoUploaded,
        'uploadProgress': 100,
        'coverUrl': r.coverUrl ?? '',
        'videoUrl': videoUrl,
      };

  Future<ProcessVideoRecord?> _findVideoByUuid(String videoId) async {
    final repo = processVideoRepository;
    if (repo == null || videoId.isEmpty) {
      return null;
    }
    await repo.open();
    return repo.findByVideoId(videoId);
  }

  Future<void> _handleUploadVideo(DeviceWsEnvelope request) async {
    final payload = request.payload;
    final videoId = payload is Map
        ? (payload['videoId'] ?? payload['video_id'])?.toString() ?? ''
        : '';
    if (videoId.isEmpty) {
      await dispatcher.sendDataAck(
        type: 'command.upload_video_ack',
        requestId: request.id,
        success: false,
        message: 'missing videoId',
      );
      return;
    }
    final row = await _findVideoByUuid(videoId);
    if (row == null) {
      await dispatcher.sendDataAck(
        type: 'command.upload_video_ack',
        requestId: request.id,
        success: false,
        message: 'video_not_found',
      );
      return;
    }
    final pin = prober.pinnedBase;
    if (pin == null) {
      await dispatcher.sendDataAck(
        type: 'command.upload_video_ack',
        requestId: request.id,
        success: false,
        message: 'no_api_origin',
      );
      return;
    }
    final file = File(row.videoPath);
    if (!await file.exists()) {
      await dispatcher.sendDataAck(
        type: 'command.upload_video_ack',
        requestId: request.id,
        success: false,
        message: 'file_missing',
      );
      return;
    }

    // lws-ui: ack when upload is accepted/started — not when finished.
    await dispatcher.sendDataAck(
      type: 'command.upload_video_ack',
      requestId: request.id,
      success: true,
      message: 'accepted',
    );

    try {
      final sts = await r2StsClient.fetchSts(pinnedBase: pin);
      if (sts == null) {
        debugPrint('cloud-runtime: upload sts_failed after accept');
        return;
      }
      await processVideoRepository?.updateUploadState(
        videoId: videoId,
        uploadStatus: ProcessVideoUploadStatus.videoUploading,
        uploadProgress: 0,
      );
      await ws.send(
        DeviceWsEnvelope.build(
          type: 'video.uploading',
          payload: {
            'videoId': videoId,
            'uploadStatus': ProcessVideoUploadStatus.videoUploading,
            'uploadProgress': 0,
            'videoUrl': '',
          },
        ),
      );
      final bytes = await file.readAsBytes();
      final objectKey = 'process-videos/${row.videoId}.mp4';
      final putOk = await r2PutClient.putObject(
        credentials: sts,
        objectKey: objectKey,
        bytes: bytes,
        contentType: 'video/mp4',
      );
      if (!putOk) {
        debugPrint('cloud-runtime: r2_put_failed after accept');
        return;
      }
      final videoUrl =
          '${sts.endpoint.replaceAll(RegExp(r'/+$'), '')}/${sts.bucket}/$objectKey';
      await videoMetadataClient.uploadVideoAndProcessData(
        pinnedBase: pin,
        body: {
          'videoId': videoId,
          'videoUrl': videoUrl,
          'processType': row.processType.wireValue,
          'materialType': row.materialType?.storageValue,
          'createTime': row.createTimeMs,
          'fileSize': row.fileSize,
          'duration': row.durationMs,
          'resolution': row.resolution,
          'processParametersJson': row.snapshot?.toJsonString(),
        },
      );
      await processVideoRepository?.updateUploadState(
        videoId: videoId,
        uploadStatus: ProcessVideoUploadStatus.videoUploaded,
        uploadProgress: 100,
        videoUrl: videoUrl,
      );
      await ws.send(
        DeviceWsEnvelope.build(
          type: 'video.uploading',
          payload: {
            'videoId': videoId,
            'uploadStatus': ProcessVideoUploadStatus.videoUploaded,
            'uploadProgress': 100,
            'videoUrl': videoUrl,
          },
        ),
      );
      await ws.send(
        DeviceWsEnvelope.build(
          type: 'video.metadata',
          payload: _videoMetadataPayload(row, videoUrl: videoUrl),
        ),
      );
    } catch (e) {
      debugPrint('cloud-runtime: upload video failed after accept: $e');
    }
  }

  Future<void> _handleDeleteVideo(DeviceWsEnvelope request) async {
    final payload = request.payload;
    final videoId = payload is Map
        ? (payload['video_id'] ?? payload['videoId'])?.toString() ?? ''
        : '';
    if (videoId.isEmpty) {
      await dispatcher.sendDataAck(
        type: 'command.delete_video_ack',
        requestId: request.id,
        success: false,
        message: 'missing_video_id',
      );
      return;
    }
    final row = await _findVideoByUuid(videoId);
    if (row == null || row.id == null) {
      await dispatcher.sendDataAck(
        type: 'command.delete_video_ack',
        requestId: request.id,
        success: false,
        message: 'video_not_found',
      );
      return;
    }
    final ok = await processVideoRepository!.deleteById(row.id!);
    await dispatcher.sendDataAck(
      type: 'command.delete_video_ack',
      requestId: request.id,
      success: ok,
      message: ok ? 'ok' : 'file_delete_failed',
    );
  }

  // --- Process library / parameters WS ------------------------------------

  Map<String, Object?> _presetWire(ProcessPreset p) => {
        'id': p.uuid,
        'uuid': p.uuid,
        'name': p.name,
        'processType': p.processType.wireValue,
        'materialType': p.materialType?.storageValue,
        'materialName': p.materialName,
        'thickness': p.thickness,
        'gear': p.gear,
        'parameters': p.parameters.toJson(),
        'dataType': p.isBuiltin ? 1 : 2,
        'isBuiltin': p.isBuiltin,
        'kind': p.kind.storageValue,
      };

  Future<void> _handleProcessLibraryRequest(DeviceWsEnvelope request) async {
    final library = processLibrary;
    if (library == null) {
      await ws.send(
        DeviceWsEnvelope.build(
          type: 'command.process_library_response',
          payload: {
            'request_id': request.id,
            'data': <Object?>[],
          },
        ),
      );
      return;
    }
    await library.initialize();
    final payload = request.payload;
    int? processType;
    if (payload is Map) {
      final raw = payload['process_type'] ?? payload['processType'];
      if (raw is num) {
        processType = raw.toInt();
      } else if (raw != null) {
        processType = int.tryParse(raw.toString());
      }
    }
    // lws-ui: missing process_type → empty array (not full dump).
    final list = processType == null
        ? <Map<String, Object?>>[]
        : library.presets
            .where((p) => p.processType.wireValue == processType)
            .map(_presetWire)
            .toList();
    await ws.send(
      DeviceWsEnvelope.build(
        type: 'command.process_library_response',
        payload: {
          'request_id': request.id,
          'data': list,
        },
      ),
    );
  }

  Future<void> _handleProcessParametersRequest(DeviceWsEnvelope request) async {
    final library = processLibrary;
    final idRaw = request.payload is Map
        ? (request.payload as Map)['id']?.toString() ?? ''
        : '';
    ProcessPreset? found;
    if (library != null && idRaw.isNotEmpty) {
      await library.initialize();
      found = await library.repository.findByUuid(idRaw);
      if (found == null) {
        final asInt = int.tryParse(idRaw);
        if (asInt != null) {
          for (final p in library.presets) {
            if (p.id == asInt) {
              found = p;
              break;
            }
          }
        }
      }
    }
    await ws.send(
      DeviceWsEnvelope.build(
        type: 'command.process_parameters_response',
        payload: {
          'request_id': request.id,
          'data': found == null ? null : _presetWire(found),
        },
      ),
    );
  }

  Future<void> _handleProcessParametersCreate(DeviceWsEnvelope request) async {
    await _mutateUserPreset(
      request,
      ackType: 'command.process_parameters_create_ack',
      create: true,
    );
  }

  Future<void> _handleProcessParametersUpdate(DeviceWsEnvelope request) async {
    await _mutateUserPreset(
      request,
      ackType: 'command.process_parameters_update_ack',
      create: false,
    );
  }

  Future<void> _mutateUserPreset(
    DeviceWsEnvelope request, {
    required String ackType,
    required bool create,
  }) async {
    final library = processLibrary;
    if (library == null) {
      await dispatcher.sendDataAck(
        type: ackType,
        requestId: request.id,
        success: false,
        message: 'process_library_unavailable',
      );
      return;
    }
    try {
      await library.initialize();
      final map = request.payload is Map
          ? Map<String, Object?>.from(request.payload as Map)
          : <String, Object?>{};
      final name = map['name']?.toString().trim() ?? '';
      final processTypeRaw = map['process_type'] ?? map['processType'];
      final processType = processTypeRaw is num
          ? ProcessType.fromWireValue(processTypeRaw.toInt())
          : ProcessType.fromWireValue(
              int.parse(processTypeRaw?.toString() ?? '0'),
            );
      final materialRaw = map['material_type'] ?? map['materialType'];
      MaterialType? material;
      if (materialRaw is num) {
        material = MaterialType.fromStorageValue(materialRaw.toInt());
      }
      final paramsRaw = map['parameters'] ?? map['data'];
      final parameters = paramsRaw == null
          ? const ProcessParameters.empty()
          : ProcessParameters.fromJson(
              paramsRaw is Map
                  ? Map<String, dynamic>.from(paramsRaw)
                  : <String, dynamic>{},
            );
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      if (create) {
        final saved = await library.saveUser(
          ProcessPreset(
            uuid: _newUuid(),
            name: name.isEmpty ? 'Cloud preset' : name,
            kind: ProcessPresetKind.user,
            source: 'cloud',
            isBuiltin: false,
            processType: processType,
            materialType: material,
            materialName: map['materialName']?.toString() ??
                map['material_name']?.toString(),
            thickness: (map['thickness'] as num?)?.toDouble(),
            gear: (map['gear'] as num?)?.toInt(),
            parameters: parameters,
            createdAtMs: now,
            updatedAtMs: now,
          ),
        );
        await dispatcher.sendDataAck(
          type: ackType,
          requestId: request.id,
          success: true,
          message: 'ok',
          createdId: saved.uuid,
        );
      } else {
        final idRaw = map['id']?.toString() ?? '';
        var existing = await library.repository.findByUuid(idRaw);
        if (existing == null) {
          await dispatcher.sendDataAck(
            type: ackType,
            requestId: request.id,
            success: false,
            message: 'not_found',
          );
          return;
        }
        if (existing.isBuiltin) {
          await dispatcher.sendDataAck(
            type: ackType,
            requestId: request.id,
            success: false,
            message: 'builtin_readonly',
          );
          return;
        }
        final saved = await library.saveUser(
          existing.copyWith(
            name: name.isEmpty ? existing.name : name,
            processType: processType,
            materialType: material ?? existing.materialType,
            materialName: map['materialName']?.toString() ??
                map['material_name']?.toString() ??
                existing.materialName,
            thickness: (map['thickness'] as num?)?.toDouble() ??
                existing.thickness,
            gear: (map['gear'] as num?)?.toInt() ?? existing.gear,
            parameters: parameters.values.isEmpty
                ? existing.parameters
                : parameters,
            updatedAtMs: now,
          ),
        );
        await dispatcher.sendDataAck(
          type: ackType,
          requestId: request.id,
          success: true,
          message: 'ok',
          createdId: saved.uuid,
        );
      }
    } catch (e) {
      await dispatcher.sendDataAck(
        type: ackType,
        requestId: request.id,
        success: false,
        message: e.toString(),
      );
    }
  }

  Future<void> _handleProcessParametersDelete(DeviceWsEnvelope request) async {
    final library = processLibrary;
    final idRaw = request.payload is Map
        ? (request.payload as Map)['id']?.toString() ?? ''
        : '';
    if (library == null || idRaw.isEmpty) {
      await dispatcher.sendDataAck(
        type: 'command.process_parameters_delete_ack',
        requestId: request.id,
        success: false,
        message: 'missing id',
      );
      return;
    }
    try {
      await library.initialize();
      final existing = await library.repository.findByUuid(idRaw);
      if (existing == null || existing.isBuiltin) {
        await dispatcher.sendDataAck(
          type: 'command.process_parameters_delete_ack',
          requestId: request.id,
          success: false,
          message: existing == null ? 'not_found' : 'builtin_readonly',
        );
        return;
      }
      await library.deleteUser(existing);
      await dispatcher.sendDataAck(
        type: 'command.process_parameters_delete_ack',
        requestId: request.id,
        success: true,
        message: 'ok',
      );
    } catch (e) {
      await dispatcher.sendDataAck(
        type: 'command.process_parameters_delete_ack',
        requestId: request.id,
        success: false,
        message: e.toString(),
      );
    }
  }

  Future<void> _handleProcessParametersSetDefault(
    DeviceWsEnvelope request,
  ) async {
    // Linux HMI has no separate "active preset" store yet — ack apply attempt.
    final library = processLibrary;
    final idRaw = request.payload is Map
        ? (request.payload as Map)['id']?.toString() ?? ''
        : '';
    if (library == null || idRaw.isEmpty) {
      await dispatcher.sendDataAck(
        type: 'command.process_parameters_set_default_ack',
        requestId: request.id,
        success: false,
        message: 'missing id',
      );
      return;
    }
    try {
      await library.initialize();
      final existing = await library.repository.findByUuid(idRaw);
      if (existing == null) {
        await dispatcher.sendDataAck(
          type: 'command.process_parameters_set_default_ack',
          requestId: request.id,
          success: false,
          message: 'not_found',
        );
        return;
      }
      final result = await library.apply(existing);
      final ok = result.isSuccess;
      await dispatcher.sendDataAck(
        type: 'command.process_parameters_set_default_ack',
        requestId: request.id,
        success: ok,
        message: ok ? 'ok' : 'apply_failed',
      );
    } catch (e) {
      await dispatcher.sendDataAck(
        type: 'command.process_parameters_set_default_ack',
        requestId: request.id,
        success: false,
        message: e.toString(),
      );
    }
  }

  static String _newUuid() {
    final ms = DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'cloud-$ms-${ms.hashCode.abs()}';
  }
}
