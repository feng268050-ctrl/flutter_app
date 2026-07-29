import 'package:lws_hmi/platform/cloud/cloud_environment_tier.dart';

/// Worker API bases + WebSocket URL helpers (lws-ui `DeviceApiOriginConfig` parity).
abstract final class DeviceApiOriginConfig {
  static const httpsOriginProd = 'https://api-prod.lasercyber.workers.dev';
  static const httpsOriginTest = 'https://api-test.lasercyber.workers.dev';

  static const _devBases = <String>[
    'http://10.0.2.2:8787',
    'http://10.0.1.110:8787',
  ];

  static const _testBases = <String>[
    httpsOriginTest,
    'https://lasercyber.hyurl.com/test',
  ];

  static const _prodBases = <String>[
    httpsOriginProd,
    'https://lasercyber.hyurl.com/prod',
  ];

  /// Ordered candidate bases for [tier] (no trailing slash).
  static List<Uri> orderedCandidateBases(CloudEnvironmentTier tier) {
    final raw = switch (tier) {
      CloudEnvironmentTier.dev => _devBases,
      CloudEnvironmentTier.test => _testBases,
      CloudEnvironmentTier.prod => _prodBases,
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
