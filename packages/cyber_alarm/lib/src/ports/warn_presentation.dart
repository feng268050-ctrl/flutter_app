import 'package:cyber_alarm/src/domain/alarm_code.dart';
import 'package:cyber_alarm/src/domain/warn_episode.dart';

/// Outbound modal warn presentation (App implements with CyberUI).
abstract interface class WarnPresentation {
  /// Show or enqueue a warn dialog for [episode].
  Future<void> show(WarnEpisode episode, AlarmCodeEntry entry);

  /// Dismiss dialog for [code] if showing / queued.
  Future<void> dismiss(String code);

  /// Refresh visible dialog content (e.g. reminder) without new onset.
  Future<void> update(WarnEpisode episode, AlarmCodeEntry entry);
}
