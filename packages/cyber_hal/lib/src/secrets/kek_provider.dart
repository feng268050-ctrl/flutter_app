import 'dart:typed_data';

/// Abstract Secrets / KEK provider: seal plaintext with AAD into an opaque blob.
///
/// Callers MUST depend on this type, not a concrete OP-TEE or software backend.
/// Implementations MUST NOT write key material or unsealed plaintext to
/// info-level logs.
abstract class KekProvider {
  /// Backend id for diagnostics (e.g. [SecretsBackendId.optee]).
  String get backendId;

  /// True when seal/unseal is bound to platform TEE / HUK (OP-TEE).
  bool get isHardwareBound;

  /// Seal [plaintext] with associated data [aad] → opaque blob.
  Future<Uint8List> seal({
    required Uint8List plaintext,
    required Uint8List aad,
  });

  /// Unseal [blob] with the same [aad] used at seal time.
  ///
  /// Wrong AAD MUST fail closed (throw) and MUST NOT return plaintext.
  Future<Uint8List> unseal({
    required Uint8List blob,
    required Uint8List aad,
  });
}
