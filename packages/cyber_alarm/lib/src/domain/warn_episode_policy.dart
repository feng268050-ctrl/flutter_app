/// Frozen when an episode is armed (lws-ui `WarnEpisodePolicy`).
final class WarnEpisodePolicy {
  const WarnEpisodePolicy({
    this.resistExternalAutoClose = false,
    this.demoSimulated = false,
  });

  /// When true, fault clear alone does not dismiss; operator ack required.
  final bool resistExternalAutoClose;

  final bool demoSimulated;

  static const productionPassive = WarnEpisodePolicy();

  static const productionResist = WarnEpisodePolicy(
    resistExternalAutoClose: true,
  );

  static const demoAlarm = WarnEpisodePolicy(
    resistExternalAutoClose: true,
    demoSimulated: true,
  );
}
