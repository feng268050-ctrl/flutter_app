import 'package:cyber_hal/src/core/net_role.dart';

/// Ethernet L3 via networkd (after D11 cutover). Scaffold stub.
abstract class Ethernet {
  Future<EthernetStatus> status(NetRole role);

  Future<void> setDhcp(NetRole role);

  Future<void> setStatic(
    NetRole role, {
    required String addressCidr,
    String? gateway,
    List<String> dns = const [],
  });
}

final class EthernetStatus {
  const EthernetStatus({
    required this.role,
    required this.iface,
    this.operational,
    this.addresses = const [],
  });

  final NetRole role;
  final String iface;
  final String? operational;
  final List<String> addresses;
}
