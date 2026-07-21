/// How a signal relates to the previous active state.
enum AlarmSignalKind {
  /// inactive → active (or first observe active).
  rising,

  /// active → inactive.
  falling,

  /// Still active; timed re-notify (e.g. HAL reminder). Not a new onset.
  reminder,
}

/// Transport-agnostic alarm activity event for the coordinator.
final class AlarmSignalEvent {
  const AlarmSignalEvent({
    required this.code,
    required this.active,
    required this.kind,
    this.attributeId,
    this.labelHint,
  });

  final String code;
  final bool active;
  final AlarmSignalKind kind;

  /// Optional source attribute id (e.g. `alarm.gun_comm`).
  final String? attributeId;

  /// Optional label hint from transport meta.
  final String? labelHint;
}
