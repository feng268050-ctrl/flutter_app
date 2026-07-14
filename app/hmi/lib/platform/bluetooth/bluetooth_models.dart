enum BluetoothAdapterState { off, starting, on, error }

class BluetoothRemoteDevice {
  const BluetoothRemoteDevice({
    required this.address,
    this.name = '',
    this.paired = false,
    this.trusted = false,
    this.connected = false,
  });

  final String address;
  final String name;
  final bool paired;
  final bool trusted;
  final bool connected;
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
