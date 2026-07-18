/// Wall clock / timezone (timedatectl helpers).
///
/// [TimeSyncMode] uses `manual` / `network` (not NTP enum).
/// Concrete Linux type: [LinuxDateTimeController].
library;

export 'package:cyber_hal/src/time/time_service.dart';
export 'package:cyber_hal/src/time/linux_date_time_controller.dart';
