import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';
import 'package:lws_hmi/platform/cloud/device_remote_snapshot.dart';
import 'package:lws_hmi/platform/cloud/device_ws_connection_manager.dart';
import 'package:lws_hmi/platform/cloud/device_ws_envelope.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// Dispatches device WebSocket commands (lws-ui parity).
final class DeviceWsDispatcher {
  DeviceWsDispatcher({
    required this.ws,
    required this.lockStore,
    required this.snapshotPacker,
    this.snapshotLoader,
    this.onClearAlerts,
    this.onProcessParam,
    this.onProcessLib,
    this.onProcessLibraryRequest,
    this.onProcessParametersRequest,
    this.onProcessParametersCreate,
    this.onProcessParametersUpdate,
    this.onProcessParametersDelete,
    this.onProcessParametersSetDefault,
    this.onVideoListRequest,
    this.onUploadVideo,
    this.onDeleteVideo,
    this.onRemoteLockChanged,
    this.onForcedDisconnect,
    this.onLockSafetyStop,
  });

  final DeviceWsConnectionManager ws;
  final DeviceRemoteLockStore lockStore;
  final DeviceRemoteSnapshotPacker snapshotPacker;

  Future<Map<String, Object?>> Function()? snapshotLoader;

  Future<bool> Function()? onClearAlerts;
  /// Returns null on success; non-null = failure message.
  Future<String?> Function(Object? payload)? onProcessParam;
  Future<String?> Function(Object? payload)? onProcessLib;
  Future<void> Function(DeviceWsEnvelope request)? onProcessLibraryRequest;
  Future<void> Function(DeviceWsEnvelope request)? onProcessParametersRequest;
  Future<void> Function(DeviceWsEnvelope request)? onProcessParametersCreate;
  Future<void> Function(DeviceWsEnvelope request)? onProcessParametersUpdate;
  Future<void> Function(DeviceWsEnvelope request)? onProcessParametersDelete;
  Future<void> Function(DeviceWsEnvelope request)? onProcessParametersSetDefault;
  Future<void> Function(DeviceWsEnvelope request)? onVideoListRequest;
  Future<void> Function(DeviceWsEnvelope request)? onUploadVideo;
  Future<void> Function(DeviceWsEnvelope request)? onDeleteVideo;

  /// Called after lock flag persists (`true` = locked).
  Future<void> Function(bool locked)? onRemoteLockChanged;

  /// Best-effort Modbus safety stop when locking.
  Future<void> Function()? onLockSafetyStop;

  /// After forced disconnect (UI notice).
  Future<void> Function(String reason)? onForcedDisconnect;

  /// OTA manifest check (`command.check_update`). Returns ack `data` map.
  Future<Map<String, Object?>> Function(DeviceWsEnvelope envelope)?
      onOtaCheckUpdate;

  /// OTA apply start (`command.update_system`). Returns ack `data` map.
  Future<Map<String, Object?>> Function(DeviceWsEnvelope envelope)?
      onOtaUpdateSystem;

  Future<void> handle(DeviceWsEnvelope envelope) async {
    debugPrint(
      'device-ws: recv type=${envelope.type} id=${envelope.id}',
    );

    if (envelope.isOtaRelated) {
      await _handleOta(envelope);
      return;
    }

    switch (envelope.type) {
      case 'command.stat_request':
        await _sendStat(envelope.id);
      case 'command.lock':
        await lockStore.setLocked(true);
        try {
          await onLockSafetyStop?.call();
        } catch (e) {
          debugPrint('device-ws: lock safety stop failed: $e');
        }
        try {
          await onRemoteLockChanged?.call(true);
        } catch (e) {
          debugPrint('device-ws: lock UI callback failed: $e');
        }
      case 'command.unlock':
        await lockStore.setLocked(false);
        try {
          await onRemoteLockChanged?.call(false);
        } catch (e) {
          debugPrint('device-ws: unlock UI callback failed: $e');
        }
      case 'command.clear_alerts':
        final ok = await onClearAlerts?.call() ?? false;
        await sendDataAck(
          type: 'command.clear_alerts_ack',
          requestId: envelope.id,
          success: ok,
          message: ok ? 'ok' : 'clear_alerts_failed',
        );
      case 'command.disconnect':
        final reason = envelope.payload is Map
            ? (envelope.payload as Map)['reason']?.toString() ?? ''
            : '';
        await ws.disconnect(forced: true);
        try {
          await onForcedDisconnect?.call(reason);
        } catch (e) {
          debugPrint('device-ws: disconnect notice failed: $e');
        }
      case 'command.send_process_param':
        final err = await onProcessParam?.call(envelope.payload);
        await sendProcessAck(
          type: 'command.send_process_param_ack',
          requestId: envelope.id,
          code: err == null ? 200 : 500,
          message: err ?? 'ok',
        );
      case 'command.send_process_lib':
        final err = await onProcessLib?.call(envelope.payload);
        await sendProcessAck(
          type: 'command.send_process_lib_ack',
          requestId: envelope.id,
          code: err == null ? 200 : 500,
          message: err ?? 'ok',
        );
      case 'command.process_library_request':
        await onProcessLibraryRequest?.call(envelope);
      case 'command.process_parameters_request':
        await onProcessParametersRequest?.call(envelope);
      case 'command.process_parameters_create':
        await onProcessParametersCreate?.call(envelope);
      case 'command.process_parameters_update':
        await onProcessParametersUpdate?.call(envelope);
      case 'command.process_parameters_delete':
        await onProcessParametersDelete?.call(envelope);
      case 'command.process_parameters_set_default':
        await onProcessParametersSetDefault?.call(envelope);
      case 'command.video_list_request':
        await onVideoListRequest?.call(envelope);
      case 'command.upload_video':
        await onUploadVideo?.call(envelope);
      case 'command.delete_video':
        await onDeleteVideo?.call(envelope);
      case 'command.error':
        debugPrint(
          'device-ws: command.error id=${envelope.id} payload=${envelope.payload}',
        );
      case 'connected':
      case 'ack':
        break;
      default:
        debugPrint(
          'device-ws: unhandled type=${envelope.type} '
          'id=${envelope.id} payload=${envelope.payload}',
        );
    }
  }

  Future<void> _handleOta(DeviceWsEnvelope envelope) async {
    switch (envelope.type) {
      case 'command.check_update':
        final data = await onOtaCheckUpdate?.call(envelope) ??
            _otaNotConfiguredAck();
        await ws.send(
          DeviceWsEnvelope.build(
            type: 'command.check_update_ack',
            payload: {
              'request_id': envelope.id,
              'data': data,
            },
          ),
        );
      case 'command.update_system':
        final data = await onOtaUpdateSystem?.call(envelope) ??
            _otaNotConfiguredAck();
        await ws.send(
          DeviceWsEnvelope.build(
            type: 'command.update_system_ack',
            payload: {
              'request_id': envelope.id,
              'data': data,
            },
          ),
        );
      case 'device.update_progress':
        // Inbound progress is ignored; device emits while a session runs.
        break;
      default:
        lwsTrace('device-ws: unhandled OTA type=${envelope.type}');
        break;
    }
  }

  static Map<String, Object?> _otaNotConfiguredAck() {
    return {
      'ok': false,
      'has_update': false,
      'started': false,
      'error_code': 'manifest_unavailable',
      'error_message': 'OTA manifest URL is not configured',
    };
  }

  /// Emit OTA progress to cloud subscribers.
  Future<void> sendUpdateProgress(Map<String, Object?> data) {
    return ws.send(
      DeviceWsEnvelope.build(
        type: 'device.update_progress',
        payload: {'data': data},
      ),
    );
  }

  Future<void> sendOnline() async {
    final snap = await _loadSnapshot();
    final info = snap['deviceInfo'];
    final sn = info is Map ? info['sn'] : null;
    final envelope = DeviceWsEnvelope.build(
      type: 'device.online',
      payload: {'stat': snap},
    );
    final json = envelope.encode();
    debugPrint(
      'device-ws: send device.online sn=$sn state=${ws.state} jsonLen=${json.length}',
    );
    await ws.send(envelope);
  }

  Future<void> sendProcessAck({
    required String type,
    required String requestId,
    required int code,
    required String message,
  }) {
    return ws.send(
      DeviceWsEnvelope.build(
        type: type,
        payload: {
          'request_id': requestId,
          'code': code,
          'message': message,
        },
      ),
    );
  }

  Future<void> sendDataAck({
    required String type,
    required String requestId,
    required bool success,
    required String message,
    String? createdId,
  }) {
    final data = <String, Object?>{
      'success': success,
      'message': message,
      if (createdId != null) 'id': createdId,
    };
    return ws.send(
      DeviceWsEnvelope.build(
        type: type,
        payload: {
          'request_id': requestId,
          'data': data,
        },
      ),
    );
  }

  Future<void> _sendStat(String requestId) async {
    final snap = await _loadSnapshot();
    await ws.send(
      DeviceWsEnvelope.build(
        type: 'command.stat_response',
        payload: {
          'request_id': requestId,
          'data': snap,
        },
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
}
