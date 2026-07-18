/// HTTP(S) proxy preferences for outbound client requests.
class HttpProxyConfig {
  const HttpProxyConfig({
    this.enabled = false,
    this.host = '',
    this.port = 8080,
    this.username = '',
    this.password = '',
  });

  final bool enabled;
  final String host;
  final int port;
  final String username;
  final String password;

  static const disabled = HttpProxyConfig();

  HttpProxyConfig copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return HttpProxyConfig(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  /// Never include password.
  @override
  String toString() =>
      'HttpProxyConfig(enabled=$enabled, host=$host, port=$port, user=$username)';
}

class HttpProbeResult {
  const HttpProbeResult({
    required this.ok,
    this.statusCode,
    this.reasonPhrase,
    this.bodySnippet = '',
    this.error,
    this.elapsedMs = 0,
  });

  final bool ok;
  final int? statusCode;
  final String? reasonPhrase;
  final String bodySnippet;
  final String? error;
  final int elapsedMs;

  String get summary {
    if (error != null && error!.isNotEmpty) {
      return 'error: $error (${elapsedMs}ms)';
    }
    return 'HTTP $statusCode ${reasonPhrase ?? ''} (${elapsedMs}ms)\n$bodySnippet';
  }
}

/// Legacy Demo parser for key=value proxy files (password stored; never logged).
///
/// Live system proxy is `/var/lib/network/proxy.conf` via `LinuxProxy` +
/// `apply-proxy`. This store remains for unit tests of the older flat format.
class HttpProxyStore {
  static const defaultPath = '/var/lib/network/proxy.conf';

  static HttpProxyConfig parse(String text) {
    final map = <String, String>{};
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) {
        continue;
      }
      final i = t.indexOf('=');
      if (i <= 0) {
        continue;
      }
      map[t.substring(0, i).trim()] = t.substring(i + 1).trim();
    }
    final enabled = (map['enabled'] ?? 'false').toLowerCase() == 'true';
    final port = int.tryParse(map['port'] ?? '') ?? 8080;
    return HttpProxyConfig(
      enabled: enabled,
      host: map['host'] ?? '',
      port: port.clamp(1, 65535),
      username: map['user'] ?? '',
      password: map['password'] ?? '',
    );
  }

  static String serialize(HttpProxyConfig c) {
    return 'enabled=${c.enabled}\n'
        'host=${c.host}\n'
        'port=${c.port}\n'
        'user=${c.username}\n'
        'password=${c.password}\n';
  }

  /// Redact password field for logs / debug UI.
  static String redact(String text) {
    return text.replaceAllMapped(
      RegExp(r'^password=.*$', multiLine: true),
      (_) => 'password=***',
    );
  }
}
