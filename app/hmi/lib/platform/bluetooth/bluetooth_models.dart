enum BluetoothAdapterState { off, starting, on, error }

enum BluetoothDeviceKind {
  unknown,
  keyboard,
  mouse,
  phone,
  computer,
  audio,
  other,
}

enum BluetoothPairingChallengeKind {
  confirm,
  displayPasskey,
  displayPinCode,
  requestPasskey,
  requestPinCode,
  authorizeService,
  requestAuthorization,
}

/// Structured failure from scan/pair/connect/remove (non-fatal).
class BluetoothOperationException implements Exception {
  BluetoothOperationException(this.message, {this.address});

  final String message;
  final String? address;

  @override
  String toString() =>
      address == null ? message : '$message ($address)';
}

class BluetoothRemoteDevice {
  const BluetoothRemoteDevice({
    required this.address,
    this.name = '',
    this.paired = false,
    this.trusted = false,
    this.connected = false,
    this.discovered = false,
    this.rssi,
    this.kind = BluetoothDeviceKind.unknown,
    this.uuids = const [],
    this.icon = '',
  });

  final String address;
  final String name;
  final bool paired;
  final bool trusted;
  final bool connected;

  /// Seen during the current or recent discovery window.
  final bool discovered;
  final int? rssi;
  final BluetoothDeviceKind kind;
  final List<String> uuids;
  final String icon;

  BluetoothRemoteDevice copyWith({
    String? address,
    String? name,
    bool? paired,
    bool? trusted,
    bool? connected,
    bool? discovered,
    int? rssi,
    bool clearRssi = false,
    BluetoothDeviceKind? kind,
    List<String>? uuids,
    String? icon,
  }) {
    return BluetoothRemoteDevice(
      address: address ?? this.address,
      name: name ?? this.name,
      paired: paired ?? this.paired,
      trusted: trusted ?? this.trusted,
      connected: connected ?? this.connected,
      discovered: discovered ?? this.discovered,
      rssi: clearRssi ? null : (rssi ?? this.rssi),
      kind: kind ?? this.kind,
      uuids: uuids ?? this.uuids,
      icon: icon ?? this.icon,
    );
  }
}

class BluetoothAdapterInfo {
  const BluetoothAdapterInfo({
    this.address = '',
    this.name = '',
    this.powered = false,
    this.discoverable = false,
    this.pairable = false,
  });

  final String address;
  final String name;
  final bool powered;
  final bool discoverable;
  final bool pairable;
}

class BluetoothPairingChallenge {
  const BluetoothPairingChallenge({
    required this.id,
    required this.address,
    required this.kind,
    this.name = '',
    this.passkey,
    this.pinCode,
    this.serviceUuid,
    this.enteredDigits,
  });

  final String id;
  final String address;
  final String name;
  final BluetoothPairingChallengeKind kind;
  final int? passkey;
  final String? pinCode;
  final String? serviceUuid;
  final int? enteredDigits;
}

/// Infer best-effort device kind from BlueZ icon / Class / UUIDs.
BluetoothDeviceKind inferBluetoothDeviceKind({
  String icon = '',
  int deviceClass = 0,
  Iterable<String> uuids = const [],
}) {
  final iconLower = icon.toLowerCase();
  if (iconLower.contains('keyboard')) {
    return BluetoothDeviceKind.keyboard;
  }
  if (iconLower.contains('mouse') || iconLower.contains('pointing')) {
    return BluetoothDeviceKind.mouse;
  }
  if (iconLower.contains('phone') || iconLower.contains('cellular')) {
    return BluetoothDeviceKind.phone;
  }
  if (iconLower.contains('computer') || iconLower.contains('laptop')) {
    return BluetoothDeviceKind.computer;
  }
  if (iconLower.contains('audio') || iconLower.contains('headset')) {
    return BluetoothDeviceKind.audio;
  }

  final uuidSet = uuids.map((u) => u.toLowerCase()).toSet();
  // HID / HOGP
  if (uuidSet.contains('00001124-0000-1000-8000-00805f9b34fb') ||
      uuidSet.contains('00001812-0000-1000-8000-00805f9b34fb')) {
    final major = (deviceClass >> 8) & 0x1f;
    final minor = (deviceClass >> 2) & 0x3f;
    if (major == 5) {
      // Peripheral
      if ((minor & 0x10) != 0 || (minor & 0x40) != 0) {
        return BluetoothDeviceKind.keyboard;
      }
      if ((minor & 0x20) != 0 || (minor & 0x80) != 0) {
        return BluetoothDeviceKind.mouse;
      }
    }
    return BluetoothDeviceKind.other;
  }

  if (deviceClass != 0) {
    final major = (deviceClass >> 8) & 0x1f;
    final minor = (deviceClass >> 2) & 0x3f;
    switch (major) {
      case 1:
        return BluetoothDeviceKind.computer;
      case 2:
        return BluetoothDeviceKind.phone;
      case 4:
        return BluetoothDeviceKind.audio;
      case 5:
        if ((minor & 0x10) != 0 || (minor & 0x40) != 0) {
          return BluetoothDeviceKind.keyboard;
        }
        if ((minor & 0x20) != 0 || (minor & 0x80) != 0) {
          return BluetoothDeviceKind.mouse;
        }
        return BluetoothDeviceKind.other;
    }
  }

  return BluetoothDeviceKind.unknown;
}
