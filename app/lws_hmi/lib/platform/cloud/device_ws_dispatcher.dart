import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';
import 'package:lws_hmi/platform/cloud/device_remote_snapshot.dart';
import 'package:lws_hmi/platform/cloud/device_ws_connection_manager.dart';
import 'package:lws_hmi/platform/cloud/device_ws_envelope.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// Dispatches non-OTA device WebSocket commands.
final class DeviceWsDispatcher {
  DeviceWsDispatcher({
    required this.ws,
    required this.lockStore,
    required this.snapshotPacker,
    this.snapshotLoader,
    this.onClearAlerts,
    this.onProcessParam,
    this.onProcessLib,
    this.onVideoListRequest,
    this.onUploadVideo,
    this.onDeleteVideo,
  });

  final DeviceWsConnectionManager ws;
  final DeviceRemoteLockStore lockStore;
  final DeviceRemoteSnapshotPacker snapshotPacker;

  /// Returns current snapshot map for online/stat.
  Future<Map<String, Object?>> Function()? snapshotLoader;

  Future<void> Function()? onClearAlerts;
  Future<void> Function(Object? payload)? onProcessParam;
  Future<void> Function(Object? payload)? onProcessLib;
  Future<void> Function(DeviceWsEnvelope request)? onVideoListRequest;
  Future<void> Function(DeviceWsEnvelope request)? onUploadVideo;
  Future<void> Function(DeviceWsEnvelope request)? onDeleteVideo;

  Future<void> handle(DeviceWsEnvelope envelope) async {
    if (envelope.isOtaRelated) {
      lwsTrace('device-ws: OTA no-op type=${envelope.type}');
      await ws.send(
        DeviceWsEnvelope.build(
          type: '${envelope.type}_ack',
          id: envelope.id,
          payload: {
            'ok': false,
            'unsupported': true,
            'reason': 'ota_deferred',
          },
        ),
      );
      return;
    }

    switch (envelope.type) {
      case 'command.stat_request':
        await _sendStat(envelope.id);
      case 'command.lock':
        await lockStore.setLocked(true);
        await _ack(envelope, ok: true);
      case 'command.unlock':
        await lockStore.setLocked(false);
        await _ack(envelope, ok: true);
      case 'command.clear_alerts':
        await onClearAlerts?.call();
        await _ack(envelope, ok: true);
      case 'command.disconnect':
        await ws.disconnect(forced: true);
      case 'command.send_process_param':
        await onProcessParam?.call(envelope.payload);
        await _ack(envelope, ok: true);
      case 'command.send_process_lib':
        await onProcessLib?.call(envelope.payload);
        await _ack(envelope, ok: true);
      case 'command.video_list_request':
        await onVideoListRequest?.call(envelope);
      case 'command.upload_video':
        await onUploadVideo?.call(envelope);
      case 'command.delete_video':
        await onDeleteVideo?.call(envelope);
      default:
        debugPrint('device-ws: unhandled type=${envelope.type}');
    }
  }

  Future<void> sendOnline() async {
    final snap = await _loadSnapshot();
    await ws.send(
      DeviceWsEnvelope.build(
        type: 'device.online',
        payload: {'stat': snap},
      ),
    );
  }

  Future<void> _sendStat(String requestId) async {
    final snap = await _loadSnapshot();
    await ws.send(
      DeviceWsEnvelope.build(
        type: 'command.stat_response',
        id: requestId,
        payload: {'stat': snap},
      ),
    );
  }

  Future<Map<String, Object?>> _loadSnapshot() async {
    final loader = snapshotLoader;
    if (loader != null) {
      return loader();
    }
    return snapshotPacker.pack(
      deviceSn: '',
      brand: '',
      model: '',
    );
  }

  Future<void> _ack(DeviceWsEnvelope envelope, {required bool ok}) async {
    await ws.send(
      DeviceWsEnvelope.build(
        type: '${envelope.type}_ack',
        id: envelope.id,
        payload: {'ok': ok},
      ),
    );
  }
}
