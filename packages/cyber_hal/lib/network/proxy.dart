/// System-wide multi-scheme proxy (D18). Scaffold stub — §6.
abstract class Proxy {
  Future<ProxySettings> getSettings();

  Future<void> setSettings(ProxySettings settings);

  Future<void> clear();
}

final class ProxySettings {
  const ProxySettings({
    this.enabled = false,
    this.httpProxy,
    this.httpsProxy,
    this.ftpProxy,
    this.allProxy,
    this.noProxy = const [],
  });

  final bool enabled;
  final ProxyUri? httpProxy;
  final ProxyUri? httpsProxy;
  final ProxyUri? ftpProxy;
  final ProxyUri? allProxy;
  final List<String> noProxy;
}

enum ProxyScheme {
  http,
  https,
  socks4,
  socks4a,
  socks5,
  socks5h,
  ftp,
}

final class ProxyUri {
  const ProxyUri({
    required this.scheme,
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  final ProxyScheme scheme;
  final String host;
  final int port;
  final String? username;
  final String? password;
}
