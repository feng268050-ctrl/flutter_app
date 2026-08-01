/// Wall clock / timezone (timedatectl helpers).
///
/// [TimeSyncMode] uses `manual` / `network` (not NTP enum).
/// Linux prefs: `/var/lib/hal/datetime.conf`
/// (`sync_mode`, `timezone`, `ntp_server`, `auto_timezone`).
/// Concrete Linux type: [LinuxDateTimeController].
library;

export 'package:cyber_hal/src/time/time_service.dart';
export 'package:cyber_hal/src/time/linux_date_time_controller.dart';
export 'package:cyber_hal/src/time/network_time_sync_watcher.dart';
