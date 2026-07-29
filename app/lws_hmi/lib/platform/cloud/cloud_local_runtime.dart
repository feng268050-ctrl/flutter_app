import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';
import 'package:lws_hmi/platform/cloud/device_ai_report_client.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_prober.dart';
import 'package:lws_hmi/platform/cloud/device_r2_put_object_client.dart';
import 'package:lws_hmi/platform/cloud/device_r2_sts_client.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';
import 'package:lws_hmi/platform/cloud/device_remote_snapshot.dart';
import 'package:lws_hmi/platform/cloud/device_users_client.dart';
import 'package:lws_hmi/platform/cloud/device_video_metadata_client.dart';
import 'package:lws_hmi/platform/cloud/device_ws_connection_manager.dart';
import 'package:lws_hmi/platform/cloud/device_ws_dispatcher.dart';
import 'package:lws_hmi/platform/cloud/device_ws_envelope.dart';
import 'package:lws_hmi/platform/local_http/device_local_http_server.dart';
import 'package:lws_hmi/platform/lws_trace.dart';
import 'package:lws_hmi/platform/mdns/device_mdns_advertise.dart';

/// Post–first-frame cloud + LAN orchestrator (probe → WS, local HTTP, mDNS).
final class CloudLocalRuntime {
  CloudLocalRuntime({
    required this.services,
    required this.cloudSettings,
    required this.lockStore,
    this.processLibrary,
    this.processVideoRepository,
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
      onAuthError: () => onAuthError?.call(),
      onStateChanged: (s) {
        if (s == DeviceWsState.connected) {
          unawaited(_onWsConnected());
        }
      },
    );
    dispatcher = DeviceWsDispatcher(
      ws: ws,
      lockStore: lockStore,
      snapshotPacker: snapshotPacker,
      snapshotLoader: _loadSnapshot,
      onClearAlerts: onClearAlerts,
      onProcessParam: onProcessParam,
      onProcessLib: onProcessLib,
      onVideoListRequest: onVideoListRequest,
      onUploadVideo: onUploadVideo,
      onDeleteVideo: onDeleteVideo,
    );
    ws.onMessage = dispatcher.handle;
    localHttp = DeviceLocalHttpServer(
      processVideoRepository: processVideoRepository,
      processLibrary: processLibrary,
      sshDebug: services.sshDebug,
    );
    mdns = DeviceMdnsAdvertise();

    // Default shared LAN/WS video list handler.
    onVideoListRequest ??= (request) async {
      final repo = processVideoRepository;
      if (repo == null) {
        await ws.send(
          DeviceWsEnvelope.build(
            type: 'command.video_list_response',
            id: request.id,
            payload: {'list': <Object?>[], 'total': 0},
          ),
        );
        return;
      }
      await repo.open();
      final total = await repo.count();
      final rows = await repo.list(limit: 10, offset: 0);
      await ws.send(
        DeviceWsEnvelope.build(
          type: 'command.video_list_response',
          id: request.id,
          payload: {
            'list': [
              for (final r in rows)
                {
                  'videoId': r.videoId,
                  'processType': r.processType.wireValue,
                  'materialType': r.materialType?.storageValue,
                  'createTime': r.createTimeMs,
                  'uploadStatus': r.uploadStatus,
                },
            ],
            'total': total,
          },
        ),
      );
    };
    onDeleteVideo ??= (request) async {
      await ws.send(
        DeviceWsEnvelope.build(
          type: 'command.delete_video_ack',
          id: request.id,
          payload: {'ok': false, 'reason': 'not_wired'},
        ),
      );
    };
    onUploadVideo ??= (request) async {
      await ws.send(
        DeviceWsEnvelope.build(
          type: 'command.upload_video_ack',
          id: request.id,
          payload: {'ok': false, 'reason': 'not_wired'},
        ),
      );
    };
    onProcessParam ??= (_) async {
      lwsTrace('cloud-runtime: process param push received (import deferred)');
    };
    onProcessLib ??= (_) async {
      lwsTrace('cloud-runtime: process lib push received (import deferred)');
    };

    dispatcher.onVideoListRequest = onVideoListRequest;
    dispatcher.onDeleteVideo = onDeleteVideo;
    dispatcher.onUploadVideo = onUploadVideo;
    dispatcher.onProcessParam = onProcessParam;
    dispatcher.onProcessLib = onProcessLib;
  }

  final AppServices services;
  final CloudSettingsStore cloudSettings;
  final DeviceRemoteLockStore lockStore;
  final ProcessLibraryController? processLibrary;
  final ProcessVideoRepository? processVideoRepository;

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
  late final DeviceLocalHttpServer localHttp;
  late final DeviceMdnsAdvertise mdns;

  void Function()? onAuthError;
  void Function(DeviceUsersProbeResult result)? onUsersProbe;
  Future<void> Function()? onClearAlerts;
  Future<void> Function(Object? payload)? onProcessParam;
  Future<void> Function(Object? payload)? onProcessLib;
  Future<void> Function(DeviceWsEnvelope request)? onVideoListRequest;
  Future<void> Function(DeviceWsEnvelope request)? onUploadVideo;
  Future<void> Function(DeviceWsEnvelope request)? onDeleteVideo;

  bool _started = false;

  /// Idempotent post–first-frame start.
  Future<void> startAfterFirstFrame() async {
    if (_started) {
      return;
    }
    _started = true;
    cloudSettings.warmRead();
    lockStore.warmRead();

    final httpOk = await localHttp.start();
    if (httpOk) {
      await _publishMdns();
    }

    try {
      final pin = await prober.probe(cloudSettings.environmentTier);
      if (pin == null) {
        lwsTrace('cloud-runtime: no API origin pinned');
        return;
      }
      final product = await services.ensureProductInfo();
      final sn = product.sn.trim();
      if (sn.isNotEmpty) {
        final users = await usersClient.probeUsers(pinnedBase: pin, deviceSn: sn);
        onUsersProbe?.call(users);
      }
      final wsUrl = DeviceApiOriginConfig.deviceWebSocketUri(
        pinnedHttpBase: pin,
        deviceSn: sn.isEmpty ? 'UNKNOWN' : sn,
      );
      await ws.connect(wsUrl);
    } catch (e) {
      debugPrint('cloud-runtime: start failed: $e');
    }
  }

  Future<void> reprobeAndReconnect() async {
    await ws.disconnect();
    prober.clearPin();
    final pin = await prober.probe(cloudSettings.environmentTier);
    if (pin == null) {
      return;
    }
    final product = await services.ensureProductInfo();
    final sn = product.sn.trim().isEmpty ? 'UNKNOWN' : product.sn.trim();
    await ws.reconnectClearingAuthLatch();
    await ws.connect(
      DeviceApiOriginConfig.deviceWebSocketUri(
        pinnedHttpBase: pin,
        deviceSn: sn,
      ),
    );
  }

  Future<void> dispose() async {
    await mdns.withdraw();
    await localHttp.stop();
    await ws.dispose();
  }

  Future<void> _onWsConnected() async {
    dispatcher.snapshotLoader = _loadSnapshot;
    await dispatcher.sendOnline();
  }

  Future<Map<String, Object?>> _loadSnapshot() async {
    final product = await services.ensureProductInfo();
    String? ssid;
    try {
      ssid = services.wifi.currentConnection.ssid;
    } catch (_) {}
    return snapshotPacker.pack(
      deviceSn: product.sn,
      brand: product.brand,
      model: product.model,
      wifiSsid: ssid,
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
}
