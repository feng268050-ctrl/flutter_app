import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// JSON-array history under `/var/lib/hmi/alarm-log.json` (newest first).
final class FileAlarmLogRepository implements AlarmLogRepository {
  FileAlarmLogRepository({
    String? path,
    this.maxEntries = 500,
  }) : path = path ?? '${OsPaths.varHmi}/alarm-log.json';

  final String path;
  final int maxEntries;

  final List<AlarmLogEntry> _cache = [];
  final _ctrl = StreamController<List<AlarmLogEntry>>.broadcast();
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final f = File(path);
      if (!await f.exists()) {
        return;
      }
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          _cache.add(AlarmLogEntry.fromJson(Map<String, Object?>.from(item)));
        } else if (item is Map) {
          _cache.add(
            AlarmLogEntry.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('alarm-log: load failed: $e');
      _cache.clear();
    }
  }

  Future<void> _persist() async {
    try {
      final f = File(path);
      await f.parent.create(recursive: true);
      final payload = _cache.map((e) => e.toJson()).toList(growable: false);
      await f.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    } catch (e) {
      debugPrint('alarm-log: persist failed: $e');
    }
  }

  void _emit() {
    if (!_ctrl.isClosed) {
      _ctrl.add(List<AlarmLogEntry>.unmodifiable(_cache));
    }
  }

  @override
  Future<void> insertRising(AlarmLogEntry entry) async {
    await _ensureLoaded();
    _cache.insert(0, entry);
    while (_cache.length > maxEntries) {
      _cache.removeLast();
    }
    await _persist();
    _emit();
  }

  @override
  Future<List<AlarmLogEntry>> query({int? limit}) async {
    await _ensureLoaded();
    if (limit == null) {
      return List<AlarmLogEntry>.unmodifiable(_cache);
    }
    return _cache.take(limit).toList(growable: false);
  }

  @override
  Future<void> clear() async {
    await _ensureLoaded();
    _cache.clear();
    await _persist();
    _emit();
  }

  @override
  Stream<List<AlarmLogEntry>> watch({int? limit}) async* {
    await _ensureLoaded();
    yield _slice(limit);
    yield* _ctrl.stream.map((_) => _slice(limit));
  }

  List<AlarmLogEntry> _slice(int? limit) {
    if (limit == null) {
      return List<AlarmLogEntry>.unmodifiable(_cache);
    }
    return _cache.take(limit).toList(growable: false);
  }

  Future<void> dispose() async {
    await _ctrl.close();
  }
}
