/// Logical network role; board profile maps roles → iface names.
///
/// Product App code MUST address roles, not hard-code `eth0` / `wlan0`.
enum NetRole {
  ethernetPrimary('ethernet.primary'),
  wifiStation('wifi.station');

  const NetRole(this.id);

  final String id;

  static NetRole? tryParse(String id) {
    for (final role in NetRole.values) {
      if (role.id == id) return role;
    }
    return null;
  }
}
