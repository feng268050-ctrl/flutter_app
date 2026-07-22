/// Product UI phases for Home status icon / Settings (not HAL health).
library;

enum IpCameraUiPhase { connecting, connected, failed }

final class IpCameraUiStatus {
  const IpCameraUiStatus({
    required this.phase,
    this.attempt = 0,
    this.detail,
  });

  final IpCameraUiPhase phase;
  final int attempt;
  final String? detail;

  static const connecting = IpCameraUiStatus(phase: IpCameraUiPhase.connecting);

  IpCameraUiStatus copyWith({
    IpCameraUiPhase? phase,
    int? attempt,
    String? detail,
    bool clearDetail = false,
  }) {
    return IpCameraUiStatus(
      phase: phase ?? this.phase,
      attempt: attempt ?? this.attempt,
      detail: clearDetail ? null : (detail ?? this.detail),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IpCameraUiStatus &&
        other.phase == phase &&
        other.attempt == attempt &&
        other.detail == detail;
  }

  @override
  int get hashCode => Object.hash(phase, attempt, detail);
}
