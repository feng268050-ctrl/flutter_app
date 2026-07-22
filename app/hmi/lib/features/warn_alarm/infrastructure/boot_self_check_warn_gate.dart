import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_gate.dart';

/// Suppresses warn modals while [BootSelfCheckGate.isActive].
final class BootSelfCheckWarnGate implements WarnGate {
  const BootSelfCheckWarnGate();

  @override
  bool get isPresentationSuppressed => BootSelfCheckGate.isActive;
}
