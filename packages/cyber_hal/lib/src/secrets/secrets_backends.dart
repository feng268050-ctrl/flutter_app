/// Queryable Secrets backend identifiers (never key material).
abstract final class SecretsBackendId {
  /// In-memory host-test fake (hardware unavailable).
  static const fake = 'fake';

  /// Device-bound software KEK (HKDF over live HW factors → AES-GCM).
  ///
  /// Selected via board profile `secrets_backend: "software"` (or sim/emu
  /// heuristic when the field is omitted). No KEK/salt file on disk.
  static const softwareFallback = 'software_fallback';

  /// OP-TEE-backed seal (`secrets_backend: "optee"`).
  static const optee = 'optee';
}

/// Board-profile preference for which Secrets backend to construct.
///
/// JSON field: `secrets_backend` — `"software"` or `"optee"`.
abstract final class SecretsBackendPreference {
  /// Chip-id + salt HKDF software seal ([SecretsBackendId.softwareFallback]).
  static const software = 'software';

  /// OP-TEE seal helper ([SecretsBackendId.optee]).
  static const optee = 'optee';

  /// Normalize profile / helper values; returns null if unknown / empty.
  static String? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) {
      return null;
    }
    if (v == software ||
        v == 'software_fallback' ||
        v == SecretsBackendId.softwareFallback) {
      return software;
    }
    if (v == optee || v == SecretsBackendId.optee) {
      return optee;
    }
    return null;
  }
}
