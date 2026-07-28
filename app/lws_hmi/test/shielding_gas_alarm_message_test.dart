import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/features/warn_alarm/l10n/shielding_gas_alarm_message.dart';
import 'package:lws_hmi/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('A001 dialog falls back to generic when no cause bits', () {
    final monitor = AlarmMonitorState();
    expect(
      ShieldingGasAlarmMessage.buildDialogContent(l10n, monitor),
      l10n.shieldingGasAlarmContent,
    );
  });

  test('A001 dialog lists active causes then guidance', () {
    final monitor = AlarmMonitorState()
      ..gasBlowPressureAlarm = true
      ..gasInletPressureAlarm = true;
    final body = ShieldingGasAlarmMessage.buildDialogContent(l10n, monitor);
    expect(body, contains(l10n.shieldingGasAlarmReasonHeader));
    expect(body, contains(l10n.shieldingGasAlarmCauseBlowPressure));
    expect(body, contains(l10n.shieldingGasAlarmCauseInletPressure));
    expect(body, contains(l10n.shieldingGasAlarmContent));
  });
}
