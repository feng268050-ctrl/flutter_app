/// Lifecycle phases for whole-device OTA.
enum OtaPhase {
  idle,
  preparing,
  checking,
  transferring,
  verifying,
  extracting,
  writing,
  arming,
  ok,
  fail;

  /// Wire value for cloud WS / API payloads.
  String get wireName => switch (this) {
        OtaPhase.idle => 'idle',
        OtaPhase.preparing => 'preparing',
        OtaPhase.checking => 'checking',
        OtaPhase.transferring => 'transferring',
        OtaPhase.verifying => 'verifying',
        OtaPhase.extracting => 'extracting',
        OtaPhase.writing => 'writing',
        OtaPhase.arming => 'arming',
        OtaPhase.ok => 'ok',
        OtaPhase.fail => 'fail',
      };

  static OtaPhase? fromWireName(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final phase in OtaPhase.values) {
      if (phase.wireName == value) {
        return phase;
      }
    }
    return null;
  }
}
