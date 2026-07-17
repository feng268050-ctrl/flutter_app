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
    this.inputReady,
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

  /// HID keyboards/mice only: Linux evdev node present and accepting input.
  /// Null when not applicable (phones, audio, …).
  final bool? inputReady;

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
    bool? inputReady,
    bool clearInputReady = false,
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
      inputReady: clearInputReady ? null : (inputReady ?? this.inputReady),
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

final _macAsName = RegExp(
  r'^[0-9A-Fa-f]{2}([:\-])([0-9A-Fa-f]{2}\1){4}[0-9A-Fa-f]{2}$',
);

/// True when [name] is empty or is just a MAC (BlueZ often aliases unnamed LE).
bool bluetoothNameIsPlaceholder(String name) {
  final t = name.trim();
  if (t.isEmpty) {
    return true;
  }
  return _macAsName.hasMatch(t);
}

bool _uuidIsPairingInteresting(String uuid) {
  final u = uuid.toLowerCase();
  const interesting = <String>{
    // Classic HID / HOGP
    '00001124-0000-1000-8000-00805f9b34fb',
    '00001812-0000-1000-8000-00805f9b34fb',
    // Audio / A2DP / AVRCP / HFP (phones, speakers — Settings-relevant)
    '0000110a-0000-1000-8000-00805f9b34fb',
    '0000110b-0000-1000-8000-00805f9b34fb',
    '0000110e-0000-1000-8000-00805f9b34fb',
    '0000111e-0000-1000-8000-00805f9b34fb',
    '0000110c-0000-1000-8000-00805f9b34fb',
    // GATT Device Information often accompanies real peripherals
    '0000180a-0000-1000-8000-00805f9b34fb',
  };
  return interesting.contains(u);
}

/// Settings-style "Available devices" filter (not raw LE advertiser dump).
///
/// Phones/Desktop hide anonymous MAC-only LE beacons and mesh junk; they keep
/// input/audio/phone/computer classes and named devices with useful services.
bool isBluetoothNearbyCandidate(BluetoothRemoteDevice d) {
  switch (d.kind) {
    case BluetoothDeviceKind.keyboard:
    case BluetoothDeviceKind.mouse:
    case BluetoothDeviceKind.phone:
    case BluetoothDeviceKind.computer:
    case BluetoothDeviceKind.audio:
      return true;
    case BluetoothDeviceKind.other:
    case BluetoothDeviceKind.unknown:
      break;
  }

  if (bluetoothNameIsPlaceholder(d.name)) {
    return false;
  }

  if (d.uuids.any(_uuidIsPairingInteresting)) {
    return true;
  }

  // Named + known BlueZ icon (not blank) — typically a real pairing target.
  if (d.icon.isNotEmpty && d.icon != 'undefined') {
    return true;
  }

  // Named Classic inquiry usually sets a non-empty CoD → kind != unknown.
  // Remaining named unknown LE (smart lights, beacons): hide like Settings.
  return false;
}
