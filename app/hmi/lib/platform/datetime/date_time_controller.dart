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
  static const syncModePath = '/var/lib/lws-hmi/time-sync-mode';
  static const timezonePath = '/var/lib/lws-hmi/timezone';
  static const helperPath = '/usr/lib/lws-hmi/wlan0-time-sync.sh';

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

  /// Same window as `wlan0-time-sync.sh` (2025–2030).
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
