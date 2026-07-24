/// Portable capability flags advertised by a [BoardProfile].
enum Capability {
  ethernet,
  wifi,
  proxy,
  bluetooth,
  backlight,
  volume,
  keyboard,
  mouse,
  gpio,
  modbus,
  sysInfo,
  datetime,
  sshDebug,
  usbOtg,
}

/// Immutable capability set for the active board.
final class Capabilities {
  const Capabilities(this._flags);

  factory Capabilities.fromIds(Iterable<String> ids) {
    final flags = <Capability>{};
    for (final id in ids) {
      final match = Capability.values.where((c) => c.name == id);
      if (match.isNotEmpty) {
        flags.add(match.first);
      }
    }
    return Capabilities(flags);
  }

  final Set<Capability> _flags;

  bool has(Capability c) => _flags.contains(c);

  Set<Capability> get all => Set.unmodifiable(_flags);
}
