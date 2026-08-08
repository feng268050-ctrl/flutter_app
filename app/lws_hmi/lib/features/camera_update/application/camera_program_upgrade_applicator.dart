import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/camera_update/domain/camera_firmware_upload_payload.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_show_overlay_applier.dart';

/// Outcome of one camera CGI flash + reboot + wait-online session.
enum CameraProgramUpgradeOutcome {
  success,
  transferFailed,
  rebootFailed,
  waitTimeout,
}

final class CameraProgramUpgradeResult {
  const CameraProgramUpgradeResult({
    required this.outcome,
    this.errorMessage,
    this.httpStatus,
  });

  final CameraProgramUpgradeOutcome outcome;
  final String? errorMessage;
  final int? httpStatus;

  bool get isSuccess => outcome == CameraProgramUpgradeOutcome.success;
}

/// App-defined progress phases for `cyber_upgrade_ui`.
enum CameraProgramUpgradePhase {
  transfer,
  reboot,
  waitOnline,
}

/// Flashes camera firmware via CGI multipart, then reboots and waits online.
///
/// Port split (from camera `/System/network`):
/// - [apiPort] (`httpPort`, default 9000): deviceinfo / reboot JSON API
/// - [cgiPort] (`webServerPort`, default 80): Boa `POST /cgi-bin/cgic_upgrade`
final class CameraProgramUpgradeApplicator {
  CameraProgramUpgradeApplicator({
    CameraOsdHttpClient? httpClient,
    CameraDeviceInfoCache? deviceInfoCache,
    Future<String?> Function(String cameraHost)? probeOnline,
    this.apiPort = 9000,
    this.cgiPort = 80,
    this.waitOnlineTimeout = const Duration(seconds: 120),
    this.waitOnlinePollInterval = const Duration(seconds: 2),
    String authorization = '',
    Duration? initialOfflineGrace,
  })  : _http = httpClient ?? DartCameraOsdHttpClient(),
        _ownsHttp = httpClient == null,
        _deviceInfo = deviceInfoCache ?? CameraDeviceInfoCache(),
        _ownsDeviceInfo = deviceInfoCache == null,
        _probeOnline = probeOnline,
        _authorization = authorization.isEmpty
            ? cameraHttpBasicAuthorization()
            : authorization,
        _initialOfflineGrace =
            initialOfflineGrace ?? const Duration(seconds: 3);

  final CameraOsdHttpClient _http;
  final bool _ownsHttp;
  final CameraDeviceInfoCache _deviceInfo;
  final bool _ownsDeviceInfo;
  final Future<String?> Function(String cameraHost)? _probeOnline;

  /// MJPG-Streamer JSON API (deviceinfo / reboot).
  final int apiPort;

  /// Boa web server CGI upgrade port.
  final int cgiPort;

  final Duration waitOnlineTimeout;
  final Duration waitOnlinePollInterval;
  final String _authorization;
  final Duration _initialOfflineGrace;

  /// POST `/cgi-bin/cgic_upgrade` → PUT `/System/reboot` → poll deviceinfo.
  Future<CameraProgramUpgradeResult> upgrade({
    required String cameraHost,
    required String fileName,
    required Uint8List bytes,
    void Function(CameraProgramUpgradePhase phase, int? percent)? onProgress,
  }) async {
    final host = cameraHost.trim();
    if (host.isEmpty) {
      return const CameraProgramUpgradeResult(
        outcome: CameraProgramUpgradeOutcome.transferFailed,
        errorMessage: 'camera_host_missing',
      );
    }

    final upgradeUri = Uri(
      scheme: 'http',
      host: host,
      port: cgiPort,
      path: '/cgi-bin/cgic_upgrade',
    );
    onProgress?.call(CameraProgramUpgradePhase.transfer, 0);
    try {
      final payload = CameraFirmwareUploadPayload.resolve(
        sourceFileName: fileName,
        bytes: bytes,
      );
      debugPrint(
        'CameraProgramUpgradeApplicator: upload ${payload.fileName} '
        '(${payload.bytes.length} bytes) → $upgradeUri',
      );
      final transfer = await _http.postMultipartFile(
        upgradeUri,
        authorization: _authorization,
        fieldName: 'file',
        fileName: payload.fileName,
        fileBytes: payload.bytes,
        onSendProgress: (sent, total) {
          if (total <= 0) {
            onProgress?.call(CameraProgramUpgradePhase.transfer, null);
            return;
          }
          final pct = ((sent / total) * 100).round().clamp(0, 99);
          onProgress?.call(CameraProgramUpgradePhase.transfer, pct);
        },
      );
      if (transfer.statusCode != 200) {
        return CameraProgramUpgradeResult(
          outcome: CameraProgramUpgradeOutcome.transferFailed,
          errorMessage: 'cgi_status_${transfer.statusCode}',
          httpStatus: transfer.statusCode,
        );
      }
      onProgress?.call(CameraProgramUpgradePhase.transfer, 100);
    } catch (e, st) {
      debugPrint('CameraProgramUpgradeApplicator: transfer failed: $e\n$st');
      return CameraProgramUpgradeResult(
        outcome: CameraProgramUpgradeOutcome.transferFailed,
        errorMessage: '$e',
      );
    }

    final rebootUri = Uri(
      scheme: 'http',
      host: host,
      port: apiPort,
      path: '/System/reboot',
    );
    onProgress?.call(CameraProgramUpgradePhase.reboot, null);
    try {
      final reboot = await _http.put(
        rebootUri,
        authorization: _authorization,
      );
      if (reboot.statusCode != 200) {
        return CameraProgramUpgradeResult(
          outcome: CameraProgramUpgradeOutcome.rebootFailed,
          errorMessage: 'reboot_status_${reboot.statusCode}',
          httpStatus: reboot.statusCode,
        );
      }
    } catch (e, st) {
      debugPrint('CameraProgramUpgradeApplicator: reboot failed: $e\n$st');
      return CameraProgramUpgradeResult(
        outcome: CameraProgramUpgradeOutcome.rebootFailed,
        errorMessage: '$e',
      );
    }

    onProgress?.call(CameraProgramUpgradePhase.waitOnline, null);
    // Brief grace so we do not treat the pre-reboot socket as still online.
    await Future<void>.delayed(_initialOfflineGrace);
    final deadline = DateTime.now().add(waitOnlineTimeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final raw = await _probe(host);
        if (raw != null && raw.isNotEmpty) {
          onProgress?.call(CameraProgramUpgradePhase.waitOnline, 100);
          return const CameraProgramUpgradeResult(
            outcome: CameraProgramUpgradeOutcome.success,
          );
        }
      } catch (_) {}
      await Future<void>.delayed(waitOnlinePollInterval);
    }

    return const CameraProgramUpgradeResult(
      outcome: CameraProgramUpgradeOutcome.waitTimeout,
      errorMessage: 'wait_online_timeout',
    );
  }

  Future<String?> _probe(String host) async {
    final custom = _probeOnline;
    if (custom != null) {
      return custom(host);
    }
    _deviceInfo.invalidate();
    return _deviceInfo.fetchRawAppVersion(host);
  }

  void dispose() {
    if (_ownsHttp) {
      _http.close();
    }
    if (_ownsDeviceInfo) {
      _deviceInfo.dispose();
    }
  }
}
