import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';

/// Parsers for `bluetoothctl show` / `devices` / `info` text.
class BluetoothctlParse {
  static String normalizeAddress(String raw) {
    return raw.trim().toUpperCase().replaceAll('-', ':');
  }

  static bool looksLikeAddress(String s) {
    return RegExp(
      r'^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$',
    ).hasMatch(s.trim());
  }

  static BluetoothAdapterInfo parseShow(String text) {
    String address = '';
    String name = '';
    var powered = false;
    var discoverable = false;
    var pairable = false;
    for (final line in text.split('\n')) {
      final t = line.trim();
      final lower = t.toLowerCase();
      if (lower.startsWith('controller ')) {
        final parts = t.split(RegExp(r'\s+'));
        if (parts.length >= 2 && looksLikeAddress(parts[1])) {
          address = normalizeAddress(parts[1]);
        }
      } else if (lower.contains('name:')) {
        name = t.split(':').skip(1).join(':').trim();
      } else if (lower.contains('alias:')) {
        final alias = t.split(':').skip(1).join(':').trim();
        if (alias.isNotEmpty) {
          name = alias;
        }
      } else if (lower.contains('powered:')) {
        powered = lower.contains('yes');
      } else if (lower.contains('discoverable:')) {
        discoverable = lower.contains('yes');
      } else if (lower.contains('pairable:')) {
        pairable = lower.contains('yes');
      }
    }
    return BluetoothAdapterInfo(
      address: address,
      name: name,
      powered: powered,
      discoverable: discoverable,
      pairable: pairable,
    );
  }

  /// Lines like: `Device AA:BB:CC:DD:EE:FF Some Name`
  static List<BluetoothRemoteDevice> parseDevices(String text) {
    final out = <BluetoothRemoteDevice>[];
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (!t.toLowerCase().startsWith('device ')) {
        continue;
      }
      final parts = t.split(RegExp(r'\s+'));
      if (parts.length < 2 || !looksLikeAddress(parts[1])) {
        continue;
      }
      final addr = normalizeAddress(parts[1]);
      final name = parts.length > 2 ? parts.sublist(2).join(' ') : '';
      out.add(BluetoothRemoteDevice(address: addr, name: name));
    }
    return out;
  }

  static BluetoothRemoteDevice mergeInfo(
    BluetoothRemoteDevice base,
    String infoText,
  ) {
    var paired = base.paired;
    var trusted = base.trusted;
    var connected = base.connected;
    var name = base.name;
    for (final line in infoText.split('\n')) {
      final trimmed = line.trim();
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('name:') || lower.startsWith('alias:')) {
        final n = trimmed.split(':').skip(1).join(':').trim();
        if (n.isNotEmpty) {
          name = n;
        }
      } else if (lower.startsWith('paired:')) {
        paired = lower.contains('yes');
      } else if (lower.startsWith('trusted:')) {
        trusted = lower.contains('yes');
      } else if (lower.startsWith('connected:')) {
        connected = lower.contains('yes');
      }
    }
    return BluetoothRemoteDevice(
      address: base.address,
      name: name,
      paired: paired,
      trusted: trusted,
      connected: connected,
      discovered: base.discovered,
      rssi: base.rssi,
      kind: base.kind,
      uuids: base.uuids,
      icon: base.icon,
    );
  }
}
