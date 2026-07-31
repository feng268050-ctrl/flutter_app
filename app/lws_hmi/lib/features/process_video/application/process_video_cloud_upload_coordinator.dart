import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_video/application/process_video_upload_r2_keys.dart';
import 'package:lws_hmi/features/process_video/application/process_video_uploading_ws_throttle.dart';
import 'package:lws_hmi/features/process_video/application/video_cover_extractor.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_prober.dart';
import 'package:lws_hmi/platform/cloud/device_r2_put_object_client.dart';
import 'package:lws_hmi/platform/cloud/device_r2_sts_client.dart';
import 'package:lws_hmi/platform/cloud/device_ws_connection_manager.dart';
import 'package:lws_hmi/platform/cloud/device_ws_envelope.dart';

/// Progress callbacks for Monitor Upload dialog / tests.
abstract interface class ProcessVideoUploadListener {
  void onMetadataPhaseStarted();
  void onVideoProgress(int percent);
  void onFinishedSuccess();
  void onFinishedError(String message);
}

/// Single-flight cover-then-video cloud upload (lws-ui Monitor coordinator).
final class ProcessVideoCloudUploadCoordinator {
  ProcessVideoCloudUploadCoordinator({
    required this.services,
    required this.repository,
    required this.prober,
    required this.r2StsClient,
    required this.r2PutClient,
    required this.ws,
    VideoCoverExtractor? coverExtractor,
  }) : _coverExtractor = coverExtractor ?? VideoCoverExtractor();

  final AppServices services;
  final ProcessVideoRepository repository;
  final DeviceApiOriginProber prober;
  final DeviceR2StsClient r2StsClient;
  final DeviceR2PutObjectClient r2PutClient;
  final DeviceWsConnectionManager ws;
  final VideoCoverExtractor _coverExtractor;

  bool _busy = false;
  String? _activeVideoId;
  int _generation = 0;

  bool get isBusy => _busy;
  String? get activeVideoId => _activeVideoId;

  bool isUploading(String videoId) =>
      _busy && _activeVideoId == videoId;

  /// Drain all pending covers when Worker origin is pinned.
  Future<void> enqueuePendingCovers() async {
    final pin = prober.pinnedBase;
    if (pin == null) {
      return;
    }
    await repository.open();
    final pending = await repository.listPendingCoverUploads();
    for (final row in pending) {
      try {
        await uploadCoverIfNeeded(row);
      } catch (e) {
        debugPrint('process-video-cover: drain failed ${row.videoId}: $e');
      }
    }
  }

  /// Cover-only path (0→1). Returns updated row or null on failure.
  Future<ProcessVideoRecord?> uploadCoverIfNeeded(ProcessVideoRecord row) async {
    if (row.uploadStatus != ProcessVideoUploadStatus.notInitiated &&
        (row.coverUrl?.isNotEmpty ?? false)) {
      return row;
    }
    if (row.uploadStatus != ProcessVideoUploadStatus.notInitiated &&
        row.uploadStatus != ProcessVideoUploadStatus.coverUploaded) {
      return row;
    }
    final pin = prober.pinnedBase;
    if (pin == null) {
      throw StateError('no_api_origin');
    }
    final product = await services.ensureProductInfo();
    final sn = product.sn.trim();
    if (sn.isEmpty || sn == 'UNKNOWN') {
      throw StateError('invalid_sn');
    }
    final jpeg = await _coverExtractor.extractFirstFrameJpeg(
      videoPath: row.videoPath,
      videoId: row.videoId,
    );
    if (jpeg == null) {
      throw StateError('cover_extract_failed');
    }
    try {
      final sts = await r2StsClient.fetchSts(
        pinnedBase: pin,
        body: {'sn': sn, 'ttl_seconds': 900},
      );
      if (sts == null) {
        throw StateError('sts_failed');
      }
      final publicBase = sts.publicBaseUrl;
      if (publicBase == null || publicBase.isEmpty) {
        throw StateError('missing_public_base_url');
      }
      final key = ProcessVideoUploadR2Keys.videoObjectKey(
        sn: sn,
        yyyyMmDd: ProcessVideoUploadR2Keys.yyyyMmDdFromCreateTimeMs(
          row.createTimeMs,
        ),
        videoId: row.videoId,
        extLowerNoDot: 'jpg',
      );
      final ok = await r2PutClient.putFile(
        credentials: sts,
        objectKey: key,
        file: jpeg,
        contentType: 'image/jpeg',
      );
      if (!ok) {
        throw StateError('cover_put_failed');
      }
      final coverUrl =
          ProcessVideoUploadR2Keys.joinPublicBaseUrl(publicBase, key);
      await repository.updateUploadState(
        videoId: row.videoId,
        uploadStatus: ProcessVideoUploadStatus.coverUploaded,
        uploadProgress: 0,
        coverUrl: coverUrl,
      );
      final updated = await repository.findByVideoId(row.videoId) ??
          ProcessVideoRecord(
            id: row.id,
            videoId: row.videoId,
            videoPath: row.videoPath,
            processType: row.processType,
            materialType: row.materialType,
            processParametersJson: row.processParametersJson,
            fileSize: row.fileSize,
            durationMs: row.durationMs,
            resolution: row.resolution,
            createTimeMs: row.createTimeMs,
            uploadStatus: ProcessVideoUploadStatus.coverUploaded,
            coverUrl: coverUrl,
            videoUrl: row.videoUrl,
          );
      await _emitVideoMetadata(updated);
      return updated;
    } finally {
      try {
        await jpeg.delete();
      } catch (_) {}
    }
  }

  /// Full upload (cover if needed, then MP4). Single-flight.
  Future<bool> uploadVideo(
    String videoId, {
    ProcessVideoUploadListener? listener,
  }) async {
    if (_busy) {
      if (_activeVideoId == videoId) {
        return false;
      }
      // Replace in-flight with newer request (lws-ui cancel/replace).
      _generation++;
    }
    final gen = ++_generation;
    _busy = true;
    _activeVideoId = videoId;
    try {
      await repository.open();
      var row = await repository.findByVideoId(videoId);
      if (row == null) {
        listener?.onFinishedError('video_not_found');
        return false;
      }
      if (row.uploadStatus == ProcessVideoUploadStatus.videoUploaded) {
        listener?.onFinishedError('already_uploaded');
        return false;
      }
      final pin = prober.pinnedBase;
      if (pin == null) {
        listener?.onFinishedError('no_api_origin');
        return false;
      }
      final file = File(row.videoPath);
      if (!await file.exists()) {
        listener?.onFinishedError('file_missing');
        return false;
      }

      listener?.onMetadataPhaseStarted();
      if (row.uploadStatus == ProcessVideoUploadStatus.notInitiated ||
          (row.coverUrl == null || row.coverUrl!.isEmpty)) {
        row = await uploadCoverIfNeeded(row);
        if (row == null || gen != _generation) {
          listener?.onFinishedError('cover_failed');
          return false;
        }
      }

      if (row.uploadStatus == ProcessVideoUploadStatus.videoUploading) {
        await repository.updateUploadState(
          videoId: videoId,
          uploadStatus: ProcessVideoUploadStatus.coverUploaded,
          uploadProgress: 0,
        );
        row = await repository.findByVideoId(videoId) ?? row;
      }

      final product = await services.ensureProductInfo();
      final sn = product.sn.trim();
      if (sn.isEmpty) {
        listener?.onFinishedError('invalid_sn');
        return false;
      }

      await repository.updateUploadState(
        videoId: videoId,
        uploadStatus: ProcessVideoUploadStatus.videoUploading,
        uploadProgress: 0,
      );
      final wsThrottle = ProcessVideoUploadingWsThrottle();
      await _emitUploading(
        videoId,
        ProcessVideoUploadStatus.videoUploading,
        0,
        '',
      );
      listener?.onVideoProgress(0);

      final sts = await r2StsClient.fetchSts(
        pinnedBase: pin,
        body: {'sn': sn, 'ttl_seconds': 900},
      );
      if (sts == null || gen != _generation) {
        await _revertAfterVideoFailure(videoId);
        listener?.onFinishedError('sts_failed');
        return false;
      }
      final key = ProcessVideoUploadR2Keys.videoObjectKey(
        sn: sn,
        yyyyMmDd: ProcessVideoUploadR2Keys.yyyyMmDdFromCreateTimeMs(
          row.createTimeMs,
        ),
        videoId: videoId,
        extLowerNoDot: ProcessVideoUploadR2Keys.extFromPath(row.videoPath),
      );

      var lastDbBucket = -1;
      final putOk = await r2PutClient.putFile(
        credentials: sts,
        objectKey: key,
        file: file,
        contentType: 'video/mp4',
        onProgress: (read, total) {
          if (gen != _generation) {
            return;
          }
          final pct = total <= 0
              ? 0
              : ((read * 100) ~/ total).clamp(0, 100);
          final bucket = pct ~/ 2;
          if (bucket != lastDbBucket) {
            lastDbBucket = bucket;
            unawaited(
              repository.updateUploadState(
                videoId: videoId,
                uploadStatus: ProcessVideoUploadStatus.videoUploading,
                uploadProgress: pct,
              ),
            );
            listener?.onVideoProgress(pct);
          }
          if (wsThrottle.shouldEmit(pct)) {
            unawaited(
              _emitUploading(
                videoId,
                ProcessVideoUploadStatus.videoUploading,
                pct,
                '',
              ),
            );
          }
        },
      );
      if (!putOk || gen != _generation) {
        await _revertAfterVideoFailure(videoId);
        listener?.onFinishedError('r2_put_failed');
        return false;
      }

      final joined = ProcessVideoUploadR2Keys.joinPublicBaseUrl(
        sts.publicBaseUrl,
        key,
      );
      final videoUrl =
          joined.isNotEmpty ? joined : _fallbackVideoUrl(sts, key);

      await repository.updateUploadState(
        videoId: videoId,
        uploadStatus: ProcessVideoUploadStatus.videoUploaded,
        uploadProgress: 100,
        videoUrl: videoUrl,
      );
      // lws-ui: terminal progress via video.uploading only (no second metadata).
      await _emitUploading(
        videoId,
        ProcessVideoUploadStatus.videoUploaded,
        100,
        videoUrl,
      );
      listener?.onVideoProgress(100);
      listener?.onFinishedSuccess();
      return true;
    } catch (e) {
      debugPrint('process-video-upload: failed $videoId: $e');
      await _revertAfterVideoFailure(videoId);
      listener?.onFinishedError(e.toString());
      return false;
    } finally {
      if (gen == _generation) {
        _busy = false;
        _activeVideoId = null;
      }
    }
  }

  /// After a failed media PutObject, keep cover status when coverUrl exists;
  /// otherwise leave/reset to not-initiated (do not fake status 1).
  Future<void> _revertAfterVideoFailure(String videoId) async {
    try {
      final row = await repository.findByVideoId(videoId);
      if (row == null) {
        return;
      }
      final hasCover = row.coverUrl != null && row.coverUrl!.isNotEmpty;
      await repository.updateUploadState(
        videoId: videoId,
        uploadStatus: hasCover
            ? ProcessVideoUploadStatus.coverUploaded
            : ProcessVideoUploadStatus.notInitiated,
        uploadProgress: 0,
      );
    } catch (_) {}
  }

  String _fallbackVideoUrl(R2StsCredentials sts, String key) {
    final endpoint = sts.endpoint.replaceAll(RegExp(r'/+$'), '');
    return '$endpoint/${sts.bucket}/$key';
  }

  Future<void> _emitUploading(
    String videoId,
    int status,
    int progress,
    String videoUrl,
  ) async {
    try {
      await ws.send(
        DeviceWsEnvelope.build(
          type: 'video.uploading',
          payload: {
            'videoId': videoId,
            'uploadStatus': status,
            'uploadProgress': progress,
            'videoUrl': videoUrl,
          },
        ),
      );
    } catch (e) {
      debugPrint('process-video-upload: video.uploading emit failed: $e');
    }
  }

  Future<void> _emitVideoMetadata(
    ProcessVideoRecord r, {
    String? videoUrlOverride,
  }) async {
    try {
      await ws.send(
        DeviceWsEnvelope.build(
          type: 'video.metadata',
          payload: {
            'videoId': r.videoId,
            'processParametersJson': r.snapshot?.toJsonString(),
            'processType': r.processType.wireValue,
            'materialType': r.materialType?.storageValue,
            'fileSize': r.fileSize,
            'duration': r.durationMs,
            'createTime': r.createTimeMs,
            'resolution': r.resolution,
            'uploadStatus': r.uploadStatus,
            'uploadProgress': r.uploadProgress,
            'coverUrl': r.coverUrl ?? '',
            'videoUrl': videoUrlOverride ?? r.videoUrl ?? '',
          },
        ),
      );
    } catch (e) {
      debugPrint('process-video-upload: video.metadata emit failed: $e');
    }
  }
}
