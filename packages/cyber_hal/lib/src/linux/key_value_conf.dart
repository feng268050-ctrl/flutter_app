import 'dart:io';

import 'package:flutter/foundation.dart';

/// Parse `key=value` conf (mouse.conf-style). Empty / `#` lines ignored.
Map<String, String> parseKeyValueConf(String raw) {
  final out = <String, String>{};
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final eq = trimmed.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    final key = trimmed.substring(0, eq).trim();
    final value = trimmed.substring(eq + 1).trim();
    if (key.isNotEmpty) {
      out[key] = value;
    }
  }
  return out;
}

/// Encode map as `key=value\n` lines (stable key order: sorted).
String encodeKeyValueConf(Map<String, String> entries) {
  final keys = entries.keys.toList()..sort();
  final buf = StringBuffer();
  for (final k in keys) {
    buf.writeln('$k=${entries[k]}');
  }
  return buf.toString();
}

Future<Map<String, String>> readKeyValueConfFile(String path) async {
  try {
    final f = File(path);
    if (!await f.exists()) {
      return {};
    }
    return parseKeyValueConf(await f.readAsString());
  } catch (e) {
    debugPrint('kv-conf: read $path failed: $e');
    return {};
  }
}

Map<String, String> readKeyValueConfFileSync(String path) {
  try {
    final f = File(path);
    if (!f.existsSync()) {
      return {};
    }
    return parseKeyValueConf(f.readAsStringSync());
  } catch (e) {
    debugPrint('kv-conf: sync read $path failed: $e');
    return {};
  }
}

/// Read-modify-write: merge [updates] into existing conf (preserves other keys).
Future<void> upsertKeyValueConfFile(
  String path,
  Map<String, String> updates,
) async {
  final map = await readKeyValueConfFile(path);
  map.addAll(updates);
  try {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(encodeKeyValueConf(map), flush: true);
  } catch (e) {
    debugPrint('kv-conf: write $path failed: $e');
  }
}
