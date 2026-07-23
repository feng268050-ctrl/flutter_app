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
    this.helperPath = '',
    DateTimeProcessRunner? runProcess,
  }) : _run = runProcess ?? ((exe, args) => Process.run(exe, args));

  final String preferencePath;
  final String legacySyncModePath;
  final String legacyTimezonePath;
  final String helperPath;
  final DateTimeProcessRunner _run;

  bool _legacyImportAttempted = false;

  @override
  Future<DateTime> now() async => DateTime.now();

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
    lwsTrace('datetime: sync mode → $token');
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
      try {
        final f = File(legacySyncModePath);
        if (await f.exists()) {
          final raw = (await f.readAsString()).trim();
          if (raw.isNotEmpty) {
            updates[TimeSyncPrefs.keySyncMode] =
                TimeSyncPrefs.modeToToken(TimeSyncPrefs.modeFromToken(raw));
          }
        }
      } catch (_) {}
    }
    if (!hasTz) {
      try {
        final f = File(legacyTimezonePath);
        if (await f.exists()) {
          final raw = (await f.readAsString()).trim();
          if (raw.isNotEmpty) {
            updates[TimeSyncPrefs.keyTimezone] =
                TimeSyncPrefs.normalizeTimezone(raw);
          }
        }
      } catch (_) {}
    }
    if (updates.isEmpty) {
      return;
    }
    await upsertKeyValueConfFile(preferencePath, updates);
    lwsTrace('datetime: migrated legacy prefs → $preferencePath');
  }

  Future<TimeSyncResult> _runNetworkLadder({required String reason}) async {
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
      final m = RegExp(r'^\s*Date:\s*(.+)$', multiLine: true, caseSensitive: false).firstMatch(blob);
      if (m == null) {
        continue;
      }
      final hdr = m.group(1)!.trim();
      final set = await _run('date', [
        '-u',
        '-D',
        '%a, %d %b %Y %H:%M:%S GMT',
        '-s',
        hdr,
      ]);
      if (set.exitCode == 0 &&
          TimeSyncPrefs.isSaneUtcYear(DateTime.now().toUtc().year)) {
        final rtc = await _writeRtc();
        return TimeSyncResult(
          ok: true,
          message: '$reason HTTP Date $url',
          rtcWritten: rtc,
        );
      }
    }

    return TimeSyncResult(
      ok: false,
      message:
          '$reason failed; clock=${DateTime.now().toUtc().toIso8601String()} UTC',
    );
  }

  Future<bool> _writeRtc() async {
    try {
      final r = await _run('hwclock', ['-w', '-u']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  static String _pad4(int n) => n.toString().padLeft(4, '0');

  @override
  Future<void> dispose() async {}
}
