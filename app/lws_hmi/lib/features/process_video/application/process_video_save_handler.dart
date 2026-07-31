import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';

/// Outcome of persisting a completed Record Work MP4 into the process-video index.
enum ProcessVideoSaveOutcome {
  saved,
  discardedTooShort,
  discardedMissingFile,
  failed,
}

/// Validates MP4 + inserts a process-video row (lws-ui `CameraRecordSaveHandler`).
final class ProcessVideoSaveHandler {
  ProcessVideoSaveHandler({
    required this.repository,
    this.minDuration = const Duration(milliseconds: 1000),
    this.defaultResolution = '1920x1080',
    this.afterSave,
    Random? random,
  }) : _random = random ?? Random.secure();

  final ProcessVideoRepository repository;
  final Duration minDuration;
  final String defaultResolution;
  final Random _random;

  /// Optional cloud cover enqueue (lws-ui CoverWorker after insert).
  final Future<void> Function(ProcessVideoRecord saved)? afterSave;

  Future<ProcessVideoSaveOutcome> save({
    required String videoPath,
    required ProcessVideoSnapshot snapshot,
    required int bytesWritten,
    required DateTime startedAt,
    required DateTime completedAt,
  }) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        return ProcessVideoSaveOutcome.discardedMissingFile;
      }
      final fileSize = await file.length();
      if (fileSize <= 0 && bytesWritten <= 0) {
        return ProcessVideoSaveOutcome.discardedMissingFile;
      }
      final durationMs = completedAt.difference(startedAt).inMilliseconds;
      if (durationMs < minDuration.inMilliseconds) {
        try {
          await file.delete();
        } catch (_) {
          // Best-effort cleanup of too-short clips.
        }
        return ProcessVideoSaveOutcome.discardedTooShort;
      }
      await repository.open();
      final saved = await repository.insert(
        ProcessVideoRecord(
          videoId: _newVideoId(),
          videoPath: videoPath,
          processType: snapshot.processType,
          materialType: snapshot.materialType,
          processParametersJson: snapshot.toJsonString(),
          fileSize: fileSize > 0 ? fileSize : bytesWritten,
          durationMs: durationMs,
          resolution: defaultResolution,
          createTimeMs: completedAt.toUtc().millisecondsSinceEpoch,
        ),
      );
      final hook = afterSave;
      if (hook != null) {
        try {
          await hook(saved);
        } catch (e) {
          debugPrint('process-video afterSave failed: $e');
        }
      }
      return ProcessVideoSaveOutcome.saved;
    } catch (e) {
      debugPrint('process-video save failed: $e');
      return ProcessVideoSaveOutcome.failed;
    }
  }

  String _newVideoId() {
    final ms = DateTime.now().toUtc().millisecondsSinceEpoch;
    final n = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$ms-$n';
  }
}
