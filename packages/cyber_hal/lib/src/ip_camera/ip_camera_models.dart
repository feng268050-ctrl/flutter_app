/// Portable IP network camera models (host + upstream streams + health).
library;

/// Native RTSP path suffixes on the camera (not local relay).
final class IpCameraStreamPaths {
  const IpCameraStreamPaths({
    this.pr0Path = '/PR0',
    this.pr1Path = '/PR1',
  });

  /// Default Hikvision-style dual stream paths used by LWS IPC.
  const IpCameraStreamPaths.pr01() : this();

  final String pr0Path;
  final String pr1Path;
}

/// Upstream RTSP URIs on the camera host (never localhost MediaMTX).
final class IpCameraStreams {
  const IpCameraStreams({required this.pr0, required this.pr1});

  factory IpCameraStreams.fromHost(
    String cameraHost, {
    IpCameraStreamPaths paths = const IpCameraStreamPaths.pr01(),
  }) {
    final host = cameraHost.trim();
    return IpCameraStreams(
      pr0: Uri(scheme: 'rtsp', host: host, path: paths.pr0Path),
      pr1: Uri(scheme: 'rtsp', host: host, path: paths.pr1Path),
    );
  }

  final Uri pr0;
  final Uri pr1;
}

enum IpCameraHealthPhase {
  /// Monitoring not started or no conclusive probe yet.
  unknown,

  /// Stably reachable (recovery may require consecutive OK probes).
  healthy,

  /// Unreachable after policy applied.
  unhealthy,
}

/// Change-oriented health snapshot for one [IpCameraController] instance.
final class IpCameraHealth {
  const IpCameraHealth({
    required this.phase,
    this.consecutiveOk = 0,
    this.consecutiveFail = 0,
    this.detail,
    required this.updatedAt,
  });

  final IpCameraHealthPhase phase;
  final int consecutiveOk;
  final int consecutiveFail;
  final String? detail;
  final DateTime updatedAt;

  bool get isHealthy => phase == IpCameraHealthPhase.healthy;

  IpCameraHealth copyWith({
    IpCameraHealthPhase? phase,
    int? consecutiveOk,
    int? consecutiveFail,
    String? detail,
    DateTime? updatedAt,
    bool clearDetail = false,
  }) {
    return IpCameraHealth(
      phase: phase ?? this.phase,
      consecutiveOk: consecutiveOk ?? this.consecutiveOk,
      consecutiveFail: consecutiveFail ?? this.consecutiveFail,
      detail: clearDetail ? null : (detail ?? this.detail),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IpCameraHealth &&
        other.phase == phase &&
        other.consecutiveOk == consecutiveOk &&
        other.consecutiveFail == consecutiveFail &&
        other.detail == detail;
  }

  @override
  int get hashCode => Object.hash(phase, consecutiveOk, consecutiveFail, detail);
}

/// Injectable one-shot reachability probe.
///
/// Built-ins: [icmpIpCameraProbe], [tcpRtspPortProbe], [rtspOptionsProbe],
/// [relayInformedProbe]. MUST NOT SETUP/PLAY native `/PR0` or `/PR1`.
typedef IpCameraProbe = Future<bool> Function(String cameraHost);
