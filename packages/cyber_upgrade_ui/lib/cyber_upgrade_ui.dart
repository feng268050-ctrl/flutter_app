/// Shared upgrade UX — check card/dialog, multi-phase progress, completion tips.
///
/// Flutter + [cyber_ui] only. Apps adapt `cyber_ota` / Modbus / camera flash.
library;

export 'src/check/upgrade_checker.dart';
export 'src/domain/upgrade_channel.dart';
export 'src/domain/upgrade_check_result.dart';
export 'src/domain/upgrade_completion_config.dart';
export 'src/domain/upgrade_offer.dart';
export 'src/domain/upgrade_phase.dart';
export 'src/domain/upgrade_policy.dart';
export 'src/domain/upgrade_progress.dart';
export 'src/widgets/upgrade_check_card.dart';
export 'src/widgets/upgrade_check_dialog.dart';
export 'src/widgets/upgrade_completion_tip.dart';
export 'src/widgets/upgrade_phase_progress_view.dart';
export 'src/widgets/upgrade_post_apply_listener.dart';
