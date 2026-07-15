import 'package:lws_hmi/platform/ethernet/ethernet_models.dart';

/// Reusable Ethernet (eth0) API (Linux helpers now; Android later).
abstract class EthernetController {
  /// Kernel netdev name (`eth0` on product image).
  String get interfaceName;

  Stream<EthAdminState> get admin;

  Stream<EthLinkState> get link;

  /// Last known admin/link (streams are broadcast and do not replay).
  EthAdminState get currentAdmin;

  EthLinkState get currentLink;

  Future<void> setInterfaceEnabled(bool enabled);

  Future<EthIpv4Config> getIpv4Config();

  Future<void> setIpv4Config(EthIpv4Config config);

  /// Snapshot of carrier + IPv4 details (for Settings / status UI).
  Future<EthLinkState> linkDetails();

  /// Align admin/link with the live system (after boot restore).
  Future<void> syncFromSystem();

  Future<void> dispose();
}
