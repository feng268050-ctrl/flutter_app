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

  /// Curated Demo short list (Settings uses [DateTimeController.listTimezoneEntries]).
  static const curatedTimezones = <String>[
    'UTC',
    'Asia/Shanghai',
    'America/Los_Angeles',
  ];

  /// Default when preference file is missing: manual (hardware RTC / operator).
  /// Network NTP is opt-in via Settings Automatic — many appliances never go online.
  static TimeSyncMode modeFromToken(String? raw) {
    final token = (raw ?? '').trim().toLowerCase();
    if (token == 'network') {
      return TimeSyncMode.network;
    }
    return TimeSyncMode.manual;
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

/// Timezone id + current UTC offset label for Settings search / display.
class TimezoneEntry {
  const TimezoneEntry({
    required this.id,
    this.utcOffsetLabel = '',
  });

  final String id;

  /// e.g. `UTC+08:00` (empty when unknown).
  final String utcOffsetLabel;
}

/// Pure helpers for timezone search / offset formatting (host-testable).
class TimezoneCatalog {
  /// `+0800` / `-0530` → `UTC+08:00` / `UTC-05:30`.
  static String formatPosixOffset(String raw) {
    final s = raw.trim();
    final m = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(s);
    if (m == null) {
      return '';
    }
    return 'UTC${m.group(1)}${m.group(2)}:${m.group(3)}';
  }

  /// Match zone id text and/or UTC offset (`8`, `+08`, `utc+8`, `UTC+08:00`, …).
  static bool matchesQuery(TimezoneEntry entry, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }
    final id = entry.id.toLowerCase();
    if (id.contains(q) || id == q || id.endsWith('/$q')) {
      return true;
    }
    final city = id.split('/').last;
    if (city.contains(q)) {
      return true;
    }

    final label = entry.utcOffsetLabel.toLowerCase();
    if (label.isEmpty) {
      return false;
    }
    if (label.contains(q)) {
      return true;
    }
    final compactLabel = label.replaceAll(':', '');
    final compactQ = q.replaceAll(':', '');
    if (compactLabel.contains(compactQ)) {
      return true;
    }

    final offsetTok = _normalizeOffsetQuery(q);
    if (offsetTok == null) {
      return false;
    }
    if (label.contains(offsetTok)) {
      return true;
    }
    return compactLabel.contains(offsetTok.replaceAll(':', ''));
  }

  /// Filter with exact / suffix matches first (lws-ui timezone picker parity).
  static List<TimezoneEntry> filter(
    Iterable<TimezoneEntry> all,
    String rawQuery,
  ) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) {
      return List<TimezoneEntry>.of(all);
    }
    final exact = <TimezoneEntry>[];
    final fuzzy = <TimezoneEntry>[];
    for (final e in all) {
      if (!matchesQuery(e, q)) {
        continue;
      }
      final id = e.id.toLowerCase();
      if (id == q || id.endsWith('/$q')) {
        exact.add(e);
      } else {
        fuzzy.add(e);
      }
    }
    return [...exact, ...fuzzy];
  }

  /// `8` / `+8` / `utc+08:00` / `-5:30` → `+08` / `+08:00` / `-05:30` token.
  static String? _normalizeOffsetQuery(String q) {
    var s = q;
    if (s.startsWith('utc')) {
      s = s.substring(3).trim();
    } else if (s.startsWith('gmt')) {
      s = s.substring(3).trim();
    }
    final m = RegExp(r'^([+-])?(\d{1,2})(?::?(\d{2}))?$').firstMatch(s);
    if (m == null) {
      return null;
    }
    final sign = m.group(1) ?? '+';
    final hour = int.tryParse(m.group(2)!);
    if (hour == null || hour > 14) {
      return null;
    }
    final hh = hour.toString().padLeft(2, '0');
    final minRaw = m.group(3);
    if (minRaw == null) {
      return '$sign$hh';
    }
    final minute = int.tryParse(minRaw);
    if (minute == null || minute > 59) {
      return null;
    }
    return '$sign$hh:${minute.toString().padLeft(2, '0')}';
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

  /// All usable IANA zones on this host with current UTC offset labels.
  Future<List<TimezoneEntry>> listTimezoneEntries();

  Future<void> dispose();
}


/// HAL name for [DateTimeController].
typedef TimeService = DateTimeController;
