/// One-shot handoff: boot self-check Modbus group reads → live-cache seed.
///
/// Self-check reads full `status` / `data` groups once for evaluation; the live
/// cache consumes those maps so it does not immediately re-hit the RTU bus.
abstract final class BootSelfCheckLiveCacheSeed {
  static Map<String, Object?>? _status;
  static Map<String, Object?>? _data;

  static void offer({
    Map<String, Object?>? status,
    Map<String, Object?>? data,
  }) {
    if (status != null && status.isNotEmpty) {
      _status = Map<String, Object?>.of(status);
    }
    if (data != null && data.isNotEmpty) {
      _data = Map<String, Object?>.of(data);
    }
  }

  /// Consume the offered status group (null if none / already taken).
  static Map<String, Object?>? takeStatus() {
    final out = _status;
    _status = null;
    return out;
  }

  /// Consume the offered data group (null if none / already taken).
  static Map<String, Object?>? takeData() {
    final out = _data;
    _data = null;
    return out;
  }

  static void resetForTest() {
    _status = null;
    _data = null;
  }
}
