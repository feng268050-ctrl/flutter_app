import 'package:cyber_hal/src/secrets/kek_provider.dart';

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

/// OS Settings Operating System → Security **Secrets Seal** labels (`software` | `op-tee`).
///
/// Read-only mapping from [KekProvider.backendId] / [SecretsBackendId] — does
/// not seal, unseal, or migrate backends.
abstract final class SecretsSealStatus {
  static const software = 'software';
  static const opTee = 'op-tee';

  /// Map a [KekProvider.backendId] (or preference string) to a UI label.
  ///
  /// - [SecretsBackendId.optee] → [opTee]
  /// - [SecretsBackendId.softwareFallback] / [SecretsBackendId.fake] → [software]
  static String fromBackendId(String backendId) {
    final v = backendId.trim().toLowerCase();
    if (v == SecretsBackendId.optee ||
        v == SecretsBackendPreference.optee ||
        v == 'op-tee' ||
        v == 'optee') {
      return opTee;
    }
    return software;
  }

  /// Convenience: [fromBackendId] of [provider.backendId] (no I/O).
  static String fromProvider(KekProvider provider) =>
      fromBackendId(provider.backendId);
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
