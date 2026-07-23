/// Sync strategy for wall clock (Demo / Settings reuse).
enum TimeSyncMode {
  /// Operator (or API) owns the clock; no automatic network sync timers.
  manual,

  /// Prefer network-sourced time when stale or Sync Now is requested.
  network,
}

/// Outcome of [DateTimeController.syncFromNetwork] / [ensureSaneForTls].
class TimeSyncResult {
  const TimeSyncResult({
    required this.ok,
    this.message = '',
    this.rtcWritten = false,
  });

  final bool ok;
  final String message;
  final bool rtcWritten;

  @override
  String toString() =>
      'TimeSyncResult(ok=$ok, rtcWritten=$rtcWritten, message=$message)';
}

/// Preference paths and pure helpers for Linux datetime prefs.
class TimeSyncPrefs {
  /// Mouse-style `key=value` file (`sync_mode`, `timezone`).
  static const datetimeConf = '/var/lib/hal/datetime.conf';
  static const keySyncMode = 'sync_mode';
  static const keyTimezone = 'timezone';

  /// Pre-`datetime.conf` standalone files (one-shot import only).
  /// Prefer HAL tree; keep HMI paths for devices not yet migrated.
  static const legacySyncModePath = '/var/lib/hmi/time-sync-mode';
  static const legacyTimezonePath = '/var/lib/hmi/timezone';
  static const legacySyncModePathHal = '/var/lib/hal/time-sync-mode';
  static const legacyTimezonePathHal = '/var/lib/hal/timezone';

  static const helperPath = ''; // optional board override only

  /// Curated Demo / Settings list (extend later).
  static const curatedTimezones = <String>[
    'UTC',
    'Asia/Shanghai',
    'America/Los_Angeles',
  ];

  /// Default when preference file is missing: network (heal TLS on first boot).
  static TimeSyncMode modeFromToken(String? raw) {
    final token = (raw ?? '').trim().toLowerCase();
    if (token == 'manual') {
      return TimeSyncMode.manual;
    }
    return TimeSyncMode.network;
  }

  static String modeToToken(TimeSyncMode mode) {
    switch (mode) {
      case TimeSyncMode.manual:
        return 'manual';
      case TimeSyncMode.network:
        return 'network';
    }
  }

  /// Same window as `/usr/bin/sync-time` / `time-sync.sh` (2025–2030).
  static bool isSaneUtcYear(int year) => year >= 2025 && year <= 2030;

  static String normalizeTimezone(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) {
      return 'UTC';
    }
    return t;
  }
}

/// Reusable date/time API (manual set + network sync + RTC write).
abstract class DateTimeController {
  Future<DateTime> now();

  Future<String> getTimezone();

  Future<void> setTimezone(String id);

  Future<TimeSyncMode> getSyncMode();

  Future<void> setSyncMode(TimeSyncMode mode);

  /// Set local civil wall clock; persists mode as [TimeSyncMode.manual].
  Future<void> setWallClock(DateTime local);

  Future<TimeSyncResult> syncFromNetwork({bool onlyIfStale = false});

  /// TLS survival: sync when UTC year &lt; 2025 even if mode is manual;
  /// does not change persisted mode.
  Future<TimeSyncResult> ensureSaneForTls();

  Future<void> dispose();
}


/// HAL name for [DateTimeController].
typedef TimeService = DateTimeController;
