import 'dart:io';

import 'package:cyber_hal/src/network/wifi_credential_vault.dart';

/// One plaintext PSK extracted from a wpa conf network block.
final class WpaConfPlaintextPsk {
  const WpaConfPlaintextPsk({required this.ssid, required this.psk});

  final String ssid;
  final String psk;
}

/// Pure helpers: extract / scrub plaintext `psk=` / `passphrase=` from conf.
///
/// Host-testable; does not touch Secrets or D-Bus.
abstract final class WpaConfPskMigration {
  /// True when conf still has a plaintext `psk=` or `passphrase=` assignment.
  static bool hasPlaintextPsk(String conf) {
    return extractPlaintextPsks(conf).isNotEmpty;
  }

  /// Extract SSID + PSK pairs from `network={...}` blocks that still hold
  /// plaintext secrets.
  static List<WpaConfPlaintextPsk> extractPlaintextPsks(String conf) {
    final out = <WpaConfPlaintextPsk>[];
    for (final block in _networkBlocks(conf)) {
      final ssid = _field(block, 'ssid');
      final psk = _field(block, 'psk') ?? _field(block, 'passphrase');
      if (ssid == null || ssid.isEmpty || psk == null || psk.isEmpty) {
        continue;
      }
      out.add(WpaConfPlaintextPsk(ssid: ssid, psk: psk));
    }
    return out;
  }

  /// Remove plaintext `psk=` / `passphrase=` lines and ensure `mem_only_psk=1`
  /// on network blocks that had a secret (or already use mem_only).
  static String scrubPlaintextPsks(String conf) {
    final buf = StringBuffer();
    var i = 0;
    while (i < conf.length) {
      final start = conf.indexOf('network={', i);
      if (start < 0) {
        buf.write(conf.substring(i));
        break;
      }
      buf.write(conf.substring(i, start));
      final bodyStart = start + 'network={'.length;
      final end = _findBlockEnd(conf, bodyStart);
      if (end < 0) {
        buf.write(conf.substring(start));
        break;
      }
      final body = conf.substring(bodyStart, end);
      final hadSecret = _field(body, 'psk') != null ||
          _field(body, 'passphrase') != null;
      var scrubbed = _removeFieldLines(body, const ['psk', 'passphrase']);
      if (hadSecret && !_hasField(scrubbed, 'mem_only_psk')) {
        scrubbed = '${scrubbed.trimRight()}\n\tmem_only_psk=1\n';
      }
      buf.write('network={');
      buf.write(scrubbed);
      buf.write('}');
      i = end + 1;
    }
    return buf.toString();
  }

  /// Import plaintext conf secrets into [vault] and rewrite [confPath].
  ///
  /// Idempotent when conf no longer contains plaintext PSKs.
  /// Returns number of SSIDs imported.
  static Future<int> migrateFile({
    required String confPath,
    required WifiCredentialVault vault,
  }) async {
    final f = File(confPath);
    if (!await f.exists()) {
      return 0;
    }
    final conf = await f.readAsString();
    final entries = extractPlaintextPsks(conf);
    if (entries.isEmpty) {
      return 0;
    }
    for (final e in entries) {
      await vault.put(e.ssid, e.psk);
    }
    final scrubbed = scrubPlaintextPsks(conf);
    final tmp = File('$confPath.tmp');
    await tmp.writeAsString(scrubbed, flush: true);
    await tmp.rename(confPath);
    try {
      await Process.run('chmod', ['600', confPath]);
    } catch (_) {}
    return entries.length;
  }

  static Iterable<String> _networkBlocks(String conf) sync* {
    var i = 0;
    while (i < conf.length) {
      final start = conf.indexOf('network={', i);
      if (start < 0) {
        return;
      }
      final bodyStart = start + 'network={'.length;
      final end = _findBlockEnd(conf, bodyStart);
      if (end < 0) {
        return;
      }
      yield conf.substring(bodyStart, end);
      i = end + 1;
    }
  }

  static int _findBlockEnd(String conf, int bodyStart) {
    var depth = 1;
    for (var i = bodyStart; i < conf.length; i++) {
      final c = conf[i];
      if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) {
          return i;
        }
      }
    }
    return -1;
  }

  static bool _hasField(String body, String name) {
    return _field(body, name) != null;
  }

  /// Read a simple `key=value` / `key="value"` field from a network body.
  ///
  /// Matches the exact key only (`psk` does not match `mem_only_psk`).
  static String? _field(String body, String name) {
    for (final line in body.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      final eq = trimmed.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      final key = trimmed.substring(0, eq).trim();
      if (key != name) {
        continue;
      }
      var v = trimmed.substring(eq + 1).trim();
      // Strip inline comments (unquoted).
      if (!v.startsWith('"')) {
        final hash = v.indexOf('#');
        if (hash >= 0) {
          v = v.substring(0, hash).trim();
        }
      }
      if (v.startsWith('"') && v.endsWith('"') && v.length >= 2) {
        return v.substring(1, v.length - 1);
      }
      return v;
    }
    return null;
  }

  static String _removeFieldLines(String body, List<String> names) {
    final lines = body.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final trimmed = line.trimLeft();
      var drop = false;
      for (final name in names) {
        final eq = trimmed.indexOf('=');
        if (eq <= 0) {
          continue;
        }
        final key = trimmed.substring(0, eq).trim();
        if (key == name) {
          drop = true;
          break;
        }
      }
      if (!drop) {
        kept.add(line);
      }
    }
    return kept.join('\n');
  }
}
