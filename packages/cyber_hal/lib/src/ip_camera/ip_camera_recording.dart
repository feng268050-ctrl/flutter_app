import 'dart:async';

/// Encoded video codec expected on an RTSP recording source.
enum IpCameraVideoCodec { h264, h265 }

/// Product-neutral RTSP-to-file recording request.
final class IpCameraRecordingRequest {
  const IpCameraRecordingRequest({
    required this.sourceCandidates,
    required this.outputPath,
    this.codec = IpCameraVideoCodec.h264,
    this.readyTimeout = const Duration(seconds: 30),
    this.retryDelay = const Duration(seconds: 1),
    this.finalizeTimeout = const Duration(seconds: 10),
  });

  /// Candidates are attempted in order and then cycled until [readyTimeout].
  final List<Uri> sourceCandidates;
  final String outputPath;
  final IpCameraVideoCodec codec;
  final Duration readyTimeout;
  final Duration retryDelay;
  final Duration finalizeTimeout;
}

enum IpCameraRecordingPhase {
  idle,
  preparing,
  recording,
  stopping,
  completed,
  failed,
}

/// Change-oriented recording lifecycle snapshot.
final class IpCameraRecordingStatus {
  const IpCameraRecordingStatus({
    required this.phase,
    this.outputPath,
    this.detail,
    this.startedAt,
    required this.updatedAt,
  });

  final IpCameraRecordingPhase phase;
  final String? outputPath;
  final String? detail;
  final DateTime? startedAt;
  final DateTime updatedAt;

  bool get isActive =>
      phase == IpCameraRecordingPhase.preparing ||
      phase == IpCameraRecordingPhase.recording ||
      phase == IpCameraRecordingPhase.stopping;

  @override
  bool operator ==(Object other) {
    return other is IpCameraRecordingStatus &&
        other.phase == phase &&
        other.outputPath == outputPath &&
        other.detail == detail &&
        other.startedAt == startedAt;
  }

  @override
  int get hashCode => Object.hash(phase, outputPath, detail, startedAt);
}

final class IpCameraRecordingResult {
  const IpCameraRecordingResult({
    required this.outputPath,
    required this.bytesWritten,
    required this.startedAt,
    required this.completedAt,
  });

  final String outputPath;
  final int bytesWritten;
  final DateTime startedAt;
  final DateTime completedAt;
}

/// One active recording at a time for a single IP-camera instance.
abstract interface class IpCameraRecordingController {
  Stream<IpCameraRecordingStatus> get status;
  IpCameraRecordingStatus get currentStatus;

  /// Resolves only after media reaches the muxer, not when a process is spawned.
  Future<IpCameraRecordingStatus> start(IpCameraRecordingRequest request);

  /// Cancels preparing, or finalizes and returns an active recording.
  Future<IpCameraRecordingResult?> stop();

  Future<void> dispose();
}
