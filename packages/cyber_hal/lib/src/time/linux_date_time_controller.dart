import 'dart:io';

import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/time/time_service.dart';

typedef DateTimeProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Linux: BusyBox/`timedatectl` + `hwclock` + `/usr/bin/sync-time` ladder.
class LinuxDateTimeController implements DateTimeController {
  LinuxDateTimeController({
    this.preferencePath = TimeSyncPrefs.datetimeConf,
    this.legacySyncModePath = TimeSyncPrefs.legacySyncModePath,
    this.legacyTimezonePath = TimeSyncPrefs.legacyTimezonePath,
    this.timesyncdDropInPath = TimeSyncPrefs.timesyncdDropInPath,
    this.helperPath = '',
    DateTimeProcessRunner? runProcess,
  }) : _run = runProcess ?? ((exe, args) => Process.run(exe, args));

  final String preferencePath;
  final String legacySyncModePath;
  final String legacyTimezonePath;
  final String timesyncdDropInPath;
  final String helperPath;
  final DateTimeProcessRunner _run;

  bool _legacyImportAttempted = false;

  @override
  Future<DateTime> now() async {
    // Prefer OS civil time via `date` so Settings matches timedatectl even when
    // the Dart/ICU default zone is still UTC (common on eLinux until TZ is set).
    try {
      final r = await _run('date', ['+%Y-%m-%dT%H:%M:%S']);
      if (r.exitCode == 0) {
        final raw = (r.stdout as String?)?.trim() ?? '';
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) {
          return parsed;
        }
      }
    } catch (_) {}
    return DateTime.now();
  }

  @override
  Future<TimeSyncMode> getSyncMode() async {
    final map = await _prefsMap();
    return TimeSyncPrefs.modeFromToken(map[TimeSyncPrefs.keySyncMode]);
  }

  @override
  Future<void> setSyncMode(TimeSyncMode mode) async {
    await _ensureLegacyImported();
    final token = TimeSyncPrefs.modeToToken(mode);
    await upsertKeyValueConfFile(preferencePath, {
      TimeSyncPrefs.keySyncMode: token,
    });
    await _applyOsNtp(mode == TimeSyncMode.network);
    lwsTrace('datetime: sync mode → $token');
  }

  /// Apply persisted sync mode to OS NTP (`timedatectl set-ntp`).
  ///
  /// Call on HMI bring-up so upgrades with timesyncd do not leave NTP stuck off
  /// when prefs say `network`.
  Future<void> applyPersistedSyncMode() async {
    final mode = await getSyncMode();
    await _applyOsNtp(mode == TimeSyncMode.network);
  }

  /// Write timesyncd drop-in from persisted [getNtpServerId] and restart unit.
  Future<void> applyPersistedNtpServer() async {
    final id = await getNtpServerId();
    await _writeTimesyncdDropIn(id);
  }

  /// Best-effort `timedatectl set-ntp`; no-op when timedatectl/timesyncd absent.
  Future<void> _applyOsNtp(bool enable) async {
    final flag = enable ? 'true' : 'false';
    try {
      final r = await _run('timedatectl', ['set-ntp', flag]);
      if (r.exitCode == 0) {
        lwsTrace('datetime: set-ntp → $flag');
      } else {
        final err = ((r.stderr as String?) ?? (r.stdout as String?) ?? '').trim();
        lwsTrace('datetime: set-ntp $flag failed: $err');
      }
    } catch (e) {
      lwsTrace('datetime: set-ntp unavailable: $e');
    }
  }

  @override
  List<NtpServerPreset> listNtpServerPresets() =>
      List<NtpServerPreset>.unmodifiable(NtpServerCatalog.presets);

  @override
  Future<String> getNtpServerId() async {
    final map = await _prefsMap();
    return NtpServerCatalog.normalizeId(map[TimeSyncPrefs.keyNtpServer]);
  }

  @override
  Future<void> setNtpServerId(String id) async {
    final normalized = NtpServerCatalog.normalizeId(id);
    await _ensureLegacyImported();
    await upsertKeyValueConfFile(preferencePath, {
      TimeSyncPrefs.keyNtpServer: normalized,
    });
    await _writeTimesyncdDropIn(normalized);
    lwsTrace('datetime: ntp_server → $normalized');
  }

  Future<void> _writeTimesyncdDropIn(String primaryId) async {
    final body = NtpServerCatalog.renderTimesyncdDropIn(primaryId);
    try {
      final f = File(timesyncdDropInPath);
      await f.parent.create(recursive: true);
      await f.writeAsString(body, flush: true);
    } catch (e) {
      lwsTrace('datetime: timesyncd drop-in write failed: $e');
      return;
    }
    try {
      final r = await _run('systemctl', ['restart', 'systemd-timesyncd.service']);
      if (r.exitCode != 0) {
        final err = ((r.stderr as String?) ?? (r.stdout as String?) ?? '').trim();
        lwsTrace('datetime: timesyncd restart failed: $err');
      }
    } catch (e) {
      lwsTrace('datetime: timesyncd restart unavailable: $e');
    }
  }

  @override
  Future<bool> getAutoTimezone() async {
    final map = await _prefsMap();
    return TimeSyncPrefs.autoTimezoneFromToken(
      map[TimeSyncPrefs.keyAutoTimezone],
    );
  }

  @override
  Future<TimeSyncResult> setAutoTimezone(bool enabled) async {
    await _ensureLegacyImported();
    await upsertKeyValueConfFile(preferencePath, {
      TimeSyncPrefs.keyAutoTimezone: TimeSyncPrefs.autoTimezoneToToken(enabled),
    });
    lwsTrace('datetime: auto_timezone → $enabled');
    if (enabled) {
      return syncTimezoneFromNetwork();
    }
    return const TimeSyncResult(ok: true, message: 'auto_timezone off');
  }

  @override
  Future<TimeSyncResult> syncTimezoneFromNetwork() async {
    // Prefer HTTP (works when TLS clock is still wrong). WorldTimeAPI is sunset.
    Future<TimeSyncResult?> tryWget({
      required String url,
      required String? Function(String body) parse,
      required String label,
    }) async {
      try {
        final r = await _run('wget', [
          '-q',
          '-O',
          '-',
          '-T',
          '10',
          url,
        ]);
        if (r.exitCode != 0) {
          final err =
              ((r.stderr as String?) ?? (r.stdout as String?) ?? '').trim();
          lwsTrace('datetime: $label wget exit ${r.exitCode}: $err');
          return null;
        }
        final tz = parse((r.stdout as String?) ?? '');
        if (tz == null) {
          lwsTrace('datetime: $label parse failed');
          return null;
        }
        await setTimezone(tz);
        return TimeSyncResult(ok: true, message: 'timezone via $label → $tz');
      } catch (e) {
        lwsTrace('datetime: $label failed: $e');
        return null;
      }
    }

    final ipApiJson = await tryWget(
      url: 'http://ip-api.com/json/?fields=status,message,timezone',
      parse: TimezoneGeoParse.fromJsonTimezoneField,
      label: 'ip-api json',
    );
    if (ipApiJson != null) {
      return ipApiJson;
    }

    final ipApiLine = await tryWget(
      url: 'http://ip-api.com/line/?fields=timezone',
      parse: TimezoneGeoParse.fromPlainTimezone,
      label: 'ip-api line',
    );
    if (ipApiLine != null) {
      return ipApiLine;
    }

    // HTTPS last — may fail if wall clock is still pre-TLS-sane.
    final ipapi = await tryWget(
      url: 'https://ipapi.co/timezone/',
      parse: TimezoneGeoParse.fromPlainTimezone,
      label: 'ipapi.co',
    );
    if (ipapi != null) {
      return ipapi;
    }

    return const TimeSyncResult(
      ok: false,
      message: 'timezone geo lookup failed',
    );
  }

  @override
  Future<bool> getUse24HourFormat() async {
    final map = await _prefsMap();
    return TimeSyncPrefs.use24HourFromToken(map[TimeSyncPrefs.keyUse24Hour]);
  }

  @override
  Future<void> setUse24HourFormat(bool enabled) async {
    await _ensureLegacyImported();
    await upsertKeyValueConfFile(preferencePath, {
      TimeSyncPrefs.keyUse24Hour: TimeSyncPrefs.use24HourToToken(enabled),
    });
    lwsTrace('datetime: use_24h → $enabled');
  }

  @override
  Future<String> getTimezone() async {
    final map = await _prefsMap();
    final fromConf = map[TimeSyncPrefs.keyTimezone]?.trim() ?? '';
    if (fromConf.isNotEmpty) {
      return TimeSyncPrefs.normalizeTimezone(fromConf);
    }
    // Fall back to timedatectl if present.
    try {
      final r = await _run('timedatectl', ['show', '-p', 'Timezone', '--value']);
      if (r.exitCode == 0) {
        final v = (r.stdout as String?)?.trim() ?? '';
        if (v.isNotEmpty) {
          return v;
        }
      }
    } catch (_) {}
    return 'UTC';
  }

  @override
  Future<void> setTimezone(String id) async {
    final zone = TimeSyncPrefs.normalizeTimezone(id);
    await _ensureLegacyImported();
    await upsertKeyValueConfFile(preferencePath, {
      TimeSyncPrefs.keyTimezone: zone,
    });

    final td = await _run('timedatectl', ['set-timezone', zone]);
    if (td.exitCode == 0) {
      lwsTrace('datetime: timezone timedatectl → $zone');
      return;
    }

    final zoneFile = '/usr/share/zoneinfo/$zone';
    if (await File(zoneFile).exists()) {
      try {
        final localtime = File('/etc/localtime');
        if (await localtime.exists() || await Link('/etc/localtime').exists()) {
          await localtime.delete();
        }
        await Link('/etc/localtime').create(zoneFile);
        lwsTrace('datetime: timezone symlink → $zone');
        return;
      } catch (e) {
        lwsTrace('datetime: timezone symlink failed: $e');
      }
    }

    // Preference file is enough for Demo; TZ may only affect future shells.
    lwsTrace('datetime: timezone preferred $zone (zoneinfo/timedatectl unavailable)');
  }

  @override
  Future<void> setWallClock(DateTime local) async {
    // Prefer ISO-ish local "YYYY-MM-DD HH:MM:SS" for timedatectl / BusyBox date.
    final stamp =
        '${_pad4(local.year)}-${_pad2(local.month)}-${_pad2(local.day)} '
        '${_pad2(local.hour)}:${_pad2(local.minute)}:${_pad2(local.second)}';

    // timedatectl refuses set-time while NTP is on; drop NTP before writing.
    await _applyOsNtp(false);

    var ok = false;
    final td = await _run('timedatectl', ['set-time', stamp]);
    if (td.exitCode == 0) {
      ok = true;
    } else {
      final d = await _run('date', ['-s', stamp]);
      ok = d.exitCode == 0;
      if (!ok) {
        final err = ((d.stderr as String?) ?? (d.stdout as String?) ?? '').trim();
        throw StateError('date -s failed: $err');
      }
    }

    await setSyncMode(TimeSyncMode.manual);
    final rtc = await _writeRtc();
    lwsTrace(
      'datetime: manual set $stamp (rtcWritten=$rtc) → mode=manual',
    );
    if (!ok) {
      throw StateError('setWallClock failed');
    }
  }

  @override
  Future<TimeSyncResult> syncFromNetwork({bool onlyIfStale = false}) async {
    final year = DateTime.now().toUtc().year;
    if (onlyIfStale && TimeSyncPrefs.isSaneUtcYear(year)) {
      return const TimeSyncResult(
        ok: true,
        message: 'clock already sane',
      );
    }
    return _runNetworkLadder(reason: 'syncFromNetwork');
  }

  @override
  Future<TimeSyncResult> ensureSaneForTls() async {
    final year = DateTime.now().toUtc().year;
    if (year >= 2025) {
      return const TimeSyncResult(ok: true, message: 'clock ok for TLS');
    }
    lwsTrace(
      'datetime: TLS emergency sync (year=$year, mode=${await getSyncMode()})',
    );
    // Do not change persisted mode.
    return _runNetworkLadder(reason: 'ensureSaneForTls');
  }

  /// Re-apply timezone from prefs to the OS (timedatectl /localtime).
  ///
  /// Needed so [DateTime.now] matches the Settings timezone label — prefs alone
  /// do not change libc localtime.
  Future<void> applyPersistedTimezone() async {
    final tz = await getTimezone();
    await setTimezone(tz);
  }

  Future<Map<String, String>> _prefsMap() async {
    await _ensureLegacyImported();
    return readKeyValueConfFile(preferencePath);
  }

  /// One-shot: fill missing conf keys from legacy standalone files.
  Future<void> _ensureLegacyImported() async {
    if (_legacyImportAttempted) {
      return;
    }
    _legacyImportAttempted = true;

    final map = await readKeyValueConfFile(preferencePath);
    final hasSync = (map[TimeSyncPrefs.keySyncMode] ?? '').trim().isNotEmpty;
    final hasTz = (map[TimeSyncPrefs.keyTimezone] ?? '').trim().isNotEmpty;
    if (hasSync && hasTz) {
      return;
    }

    final updates = <String, String>{};
    if (!hasSync) {
      final raw = await _readFirstExisting(<String>[
        TimeSyncPrefs.legacySyncModePathHal,
        legacySyncModePath,
      ]);
      if (raw != null && raw.isNotEmpty) {
        updates[TimeSyncPrefs.keySyncMode] =
            TimeSyncPrefs.modeToToken(TimeSyncPrefs.modeFromToken(raw));
      }
    }
    if (!hasTz) {
      final raw = await _readFirstExisting(<String>[
        TimeSyncPrefs.legacyTimezonePathHal,
        legacyTimezonePath,
      ]);
      if (raw != null && raw.isNotEmpty) {
        updates[TimeSyncPrefs.keyTimezone] =
            TimeSyncPrefs.normalizeTimezone(raw);
      }
    }
    if (updates.isEmpty) {
      return;
    }
    await upsertKeyValueConfFile(preferencePath, updates);
    lwsTrace('datetime: migrated legacy prefs → $preferencePath');
  }

  Future<String?> _readFirstExisting(List<String> paths) async {
    for (final path in paths) {
      try {
        final f = File(path);
        if (!await f.exists()) {
          continue;
        }
        final raw = (await f.readAsString()).trim();
        if (raw.isNotEmpty) {
          return raw;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<TimeSyncResult> _runNetworkLadder({required String reason}) async {
    // Pref timezone must be on the OS before we judge / display local time.
    // Otherwise UTC wall (e.g. 10:12) is shown while Settings still says Asia/Shanghai.
    try {
      await applyPersistedTimezone();
    } catch (e) {
      lwsTrace('datetime: apply timezone before sync: $e');
    }

    if (helperPath.isNotEmpty && await File(helperPath).exists()) {
      final r = await _run(helperPath, []);
      if (TimeSyncPrefs.isSaneUtcYear(DateTime.now().toUtc().year)) {
        final rtc = await _writeRtc();
        return TimeSyncResult(
          ok: true,
          message: '$reason via helper (exit ${r.exitCode})',
          rtcWritten: rtc,
        );
      }
    }

    for (final host in ['time.nist.gov', 'time.windows.com']) {
      final r = await _run('rdate', ['-s', host]);
      if (r.exitCode == 0 &&
          TimeSyncPrefs.isSaneUtcYear(DateTime.now().toUtc().year)) {
        final rtc = await _writeRtc();
        return TimeSyncResult(
          ok: true,
          message: '$reason rdate $host',
          rtcWritten: rtc,
        );
      }
    }

    for (final url in [
      'http://www.baidu.com/',
      'http://connectivitycheck.gstatic.com/generate_204',
    ]) {
      final r = await _run('wget', [
        '-S',
        '-O',
        '/dev/null',
        '-T',
        '8',
        url,
      ]);
      final blob = '${r.stderr}\n${r.stdout}';
      final m = RegExp(
        r'^\s*Date:\s*(.+)$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(blob);
      if (m == null) {
        continue;
      }
      final hdr = m.group(1)!.trim();
      DateTime utc;
      try {
        // HTTP Date is always GMT/UTC — never feed the raw header to BusyBox
        // `date -u -D … GMT -s` (some builds treat the stamp as local and end
        // up eight hours slow in Asia/Shanghai).
        utc = HttpDate.parse(hdr).toUtc();
      } catch (e) {
        lwsTrace('datetime: HTTP Date parse failed ($hdr): $e');
        continue;
      }
      if (await _setSystemUtc(utc)) {
        if (TimeSyncPrefs.isSaneUtcYear(DateTime.now().toUtc().year)) {
          final rtc = await _writeRtc();
          return TimeSyncResult(
            ok: true,
            message: '$reason HTTP Date $url',
            rtcWritten: rtc,
          );
        }
      }
    }

    return TimeSyncResult(
      ok: false,
      message:
          '$reason failed; clock=${DateTime.now().toUtc().toIso8601String()} UTC',
    );
  }

  /// Set the OS clock from a UTC instant (not local civil fields).
  Future<bool> _setSystemUtc(DateTime utc) async {
    final u = utc.toUtc();
    final stamp =
        '${_pad4(u.year)}-${_pad2(u.month)}-${_pad2(u.day)} '
        '${_pad2(u.hour)}:${_pad2(u.minute)}:${_pad2(u.second)}';

    final td = await _run('timedatectl', ['set-time', '$stamp UTC']);
    if (td.exitCode == 0) {
      lwsTrace('datetime: set UTC via timedatectl → $stamp');
      return true;
    }

    final d = await _run('date', ['-u', '-s', stamp]);
    if (d.exitCode == 0) {
      lwsTrace('datetime: set UTC via date -u -s → $stamp');
      return true;
    }
    final err = ((d.stderr as String?) ?? (d.stdout as String?) ?? '').trim();
    lwsTrace('datetime: set UTC failed: $err');
    return false;
  }

  Future<bool> _writeRtc() async {
    try {
      // BusyBox hwclock: -f DEV (not util-linux --rtc).
      final r = await _run('hwclock', ['-w', '-u', '-f', '/dev/rtc0']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<TimezoneEntry>> listTimezoneEntries() async {
    final ids = await _listTimezoneIds();
    final offsets = await _readUtcOffsetLabels(ids);
    return [
      for (final id in ids)
        TimezoneEntry(
          id: id,
          utcOffsetLabel: offsets[id] ?? '',
        ),
    ];
  }

  Future<List<String>> _listTimezoneIds() async {
    try {
      final r = await _run('timedatectl', ['list-timezones']);
      if (r.exitCode == 0) {
        final lines = (r.stdout as String)
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          return lines;
        }
      }
    } catch (_) {}

    final walked = await _walkZoneinfo('/usr/share/zoneinfo');
    if (walked.isNotEmpty) {
      return walked;
    }
    return List<String>.of(TimeSyncPrefs.curatedTimezones);
  }

  Future<List<String>> _walkZoneinfo(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      return const [];
    }
    const skipNames = {
      'iso3166.tab',
      'zone.tab',
      'zone1970.tab',
      'leapseconds',
      'tzdata.zi',
      'Factory',
      'localtime',
    };
    final out = <String>[];
    try {
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        var rel = entity.path;
        if (rel.startsWith(rootPath)) {
          rel = rel.substring(rootPath.length);
          if (rel.startsWith('/')) {
            rel = rel.substring(1);
          }
        }
        if (rel.isEmpty) {
          continue;
        }
        if (rel.startsWith('posix/') || rel.startsWith('right/')) {
          continue;
        }
        final base = rel.contains('/') ? rel.split('/').last : rel;
        if (skipNames.contains(base) || base.endsWith('.tab') || base.endsWith('.zi')) {
          continue;
        }
        out.add(rel);
      }
    } catch (e) {
      lwsTrace('datetime: zoneinfo walk failed: $e');
      return const [];
    }
    out.sort();
    return out;
  }

  /// Map zone id → `UTC±HH:MM` via `TZ=<id> date +%z` (chunked shell).
  Future<Map<String, String>> _readUtcOffsetLabels(List<String> zones) async {
    final out = <String, String>{};
    if (zones.isEmpty) {
      return out;
    }
    const chunkSize = 100;
    for (var i = 0; i < zones.length; i += chunkSize) {
      final end = (i + chunkSize < zones.length) ? i + chunkSize : zones.length;
      final slice = zones.sublist(i, end);
      final script = StringBuffer();
      for (final z in slice) {
        if (!_isSafeTimezoneId(z)) {
          continue;
        }
        script.writeln(
          'printf \'%s\\t%s\\n\' \'$z\' "\$(TZ=\'$z\' date +%z 2>/dev/null)"',
        );
      }
      if (script.isEmpty) {
        continue;
      }
      try {
        final r = await _run('sh', ['-c', script.toString()]);
        if (r.exitCode != 0 && (r.stdout as String).trim().isEmpty) {
          continue;
        }
        for (final line in (r.stdout as String).split('\n')) {
          final t = line.trim();
          if (t.isEmpty) {
            continue;
          }
          final tab = t.indexOf('\t');
          if (tab <= 0) {
            continue;
          }
          final id = t.substring(0, tab);
          final label = TimezoneCatalog.formatPosixOffset(t.substring(tab + 1));
          if (label.isNotEmpty) {
            out[id] = label;
          }
        }
      } catch (_) {}
    }
    return out;
  }

  static bool _isSafeTimezoneId(String id) {
    // IANA ids: letters, digits, _, +, -, /
    return RegExp(r'^[A-Za-z0-9_+\-/]+$').hasMatch(id);
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  static String _pad4(int n) => n.toString().padLeft(4, '0');

  @override
  Future<void> dispose() async {}
}
