import 'package:cyber_alarm/src/domain/warn_episode_policy.dart';

enum WarnEpisodePhase {
  /// Fault armed; operator has not confirmed this cycle.
  faultActive,

  /// Operator confirmed; fault may still be active.
  operatorAcked,
}

/// One coded warn episode lifecycle record.
final class WarnEpisode {
  WarnEpisode({
    required this.code,
    required this.policy,
    this.phase = WarnEpisodePhase.faultActive,
    this.faultActive = true,
    this.dialogOpen = false,
  });

  final String code;
  final WarnEpisodePolicy policy;
  WarnEpisodePhase phase;
  bool faultActive;
  bool dialogOpen;
}
