/// Shared warn/alarm episode engine (product-domain layer).
///
/// Pure Dart — no Flutter / cyber_hal imports. Apps implement ports.
library;

export 'src/application/warn_alarm_coordinator.dart';
export 'src/catalog/alarm_code_catalog.dart';
export 'src/domain/alarm_code.dart';
export 'src/domain/alarm_signal_event.dart';
export 'src/domain/warn_episode.dart';
export 'src/domain/warn_episode_policy.dart';
export 'src/ports/alarm_log_repository.dart';
export 'src/ports/alarm_signal_source.dart';
export 'src/ports/warn_gate.dart';
export 'src/ports/warn_presentation.dart';
