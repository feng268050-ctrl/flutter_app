/// How [ProcessSupervisor] reacts when a wanted child exits.
sealed class RestartPolicy {
  const RestartPolicy();

  /// Do not respawn after exit.
  static const none = RestartNone();

  /// Respawn after [delay], optionally capping consecutive failures with [maxBurst].
  const factory RestartPolicy.onFailure({
    Duration delay,
    int? maxBurst,
  }) = RestartOnFailure;
}

final class RestartNone extends RestartPolicy {
  const RestartNone();
}

final class RestartOnFailure extends RestartPolicy {
  const RestartOnFailure({
    this.delay = const Duration(seconds: 3),
    this.maxBurst,
  });

  final Duration delay;

  /// When non-null, stop respawning after this many consecutive unexpected exits.
  final int? maxBurst;
}
