import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/network/cloud_environment.dart';
import 'package:cyber_hal/network/proxy.dart';
import 'package:cyber_hal/src/network/linux_proxy.dart';
import 'package:flutter/foundation.dart';

/// Single-candidate reachability probe (GET root). Returns true when reachable.
typedef CloudHttpProbe = Future<bool> Function(
  Uri base, {
  required Duration timeout,
});

/// Worker API bases + WebSocket URL helpers (shared across Apps).
///
/// Default candidate lists match LaserCyber Workers + hyurl fallbacks. Pass
/// custom [testBases] / [prodBases] to override (tests / OEM).
final class CloudApiOriginConfig {
  const CloudApiOriginConfig({
    this.testBases = defaultTestBases,
    this.prodBases = defaultProdBases,
  });

  /// Shared default catalog (LaserCyber appliance).
  static const defaults = CloudApiOriginConfig();

  static const httpsOriginProd = 'https://api-prod.lasercyber.workers.dev';
  static const httpsOriginTest = 'https://api-test.lasercyber.workers.dev';

  static const defaultTestBases = <String>[
    httpsOriginTest,
    'https://lasercyber.hyurl.com/test',
  ];

  static const defaultProdBases = <String>[
    httpsOriginProd,
    'https://lasercyber.hyurl.com/prod',
  ];

  final List<String> testBases;
  final List<String> prodBases;

  /// Ordered candidate bases for [tier] using [defaults].
  static List<Uri> orderedCandidateBases(CloudEnvironmentTier tier) =>
      defaults.candidatesFor(tier);

  /// Ordered candidate bases for [tier] (no trailing slash).
  List<Uri> candidatesFor(CloudEnvironmentTier tier) {
    final raw = switch (tier) {
      CloudEnvironmentTier.test => testBases,
      CloudEnvironmentTier.prod => prodBases,
    };
    return [
      for (final s in raw)
        if (_tryParseBase(s) != null) _tryParseBase(s)!,
    ];
  }

  static Uri? _tryParseBase(String s) {
    try {
      return stripTrailingSlash(Uri.parse(s));
    } catch (_) {
      return null;
    }
  }

  static Uri stripTrailingSlash(Uri base) {
    final s = base.toString();
    if (s.endsWith('/') && s != '${base.scheme}://') {
      return Uri.parse(s.substring(0, s.length - 1));
    }
    return base;
  }

  /// Probe URL = base + `/`.
  static Uri rootProbeUri(Uri base) {
    final normalized = stripTrailingSlash(base);
    final s = normalized.toString();
    return Uri.parse(s.endsWith('/') ? s : '$s/');
  }

  /// Join a path that starts with `/` under [base], preserving base path prefix.
  static Uri joinUnderBase(Uri base, String pathStartingWithSlash) {
    final normalized = stripTrailingSlash(base);
    final path = pathStartingWithSlash.startsWith('/')
        ? pathStartingWithSlash
        : '/$pathStartingWithSlash';
    final prefix = normalized.path;
    if (prefix.isEmpty || prefix == '/') {
      return normalized.replace(path: path);
    }
    final joined = prefix.endsWith('/')
        ? '$prefix${path.substring(1)}'
        : '$prefix$path';
    return normalized.replace(path: joined);
  }

  /// Build `ws(s)://{pinned}/ws/device?sn=…`.
  static Uri deviceWebSocketUri({
    required Uri pinnedHttpBase,
    required String deviceSn,
  }) {
    final http = stripTrailingSlash(pinnedHttpBase);
    final wsScheme = http.scheme == 'https' ? 'wss' : 'ws';
    final joined = joinUnderBase(http, '/ws/device');
    return joined.replace(
      scheme: wsScheme,
      queryParameters: {'sn': deviceSn},
    );
  }
}

/// Concurrent reachability probe: first success wins and returns immediately.
///
/// Successful pins are also written to [pinPath] (default
/// `/run/network/cloud-origin.pin`) so other Apps in the **same boot** can skip
/// re-probe. `/run` is tmpfs — reboot clears the file.
final class CloudApiOriginProber {
  CloudApiOriginProber({
    CloudApiOriginConfig? config,
    CloudHttpProbe? probe,
    Proxy? proxy,
    this.timeout = defaultTimeout,
    this.pinPath = defaultPinPath,
  })  : config = config ?? CloudApiOriginConfig.defaults,
        _probe = probe ??
            ((base, {required timeout}) =>
                defaultHttpProbe(base, timeout: timeout, proxy: proxy));

  /// Per-candidate HTTP budget and whole-round ceiling (fail-fast).
  static const Duration defaultTimeout = Duration(seconds: 2);

  /// Boot-scoped pin file (tmpfs). Survives App seat switches; not reboots.
  static const defaultPinPath = '/run/network/cloud-origin.pin';
  static const pinKeyTier = 'environment_tier';
  static const pinKeyOrigin = 'pinned_origin';

  final CloudApiOriginConfig config;
  final Duration timeout;
  final String pinPath;
  final CloudHttpProbe _probe;

  Uri? _pinned;
  int _generation = 0;

  Uri? get pinnedBase => _pinned;

  void clearPin() {
    _pinned = null;
    try {
      final f = File(pinPath);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (e) {
      debugPrint('api-origin: clearPin delete failed: $e');
    }
  }

  /// Probe [tier] candidates concurrently; returns pinned base or null.
  ///
  /// When [force] is false and a matching boot pin exists, returns it without
  /// HTTP.
  Future<Uri?> probe(
    CloudEnvironmentTier tier, {
    Duration? timeoutOverride,
    bool force = false,
  }) async {
    if (!force) {
      final cached = _readBootPin(tier);
      if (cached != null) {
        _pinned = cached;
        debugPrint('api-origin: loaded boot pin $_pinned');
        return _pinned;
      }
    }

    final generation = ++_generation;
    final effectiveTimeout = timeoutOverride ?? timeout;
    final candidates = config.candidatesFor(tier);
    if (candidates.isEmpty) {
      debugPrint('api-origin: no candidates for $tier');
      return null;
    }
    if (candidates.length == 1) {
      final only = candidates.first;
      final ok = await _safeProbe(only, timeout: effectiveTimeout);
      if (generation != _generation) {
        return _pinned;
      }
      if (ok) {
        return _commitPin(only, tier);
      }
      return null;
    }

    final completer = Completer<Uri?>();
    var remaining = candidates.length;
    var won = false;

    for (final base in candidates) {
      unawaited(() async {
        final ok = await _safeProbe(base, timeout: effectiveTimeout);
        if (generation != _generation) {
          return;
        }
        if (ok && !won) {
          won = true;
          final pinned = _commitPin(base, tier);
          _generation++;
          if (!completer.isCompleted) {
            completer.complete(pinned);
          }
        }
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }());
    }

    return completer.future.timeout(
      effectiveTimeout,
      onTimeout: () => won ? _pinned : null,
    );
  }

  Uri _commitPin(Uri base, CloudEnvironmentTier tier) {
    _pinned = CloudApiOriginConfig.stripTrailingSlash(base);
    debugPrint('api-origin: pinned $_pinned');
    _writeBootPin(tier, _pinned!);
    return _pinned!;
  }

  Uri? _readBootPin(CloudEnvironmentTier tier) {
    try {
      final f = File(pinPath);
      if (!f.existsSync()) {
        return null;
      }
      final map = <String, String>{};
      for (final line in f.readAsStringSync().split('\n')) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith('#')) {
          continue;
        }
        final eq = t.indexOf('=');
        if (eq <= 0) {
          continue;
        }
        map[t.substring(0, eq).trim()] = t.substring(eq + 1).trim();
      }
      if (map[pinKeyTier] != tier.wireName) {
        return null;
      }
      final raw = map[pinKeyOrigin];
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return CloudApiOriginConfig.stripTrailingSlash(Uri.parse(raw));
    } catch (e) {
      debugPrint('api-origin: read boot pin failed: $e');
      return null;
    }
  }

  void _writeBootPin(CloudEnvironmentTier tier, Uri origin) {
    try {
      final f = File(pinPath);
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(
        '$pinKeyTier=${tier.wireName}\n'
        '$pinKeyOrigin=${origin.toString()}\n',
        flush: true,
      );
    } catch (e) {
      debugPrint('api-origin: write boot pin failed: $e');
    }
  }

  Future<bool> _safeProbe(Uri base, {required Duration timeout}) async {
    try {
      return await _probe(base, timeout: timeout);
    } catch (e) {
      debugPrint('api-origin: probe failed $base: $e');
      return false;
    }
  }

  /// Default GET `/` probe using [HttpClient]; honors [proxy] when enabled.
  static Future<bool> defaultHttpProbe(
    Uri base, {
    required Duration timeout,
    Proxy? proxy,
  }) async {
    HttpClient? client;
    try {
      final url = CloudApiOriginConfig.rootProbeUri(base);
      client = HttpClient();
      client.connectionTimeout = timeout;
      client.idleTimeout = timeout;
      final px = proxy ?? LinuxProxy();
      final settings = await px.getSettings();
      final u = settings.httpProxy ?? settings.httpsProxy ?? settings.allProxy;
      if (settings.enabled && u != null && u.host.isNotEmpty) {
        client.findProxy = (_) => 'PROXY ${u.host}:${u.port}';
        if (u.username != null && u.username!.isNotEmpty) {
          client.addProxyCredentials(
            u.host,
            u.port,
            'proxy',
            HttpClientBasicCredentials(u.username!, u.password ?? ''),
          );
        }
      } else {
        client.findProxy = (_) => 'DIRECT';
      }
      final req = await client.getUrl(url).timeout(timeout);
      req.followRedirects = true;
      final resp = await req.close().timeout(timeout);
      // Drain a tiny body so the connection can close cleanly.
      await resp.drain<void>().timeout(timeout);
      return resp.statusCode > 0;
    } catch (e) {
      debugPrint('api-origin: probe failed $base: $e');
      return false;
    } finally {
      client?.close(force: true);
    }
  }
}
