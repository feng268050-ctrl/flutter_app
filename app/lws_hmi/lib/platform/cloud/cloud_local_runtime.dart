import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/device/product_property_defaults.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_show_overlay_applier.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_demo_recording_paths.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:cyber_hal/ip_camera.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:lws_hmi/features/ai/application/ai_daemon_supervisor.dart';
import 'package:lws_hmi/features/process_library/application/engineer_preset_deriver.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_video/application/process_video_cloud_upload_coordinator.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/system_ota/application/system_ota_coordinator.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_store.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';
import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/cloud_link_ui_status.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';
import 'package:lws_hmi/platform/cloud/device_ai_report_client.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_prober.dart';
import 'package:lws_hmi/platform/cloud/device_cloud_ed25519.dart';
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
    ed25519Client = DeviceCloudEd25519Client(cloudHttp: cloudHttp);
    ed25519 = DeviceCloudEd25519Coordinator(
      identity: services.bindings.cloudEd25519Identity(),
      client: ed25519Client,
      vendorIdentity: const VendorIdentityReader(),
    );
    cloudHttp.deviceAccessToken = _resolveDeviceAccessToken;
    cloudHttp.refreshDeviceAccessToken = _refreshDeviceAccessToken;
    r2StsClient = DeviceR2StsClient(cloudHttp: cloudHttp);
    r2PutClient = DeviceR2PutObjectClient(cloudHttp: cloudHttp);
    videoMetadataClient = DeviceVideoMetadataClient(cloudHttp: cloudHttp);
    aiReportClient = DeviceAiReportClient(cloudHttp: cloudHttp);
    snapshotPacker = DeviceRemoteSnapshotPacker(lockStore: lockStore);
    ws = DeviceWsConnectionManager(
      cloudHttp: cloudHttp,
      onAuthError: _notifyRegistrationNeeded,
      onStateChanged: (s) {
        _publishLinkStatus();
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
      cameraAiPublisher: AiDaemonSupervisor.instance.cameraAiPublisher,
    );
    final videoRepo =
        processVideoRepository ?? SqliteProcessVideoRepository();
    processVideoUpload = ProcessVideoCloudUploadCoordinator(
      services: services,
      repository: videoRepo,
      prober: prober,
      r2StsClient: r2StsClient,
      r2PutClient: r2PutClient,
      ws: ws,
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
  late final DeviceCloudEd25519Client ed25519Client;
  late final DeviceCloudEd25519Coordinator ed25519;
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
  late final ProcessVideoCloudUploadCoordinator processVideoUpload;
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
  /// Serializes LAN/cloud plane start/stop when toggles flip quickly.
  Future<void> _planeGate = Future<void>.value();
  CloudLinkUiStatus _linkStatus = CloudLinkUiStatus.connecting;
  final StreamController<CloudLinkUiStatus> _linkStatusCtrl =
      StreamController<CloudLinkUiStatus>.broadcast();

  /// Home status-bar cloud phase (origin probe + WS, not WS-only).
  CloudLinkUiStatus get currentLinkStatus => _linkStatus;
  Stream<CloudLinkUiStatus> get linkStatusChanges => _linkStatusCtrl.stream;

  /// Pinned Worker HTTP base after origin probe (null until linked).
  Uri? get pinnedApiBase => prober.pinnedBase;

  /// Push OTA progress to cloud WS subscribers.
  Future<void> emitOtaProgress(Map<String, Object?> data) {
    return dispatcher.sendUpgradeProgress(data);
  }

  void _wireLocalHttpHandlers() {
    localHttp.cameraAiAvailable = () async => AiDaemonSupervisor.instance.isReady;
    localHttp.processVideoAiAvailable =
        () async => AiDaemonSupervisor.instance.isReady;
    localHttp.cameraShowOverlayHandler = (body) async {
      final params = CameraShowOverlayParams.tryParse(
        enableRaw: body['enable'],
        positionXRaw: body['positionx'],
        positionYRaw: body['positiony'],
      );
      if (params == null) {
        return LocalHttpCameraActionResult.fail(
          'invalid_show_overlay_request',
          httpStatus: HttpStatus.badRequest,
        );
      }
      try {
        final product = await services.ensureProductInfo();
        final host = effectiveCameraHost(product);
        if (host.isEmpty) {
          return LocalHttpCameraActionResult.fail(
            'camera_ip_unconfigured',
            httpStatus: HttpStatus.badRequest,
          );
        }
        final result = await services.cameraShowOverlay.apply(
          cameraHost: host,
          machineModel: cameraOverlayDeviceName(product.brand, product.model),
          params: params,
        );
        if (!result.ok) {
          return LocalHttpCameraActionResult.fail(
            result.message,
            httpStatus: result.httpStatus,
          );
        }
        return LocalHttpCameraActionResult.success(data: result.dataMap());
      } catch (e) {
        debugPrint('local-http: camera show-overlay failed: $e');
        return LocalHttpCameraActionResult.fail(
          'camera_unreachable',
          httpStatus: HttpStatus.serviceUnavailable,
        );
      }
    };
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

    dispatcher.onOtaCheckUpdate = (envelope) =>
        SystemOtaCoordinator.instance.handleWsCheckUpdate(envelope.payload);
    dispatcher.onOtaUpdateSystem = (envelope) =>
        SystemOtaCoordinator.instance.handleWsUpdateSystem(envelope.payload);
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

    _armMdnsWifiWatch();
    unawaited(liveCache.start());

    await _enqueuePlaneOp(() async {
      await _applyLanEnhancementUnlocked();
      await _applyCloudServicesUnlocked();
    });
  }

  /// Persist + apply 云服务 without requiring an HMI restart.
  Future<void> setCloudServicesEnabled(bool enabled) async {
    cloudSettings.warmRead();
    await cloudSettings.setCloudServicesEnabled(enabled);
    await _enqueuePlaneOp(_applyCloudServicesUnlocked);
  }

  /// Persist + apply 局域网增强 without requiring an HMI restart.
  Future<void> setLanEnhancementEnabled(bool enabled) async {
    cloudSettings.warmRead();
    await cloudSettings.setLanEnhancementEnabled(enabled);
    await _enqueuePlaneOp(_applyLanEnhancementUnlocked);
  }

  Future<void> _enqueuePlaneOp(Future<void> Function() op) {
    final run = _planeGate.then((_) => op());
    _planeGate = run.catchError((Object e, StackTrace st) {
      debugPrint('cloud-runtime: plane op failed: $e\n$st');
    });
    return run;
  }

  Future<void> _applyLanEnhancementUnlocked() async {
    if (!_started) {
      return;
    }
    if (cloudSettings.lanEnhancementEnabled) {
      final httpOk = await localHttp.start();
      if (httpOk) {
        await _publishMdns();
      }
    } else {
      await mdns.withdraw();
      await localHttp.stop();
    }
  }

  Future<void> _applyCloudServicesUnlocked() async {
    if (!_started) {
      return;
    }
    if (cloudSettings.cloudServicesEnabled) {
      // Cloud HTTP/WS need uplink DNS + route — wait for Wi‑Fi (or link now if
      // already connected). Do not probe origins while radio/IP is down.
      _armCloudLinkRetries();
    } else {
      await _stopCloudPlaneUnlocked();
    }
  }

  Future<void> _stopCloudPlaneUnlocked() async {
    _cancelCloudLinkRetries();
    _cancelPostWifiLinkRetries();
    _linkFollowUpTimer?.cancel();
    _linkFollowUpTimer = null;
    _linkFollowUpPending = false;
    _linkInFlight = false;
    _originPinned = false;
    _clearRegistrationPromptLatch();
    ed25519.clearCachedAccessToken();
    prober.clearPin();
    if (ws.state == DeviceWsState.connected ||
        ws.state == DeviceWsState.connecting ||
        ws.state == DeviceWsState.offlineAuthError) {
      await ws.disconnect();
    }
    _publishLinkStatus();
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
    if (!cloudSettings.cloudServicesEnabled) {
      debugPrint('cloud-runtime: refresh users — cloud services off');
      return;
    }
    var pin = prober.pinnedBase;
    pin ??= await prober.probe(cloudSettings.environmentTier);
    if (pin == null) {
      debugPrint('cloud-runtime: refresh users — no API origin');
      _armCloudLinkRetries();
      return;
    }
    _originPinned = true;
    _publishLinkStatus();
    await _ensureDeviceCloudAuth(pin);
    unawaited(processVideoUpload.enqueuePendingCovers());
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
    if (!cloudSettings.cloudServicesEnabled) {
      debugPrint('cloud-runtime: reprobe — cloud services off');
      await _enqueuePlaneOp(_stopCloudPlaneUnlocked);
      return;
    }
    await ws.disconnect();
    prober.clearPin();
    _originPinned = false;
    _publishLinkStatus();
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
    await _ensureDeviceCloudAuth(pin);
    unawaited(processVideoUpload.enqueuePendingCovers());
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
    _publishLinkStatus();
  }

  Future<void> _ensureCloudLinked({required String reason}) async {
    if (!cloudSettings.cloudServicesEnabled) {
      return;
    }
    final wifiPhase = services.wifi.currentConnection.phase;
    if (wifiPhase != WifiConnectionPhase.connected) {
      return;
    }
    if (_originPinned || _linkInFlight) {
      if (!_originPinned) {
        _linkFollowUpPending = true;
        _publishLinkStatus();
      }
      return;
    }
    _linkInFlight = true;
    _publishLinkStatus();
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
      _publishLinkStatus();
      // Mint device Bearer before gated WS / users / STS (token auth on v1).
      await _ensureDeviceCloudAuth(pin);
      unawaited(processVideoUpload.enqueuePendingCovers());
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
      _publishLinkStatus();
      _scheduleLinkFollowUpIfNeeded();
    }
  }

  void _scheduleLinkFollowUpIfNeeded() {
    if (!cloudSettings.cloudServicesEnabled) {
      _linkFollowUpPending = false;
      return;
    }
    if (_originPinned || !_linkFollowUpPending) {
      return;
    }
    if (services.wifi.currentConnection.phase !=
        WifiConnectionPhase.connected) {
      _linkFollowUpPending = false;
      _publishLinkStatus();
      return;
    }
    _linkFollowUpPending = false;
    _linkFollowUpTimer?.cancel();
    // Brief gap so DNS/default-route can settle after a failed probe.
    _linkFollowUpTimer = Timer(const Duration(milliseconds: 400), () {
      _linkFollowUpTimer = null;
      if (_originPinned || _linkInFlight) {
        if (!_originPinned) {
          _linkFollowUpPending = true;
        }
        _publishLinkStatus();
        return;
      }
      if (services.wifi.currentConnection.phase !=
          WifiConnectionPhase.connected) {
        _publishLinkStatus();
        return;
      }
      unawaited(_ensureCloudLinked(reason: 'wifi-followup'));
    });
    _publishLinkStatus();
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

  /// Ensure-activated + mint device Bearer before gated Worker HTTP/WS.
  ///
  /// Skips on emulator / missing Vendor Storage, HTTP-only origins, empty VS
  /// SN, or 云服务 off. Failures are logged; gated calls may still proceed
  /// without Bearer (server allowlist covers sample SNs).
  Future<void> _ensureDeviceCloudAuth(Uri pinnedBase) async {
    try {
      final result = await ed25519.ensureActivated(
        pinnedBase: pinnedBase,
        cloudServicesEnabled: cloudSettings.cloudServicesEnabled,
      );
      switch (result.status) {
        case DeviceCloudEd25519EnsureStatus.activated:
          debugPrint('cloud-ed25519: activated (pubkey ready)');
          await _mintEd25519AccessToken(pinnedBase);
        case DeviceCloudEd25519EnsureStatus.skipped:
          debugPrint('cloud-ed25519: skipped (${result.error})');
        case DeviceCloudEd25519EnsureStatus.retryLater:
          debugPrint('cloud-ed25519: activate retry later (${result.error})');
        case DeviceCloudEd25519EnsureStatus.foreignKeyConflict:
          debugPrint(
            'cloud-ed25519: FOREIGN KEY CONFLICT — fail closed (${result.error})',
          );
      }
    } catch (e) {
      debugPrint('cloud-ed25519: ensure-activated error: $e');
    }
  }

  Future<void> _mintEd25519AccessToken(Uri pinnedBase) async {
    try {
      final tok = await ed25519.mintAccessToken(
        pinnedBase: pinnedBase,
        cloudServicesEnabled: cloudSettings.cloudServicesEnabled,
      );
      if (tok.ok) {
        debugPrint('cloud-ed25519: access_token minted');
      } else {
        debugPrint('cloud-ed25519: token mint failed (${tok.error})');
      }
    } catch (e) {
      debugPrint('cloud-ed25519: token mint error: $e');
    }
  }

  Future<String?> _resolveDeviceAccessToken() async {
    final cached = ed25519.cachedAccessToken;
    if (cached != null && cached.isNotEmpty) {
      // Prefer cache; mintAccessToken also refreshes near exp.
    }
    final pin = prober.pinnedBase;
    if (pin == null || !cloudSettings.cloudServicesEnabled) {
      return cached;
    }
    try {
      final tok = await ed25519.mintAccessToken(
        pinnedBase: pin,
        cloudServicesEnabled: cloudSettings.cloudServicesEnabled,
      );
      if (tok.ok && tok.accessToken != null && tok.accessToken!.isNotEmpty) {
        return tok.accessToken;
      }
    } catch (e) {
      debugPrint('cloud-ed25519: resolve token failed: $e');
    }
    return ed25519.cachedAccessToken;
  }

  Future<String?> _refreshDeviceAccessToken() async {
    final pin = prober.pinnedBase;
    if (pin == null || !cloudSettings.cloudServicesEnabled) {
      return null;
    }
    try {
      final tok = await ed25519.mintAccessToken(
        pinnedBase: pin,
        cloudServicesEnabled: cloudSettings.cloudServicesEnabled,
        forceRefresh: true,
      );
      if (tok.ok && tok.accessToken != null && tok.accessToken!.isNotEmpty) {
        debugPrint('cloud-ed25519: access_token reminted after 401');
        return tok.accessToken;
      }
      debugPrint('cloud-ed25519: remint failed (${tok.error})');
    } catch (e) {
      debugPrint('cloud-ed25519: remint error: $e');
    }
    return null;
  }

  void _armCloudLinkRetries() {
    if (!cloudSettings.cloudServicesEnabled) {
      return;
    }
    if (_originPinned) {
      return;
    }
    _wifiWaitSub ??= services.wifi.connection.listen((state) {
      if (!cloudSettings.cloudServicesEnabled) {
        return;
      }
      if (state.phase == WifiConnectionPhase.connected) {
        // Arm short retries from Wi‑Fi-up even if the immediate probe races
        // DNS and fails with a full timeout.
        _linkFollowUpPending = true;
        _armPostWifiLinkRetries(why: 'wifi-connected');
        unawaited(_ensureCloudLinked(reason: 'wifi-connected'));
      }
      _publishLinkStatus();
    });
    if (services.wifi.currentConnection.phase ==
        WifiConnectionPhase.connected) {
      _armPostWifiLinkRetries(why: 'wifi-already');
      unawaited(_ensureCloudLinked(reason: 'wifi-already'));
    }
    _publishLinkStatus();
    // No boot-clock retries: probing without Wi‑Fi only burns DNS failures.
    // Retries are armed from Wi‑Fi-up / probe-miss via [_armPostWifiLinkRetries].
  }

  void _cancelCloudLinkRetries() {
    final sub = _wifiWaitSub;
    _wifiWaitSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    _publishLinkStatus();
  }

  /// Event-driven retries after Wi‑Fi is up (or after a probe miss while up).
  ///
  /// Boot timers are anchored at first frame; if Wi‑Fi connects at ~8s and the
  /// first probe times out (~6s), the next boot timer may be 20s/45s later.
  /// These intervals restart from the Wi‑Fi/probe-miss moment instead.
  void _armPostWifiLinkRetries({required String why}) {
    if (!cloudSettings.cloudServicesEnabled) {
      return;
    }
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
          if (!cloudSettings.cloudServicesEnabled || _originPinned) {
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
    _publishLinkStatus();
  }

  void _cancelPostWifiLinkRetries() {
    for (final t in _postWifiLinkTimers) {
      t.cancel();
    }
    _postWifiLinkTimers.clear();
    _publishLinkStatus();
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
        if (cloudSettings.lanEnhancementEnabled && localHttp.isRunning) {
          unawaited(_publishMdns());
        }
        if (cloudSettings.cloudServicesEnabled && _originPinned) {
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
    if (!cloudSettings.cloudServicesEnabled) {
      return const DeviceUsersProbeResult(
        ok: false,
        statusCode: 0,
        userCount: 0,
      );
    }
    final users = await usersClient.probeUsers(pinnedBase: pin, deviceSn: sn);
    debugPrint(
      'cloud-runtime: users probe ok=${users.ok} count=${users.userCount} '
      'status=${users.statusCode} errorCode=${users.errorCode} '
      'unbound=${users.unbound} needsRegistration=${users.needsRegistration}',
    );
    if (!cloudSettings.cloudServicesEnabled) {
      return users;
    }
    onUsersProbe?.call(users);
    if (users.ok) {
      _clearRegistrationPromptLatch();
    }
    if (notifyAuthError && users.needsRegistration) {
      _notifyRegistrationNeeded();
    }
    if (resumeWsIfOk && users.ok && cloudSettings.cloudServicesEnabled) {
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
    if (!cloudSettings.cloudServicesEnabled) {
      debugPrint('cloud-runtime: registration prompt suppressed — cloud off');
      return;
    }
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

  CloudLinkUiStatus _computeLinkStatus() {
    if (!cloudSettings.cloudServicesEnabled) {
      // Cloud plane off — Home must not show a perpetual "connecting" / fail
      // nag; treat as idle failed (no enrollment prompts while gated).
      return CloudLinkUiStatus.failed;
    }
    switch (ws.state) {
      case DeviceWsState.connected:
        return CloudLinkUiStatus.connected;
      case DeviceWsState.connecting:
        return CloudLinkUiStatus.connecting;
      case DeviceWsState.offlineAuthError:
        return CloudLinkUiStatus.failed;
      case DeviceWsState.disconnected:
        break;
    }
    if (ws.forcedDisconnectSuppressed || ws.authErrorLatched) {
      return CloudLinkUiStatus.failed;
    }
    // Origin probe / clock sync / users side-path still in flight.
    if (_linkInFlight) {
      return CloudLinkUiStatus.connecting;
    }
    if (!_originPinned) {
      // Seeking Worker origin: follow-up or post-wifi retries still armed.
      // Do not treat [_wifiWaitSub] alone as connecting — after retries
      // exhaust the icon should show failed until the next attempt starts.
      if (_linkFollowUpPending ||
          _linkFollowUpTimer != null ||
          _postWifiLinkTimers.any((t) => t.isActive)) {
        return CloudLinkUiStatus.connecting;
      }
      return CloudLinkUiStatus.failed;
    }
    // Origin pinned; WS idle — reconnect backoff or waiting for wifi resume.
    if (ws.reconnectScheduled) {
      return CloudLinkUiStatus.connecting;
    }
    return CloudLinkUiStatus.failed;
  }

  void _publishLinkStatus() {
    final next = _computeLinkStatus();
    if (next == _linkStatus) {
      return;
    }
    _linkStatus = next;
    if (!_linkStatusCtrl.isClosed) {
      _linkStatusCtrl.add(next);
    }
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
    await _linkStatusCtrl.close();
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
    final focusRaw = effectiveFocusScaleRefFromProduct(product);
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
        'country': common?.country ?? CommonSettingsStore.defaultCountry,
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
    if (!cloudSettings.lanEnhancementEnabled || !localHttp.isRunning) {
      return;
    }
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
        message: 'missing_videoId',
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
    if (prober.pinnedBase == null) {
      await dispatcher.sendDataAck(
        type: 'command.upload_video_ack',
        requestId: request.id,
        success: false,
        message: 'no_api_origin',
      );
      return;
    }
    if (!await File(row.videoPath).exists()) {
      await dispatcher.sendDataAck(
        type: 'command.upload_video_ack',
        requestId: request.id,
        success: false,
        message: 'file_missing',
      );
      return;
    }
    if (row.uploadStatus == ProcessVideoUploadStatus.videoUploaded) {
      await dispatcher.sendDataAck(
        type: 'command.upload_video_ack',
        requestId: request.id,
        success: false,
        message: 'already_uploaded',
      );
      return;
    }

    // lws-ui: ack when upload is accepted/started — not when finished.
    await dispatcher.sendDataAck(
      type: 'command.upload_video_ack',
      requestId: request.id,
      success: true,
      message: '',
    );
    unawaited(processVideoUpload.uploadVideo(videoId));
  }

  /// Monitor / Record Work: enqueue cover drain or full upload.
  Future<void> notifyProcessVideoSaved() async {
    if (!cloudSettings.cloudServicesEnabled) {
      return;
    }
    await processVideoUpload.enqueuePendingCovers();
  }

  Future<bool> uploadProcessVideo(
    String videoId, {
    ProcessVideoUploadListener? listener,
  }) async {
    if (!cloudSettings.cloudServicesEnabled) {
      return false;
    }
    return processVideoUpload.uploadVideo(videoId, listener: listener);
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
