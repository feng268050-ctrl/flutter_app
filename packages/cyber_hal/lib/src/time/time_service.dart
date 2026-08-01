/// Sync strategy for wall clock (Demo / Settings reuse).
enum TimeSyncMode {
  /// Operator (or API) owns the clock; no automatic network sync timers.
  manual,

  /// Prefer network-sourced time (product default; Settings Automatic on).
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
  /// Mouse-style `key=value` file (`sync_mode`, `timezone`, `ntp_server`, …).
  static const datetimeConf = '/var/lib/hal/datetime.conf';
  static const keySyncMode = 'sync_mode';
  static const keyTimezone = 'timezone';
  static const keyNtpServer = 'ntp_server';
  static const keyAutoTimezone = 'auto_timezone';
  static const keyUse24Hour = 'use_24h';

  /// Runtime timesyncd drop-in (overrides image `10-appliance.conf`).
  static const timesyncdDropInPath =
      '/etc/systemd/timesyncd.conf.d/20-hmi-ntp.conf';

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

  /// Default when preference file is missing: network (Settings Automatic on).
  /// Offline wall clock still relies on external RTC; Manual is an explicit opt-out.
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

  /// Default / unknown → off.
  static bool autoTimezoneFromToken(String? raw) {
    final token = (raw ?? '').trim().toLowerCase();
    return token == '1' || token == 'true' || token == 'yes' || token == 'on';
  }

  static String autoTimezoneToToken(bool enabled) => enabled ? '1' : '0';

  /// Default / unknown → on (24-hour display).
  static bool use24HourFromToken(String? raw) {
    final token = (raw ?? '').trim().toLowerCase();
    if (token.isEmpty) {
      return true;
    }
    return token != '0' &&
        token != 'false' &&
        token != 'no' &&
        token != 'off';
  }

  static String use24HourToToken(bool enabled) => enabled ? '1' : '0';
}

/// Curated NTP hostname for Settings Automatic (timesyncd `NTP=`).
class NtpServerPreset {
  const NtpServerPreset({
    required this.id,
    required this.labelKey,
  });

  /// Hostname written to timesyncd (also the preference value).
  final String id;

  /// Stable key for App l10n (e.g. `ntpPool`, `cloudflare`).
  final String labelKey;
}

/// Preset catalog + timesyncd drop-in rendering (host-testable).
abstract final class NtpServerCatalog {
  static const defaultId = 'pool.ntp.org';

  static const presets = <NtpServerPreset>[
    NtpServerPreset(id: 'pool.ntp.org', labelKey: 'ntpPool'),
    NtpServerPreset(id: 'time.cloudflare.com', labelKey: 'cloudflare'),
    NtpServerPreset(id: 'time.google.com', labelKey: 'google'),
    NtpServerPreset(id: 'ntp.aliyun.com', labelKey: 'aliyun'),
    NtpServerPreset(id: 'time.windows.com', labelKey: 'windows'),
    NtpServerPreset(id: 'time.apple.com', labelKey: 'apple'),
    NtpServerPreset(id: 'ntp.tencent.com', labelKey: 'tencent'),
    NtpServerPreset(id: 'cn.pool.ntp.org', labelKey: 'cnPool'),
  ];

  static NtpServerPreset? byId(String? raw) {
    final id = (raw ?? '').trim();
    if (id.isEmpty) {
      return null;
    }
    for (final p in presets) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }

  /// Unknown / empty → [defaultId].
  static String normalizeId(String? raw) {
    return byId(raw)?.id ?? defaultId;
  }

  /// `NTP=<primary>` + `FallbackNTP=<others>` drop-in body.
  static String renderTimesyncdDropIn(String primaryId) {
    final primary = normalizeId(primaryId);
    final fallbacks = <String>[
      for (final p in presets)
        if (p.id != primary) p.id,
    ];
    final buf = StringBuffer()
      ..writeln('# Generated by cyber_hal DateTimeController — do not edit')
      ..writeln('[Time]')
      ..writeln('NTP=$primary');
    if (fallbacks.isNotEmpty) {
      buf.writeln('FallbackNTP=${fallbacks.join(' ')}');
    }
    return buf.toString();
  }
}

/// Parse timezone id from IP-geo HTTP bodies (JSON `timezone` / plain text).
abstract final class TimezoneGeoParse {
  /// JSON body with a `"timezone":"Area/City"` field (ip-api, WorldTimeAPI, …).
  static String? fromJsonTimezoneField(String body) {
    final m = RegExp(
      r'"timezone"\s*:\s*"([^"]+)"',
    ).firstMatch(body);
    if (m == null) {
      return null;
    }
    final tz = m.group(1)!.trim();
    if (tz.isEmpty || !tz.contains('/')) {
      return null;
    }
    return tz;
  }

  /// Plain-text IANA zone body (ip-api `/line/`, ipapi.co `/timezone/`).
  static String? fromPlainTimezone(String body) {
    final tz = body.trim().split(RegExp(r'\s+')).first;
    if (tz.isEmpty || !tz.contains('/')) {
      return null;
    }
    if (tz.toLowerCase().startsWith('<!')) {
      return null;
    }
    return tz;
  }

  /// Legacy alias for [fromJsonTimezoneField].
  static String? fromWorldTimeApiJson(String body) =>
      fromJsonTimezoneField(body);

  /// Legacy alias for [fromPlainTimezone].
  static String? fromIpapiPlain(String body) => fromPlainTimezone(body);
}

/// Host-testable wall-clock display helpers (Settings / status clocks).
abstract final class TimeDisplayFormat {
  /// `HH:mm` or `h:mm AM/PM` (ASCII meridiem; UI may prefer [TimeOfDay.format]).
  static String formatHm(DateTime t, {required bool use24Hour}) {
    final minute = t.minute.toString().padLeft(2, '0');
    if (use24Hour) {
      return '${t.hour.toString().padLeft(2, '0')}:$minute';
    }
    final h24 = t.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final meridiem = h24 < 12 ? 'AM' : 'PM';
    return '$h12:$minute $meridiem';
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

  /// Curated NTP hosts for Settings Automatic.
  List<NtpServerPreset> listNtpServerPresets();

  /// Persisted primary NTP hostname ([NtpServerCatalog.defaultId] when unset).
  Future<String> getNtpServerId();

  /// Persist primary NTP and apply timesyncd drop-in.
  Future<void> setNtpServerId(String id);

  /// When true, HAL may set timezone from IP geolocation.
  Future<bool> getAutoTimezone();

  /// Persist auto-timezone; when enabling, attempts [syncTimezoneFromNetwork].
  /// Returns the geo sync result when [enabled] is true; success stub when false.
  Future<TimeSyncResult> setAutoTimezone(bool enabled);

  /// IP geolocation → IANA zone → [setTimezone] (best-effort).
  Future<TimeSyncResult> syncTimezoneFromNetwork();

  /// Prefer 24-hour clock display (default true when unset).
  Future<bool> getUse24HourFormat();

  /// Persist 24-hour display preference (does not change OS locale).
  Future<void> setUse24HourFormat(bool enabled);

  /// All usable IANA zones on this host with current UTC offset labels.
  Future<List<TimezoneEntry>> listTimezoneEntries();

  Future<void> dispose();
}


/// HAL name for [DateTimeController].
typedef TimeService = DateTimeController;
