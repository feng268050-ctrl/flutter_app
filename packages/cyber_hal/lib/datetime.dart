/// Wall clock / timezone (timedatectl helpers).
///
/// [TimeSyncMode] uses `manual` / `network` (not NTP enum).
/// Linux prefs: `/var/lib/hmi/datetime.conf` (`sync_mode`, `timezone`).
/// Concrete Linux type: [LinuxDateTimeController].
library;

export 'package:cyber_hal/src/time/time_service.dart';
export 'package:cyber_hal/src/time/linux_date_time_controller.dart';
