import 'package:cyber_alarm/src/domain/alarm_signal_event.dart';

/// Inbound alarm activity (Modbus adapter, camera, …).
abstract interface class AlarmSignalSource {
  Stream<AlarmSignalEvent> get events;
}
