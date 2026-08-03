import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_gate.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_gate.dart';

/// Suppresses warn modals until Safety Tips + Boot Self-Check finish
/// (lws-ui: no warn dialogs on SafetyTips; gate during self-check).
final class BootSelfCheckWarnGate implements WarnGate {
  const BootSelfCheckWarnGate();

  @override
  bool get isPresentationSuppressed =>
      SafetyTipsGate.isActive || !BootSelfCheckGate.isCompletedInProcess;
}
