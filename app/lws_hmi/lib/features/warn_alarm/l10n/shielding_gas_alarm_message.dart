import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// A001 dialog / log copy (lws-ui `ShieldingGasAlarmMessageUtil`).
abstract final class ShieldingGasAlarmMessage {
  /// Consumer-facing dialog body: optional reason list + generic guidance.
  static String buildDialogContent(
    AppLocalizations l10n,
    AlarmMonitorState monitor,
  ) {
    final causes = collectCauseLabels(l10n, monitor);
    if (causes.isEmpty) {
      return l10n.shieldingGasAlarmContent;
    }
    final buf = StringBuffer(l10n.shieldingGasAlarmReasonHeader);
    for (final cause in causes) {
      buf
        ..writeln()
        ..write(l10n.shieldingGasAlarmReasonBullet(cause));
    }
    buf
      ..writeln()
      ..writeln()
      ..write(l10n.shieldingGasAlarmContent);
    return buf.toString();
  }

  static List<String> collectCauseLabels(
    AppLocalizations l10n,
    AlarmMonitorState monitor,
  ) {
    final labels = <String>[];
    if (monitor.gasBlowPressureAlarm) {
      labels.add(l10n.shieldingGasAlarmCauseBlowPressure);
    }
    if (monitor.gasInletPressureAlarm) {
      labels.add(l10n.shieldingGasAlarmCauseInletPressure);
    }
    if (monitor.gasPressureSensorCommAlarm) {
      labels.add(l10n.shieldingGasAlarmCausePressureCheck);
    }
    if (monitor.gasControlCardExtFlashAlarm) {
      labels.add(l10n.shieldingGasAlarmCauseDeviceService);
    }
    return labels;
  }
}
