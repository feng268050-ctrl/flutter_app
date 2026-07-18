import 'dart:async';
import 'dart:convert';

import 'package:cyber_hal/src/network/wpa_supplicant_dbus.dart';
import 'package:dbus/dbus.dart';

/// Thin client for `org.freedesktop.network1` link status (D11).
///
/// Address / DNS / gateway discovery is **dual-compatible**:
/// 1. **Modern** (systemd ~249+ including 254): [Link.Describe] JSON — this is
///    what current upstream `org.freedesktop.network1(5)` documents.
/// 2. **Older** networkd builds: Link property `Addresses` (`a(iiay)`).
///
/// Live updates still use PropertiesChanged on state fields
/// (`OperationalState`, `IPv4AddressState`, …); callers re-read via [readLink].
class NetworkdDbus {
  NetworkdDbus({
    DBusClient? client,
    this.busName = 'org.freedesktop.network1',
  }) : _client = client ?? DBusClient.system(),
       _ownsClient = client == null;

  final DBusClient _client;
  final bool _ownsClient;
  final String busName;

  DBusObjectPath? _linkPath;
  StreamSubscription<DBusPropertiesChangedSignal>? _propsSub;
  StreamSubscription<DBusNameOwnerChangedEvent>? _ownerSub;

  /// Watch Link properties for [iface]; [onChange] on PropertiesChanged + attach.
  Future<void> watchLink(
    String iface, {
    required void Function() onChange,
  }) async {
    await cancelWatch();
    _ownerSub = _client.nameOwnerChanged.listen((ev) {
      if (ev.name != busName) {
        return;
      }
      if (ev.newOwner != null && ev.newOwner!.isNotEmpty) {
        unawaited(_attachLink(iface, onChange));
      }
    });
    await _attachLink(iface, onChange);
  }

  Future<void> _attachLink(String iface, void Function() onChange) async {
    try {
      _linkPath = await getLinkPath(iface);
    } catch (_) {
      return;
    }
    final obj = DBusRemoteObject(_client, name: busName, path: _linkPath!);
    await _propsSub?.cancel();
    _propsSub = obj.propertiesChanged.listen((sig) {
      if (sig.propertiesInterface == 'org.freedesktop.network1.Link' ||
          sig.invalidatedProperties.isNotEmpty) {
        onChange();
      }
    });
    onChange();
  }

  Future<DBusObjectPath> getLinkPath(String iface) async {
    final mgr = DBusRemoteObject(
      _client,
      name: busName,
      path: DBusObjectPath('/org/freedesktop/network1'),
    );
    final r = await mgr.callMethod(
      'org.freedesktop.network1.Manager',
      'GetLinkByName',
      [DBusString(iface)],
      replySignature: DBusSignature('io'),
    );
    return r.returnValues[1] as DBusObjectPath;
  }

  Future<NetworkdLinkSnapshot> readLink(String iface) async {
    final path = _linkPath ?? await getLinkPath(iface);
    _linkPath = path;
    final obj = DBusRemoteObject(_client, name: busName, path: path);

    NetworkdLinkSnapshot? fromDescribe;
    try {
      fromDescribe = await _readViaDescribe(obj);
    } catch (_) {
      fromDescribe = null;
    }

    // Older networkd: Addresses property. Also merge if Describe lacked IPv4.
    NetworkdLinkSnapshot? fromProps;
    try {
      fromProps = await _readViaProperties(obj);
    } catch (_) {
      fromProps = null;
    }

    if (fromDescribe != null && fromDescribe.primaryIpv4 != null) {
      return fromDescribe;
    }
    if (fromProps != null && fromProps.primaryIpv4 != null) {
      // Prefer richer Describe operational/dns when present.
      if (fromDescribe != null) {
        return NetworkdLinkSnapshot(
          operational: fromDescribe.operational.isNotEmpty
              ? fromDescribe.operational
              : fromProps.operational,
          addresses: fromProps.addresses,
          gateway: fromDescribe.gateway ?? fromProps.gateway,
          dns: fromDescribe.dns ?? fromProps.dns,
        );
      }
      return fromProps;
    }
    if (fromDescribe != null) {
      return fromDescribe;
    }
    if (fromProps != null) {
      return fromProps;
    }

    throw StateError(
      'networkd Link $iface: neither Describe nor Addresses available',
    );
  }

  Future<NetworkdLinkSnapshot> _readViaDescribe(DBusRemoteObject obj) async {
    final r = await obj.callMethod(
      'org.freedesktop.network1.Link',
      'Describe',
      const [],
      replySignature: DBusSignature('s'),
    );
    final jsonStr = (r.returnValues.first as DBusString).value;
    return parseNetworkdDescribeJson(jsonStr);
  }

  Future<NetworkdLinkSnapshot> _readViaProperties(DBusRemoteObject obj) async {
    String? operational;
    try {
      final v = await obj.getProperty(
        'org.freedesktop.network1.Link',
        'OperationalState',
        signature: DBusSignature('s'),
      );
      if (v is DBusString) {
        operational = v.value;
      }
    } catch (_) {}

    List<({String address, int prefix})> addresses = const [];
    try {
      final v = await obj.getProperty(
        'org.freedesktop.network1.Link',
        'Addresses',
      );
      addresses = parseNetworkdAddresses(v);
    } catch (_) {}

    return NetworkdLinkSnapshot(
      operational: operational ?? '',
      addresses: addresses,
    );
  }

  Future<void> cancelWatch() async {
    await _propsSub?.cancel();
    _propsSub = null;
    await _ownerSub?.cancel();
    _ownerSub = null;
  }

  Future<void> close() async {
    await cancelWatch();
    if (_ownsClient) {
      await _client.close();
    }
  }
}

final class NetworkdLinkSnapshot {
  const NetworkdLinkSnapshot({
    required this.operational,
    this.addresses = const [],
    this.gateway,
    this.dns,
  });

  final String operational;
  final List<({String address, int prefix})> addresses;
  final String? gateway;
  final String? dns;

  String? get primaryIpv4 {
    for (final a in addresses) {
      return a.address;
    }
    return null;
  }

  int? get primaryPrefix {
    for (final a in addresses) {
      return a.prefix;
    }
    return null;
  }

  bool get hasCarrier =>
      operational == 'carrier' ||
      operational == 'degraded' ||
      operational == 'routable' ||
      operational == 'enslaved';
}

/// Parse systemd-networkd `Link.Describe` JSON into a snapshot.
NetworkdLinkSnapshot parseNetworkdDescribeJson(String jsonStr) {
  final dynamic root = jsonDecode(jsonStr);
  if (root is! Map<String, dynamic>) {
    return const NetworkdLinkSnapshot(operational: '');
  }
  final operational = root['OperationalState'] as String? ?? '';
  final addresses = <({String address, int prefix})>[];
  final rawAddrs = root['Addresses'];
  if (rawAddrs is List) {
    for (final entry in rawAddrs) {
      if (entry is! Map) {
        continue;
      }
      final family = entry['Family'];
      if (family != 2) {
        continue; // AF_INET
      }
      final addrList = entry['Address'];
      final prefix = entry['PrefixLength'];
      if (addrList is! List || addrList.length != 4 || prefix is! int) {
        continue;
      }
      final b =
          addrList.map((e) => e is int ? e : int.tryParse('$e') ?? -1).toList();
      if (b.any((v) => v < 0 || v > 255)) {
        continue;
      }
      addresses.add((
        address: '${b[0]}.${b[1]}.${b[2]}.${b[3]}',
        prefix: prefix,
      ));
    }
  }

  String? gateway;
  final routes = root['Routes'];
  if (routes is List) {
    for (final entry in routes) {
      if (entry is! Map) {
        continue;
      }
      if (entry['Family'] != 2) {
        continue;
      }
      final destPrefix = entry['DestinationPrefixLength'];
      final gw = entry['Gateway'];
      if (destPrefix == 0 && gw is List && gw.length == 4) {
        final b =
            gw.map((e) => e is int ? e : int.tryParse('$e') ?? -1).toList();
        if (b.every((v) => v >= 0 && v <= 255)) {
          gateway = '${b[0]}.${b[1]}.${b[2]}.${b[3]}';
          break;
        }
      }
    }
  }

  String? dns;
  final dnsList = root['DNS'];
  if (dnsList is List) {
    for (final entry in dnsList) {
      if (entry is! Map || entry['Family'] != 2) {
        continue;
      }
      final addrList = entry['Address'];
      if (addrList is! List || addrList.length != 4) {
        continue;
      }
      final b =
          addrList.map((e) => e is int ? e : int.tryParse('$e') ?? -1).toList();
      if (b.every((v) => v >= 0 && v <= 255)) {
        dns = '${b[0]}.${b[1]}.${b[2]}.${b[3]}';
        break;
      }
    }
  }

  return NetworkdLinkSnapshot(
    operational: operational,
    addresses: addresses,
    gateway: gateway,
    dns: dns,
  );
}
