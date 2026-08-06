import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/secrets/kek_provider.dart';

/// Purpose label bound into AAD for cloud Ed25519 private-key seals.
const cloudEd25519AadPurpose = 'cloud-ed25519-v1';

/// Canonical token-mint message prefix (api-server `device-ed25519-activate`).
const cloudEd25519TokenMessagePrefix = 'ed25519-token-v1';

/// Default on-device helpers for sealed cloud Ed25519 Vendor Storage blob (ID 22).
const kReadCloudEd25519SealedPath = '/usr/bin/read-cloud-ed25519-sealed';
const kWriteCloudEd25519SealedPath = '/usr/bin/write-cloud-ed25519-sealed';

/// Build AAD for a cloud Ed25519 private-key seal (`cloud-ed25519-v1\\0sn`).
Uint8List cloudEd25519AadForSn(String productSn) {
  final sn = productSn.trim();
  return Uint8List.fromList(utf8.encode('$cloudEd25519AadPurpose\x00$sn'));
}

/// Build the UTF-8 canonical message for `POST /v1/devices/:sn/token`.
Uint8List cloudEd25519TokenMessage({
  required String sn,
  required int tsUnixSeconds,
  required String nonce,
}) {
  final body = '$cloudEd25519TokenMessagePrefix\n'
      '${sn.trim()}\n'
      '$tsUnixSeconds\n'
      '$nonce';
  return Uint8List.fromList(utf8.encode(body));
}

/// Standard base64 of a raw 32-byte Ed25519 public key.
String encodeEd25519PublicKeyBase64(List<int> publicKeyBytes) {
  if (publicKeyBytes.length != 32) {
    throw HalIoException(
      'ed25519 public key must be 32 bytes, got ${publicKeyBytes.length}',
    );
  }
  return base64Encode(publicKeyBytes);
}

/// Opaque storage for the Secrets-sealed cloud Ed25519 private-key blob.
///
/// Default implementation shells to board helpers that read/write Vendor
/// Storage ID 22. Inject [CloudEd25519SealedStore.memory] for host tests.
abstract class CloudEd25519SealedStore {
  /// Returns sealed ciphertext, or `null` when absent / unsupported.
  Future<Uint8List?> readSealed();

  /// Persist sealed ciphertext. MUST NOT overwrite unless [force] is true.
  Future<void> writeSealed(Uint8List sealed, {bool force = false});

  /// True when a non-empty sealed blob is already present.
  Future<bool> isPresent();

  /// In-memory store for unit tests (no Vendor Storage).
  factory CloudEd25519SealedStore.memory() = _MemoryCloudEd25519SealedStore;
}

final class _MemoryCloudEd25519SealedStore implements CloudEd25519SealedStore {
  Uint8List? _blob;

  @override
  Future<bool> isPresent() async => _blob != null && _blob!.isNotEmpty;

  @override
  Future<Uint8List?> readSealed() async {
    final b = _blob;
    if (b == null || b.isEmpty) {
      return null;
    }
    return Uint8List.fromList(b);
  }

  @override
  Future<void> writeSealed(Uint8List sealed, {bool force = false}) async {
    if (sealed.isEmpty) {
      throw const HalIoException('cloud ed25519: refuse empty sealed blob');
    }
    if (!force && _blob != null && _blob!.isNotEmpty) {
      throw const HalIoException(
        'cloud ed25519: sealed blob already present',
        code: 'already_present',
      );
    }
    _blob = Uint8List.fromList(sealed);
  }
}

/// Vendor Storage-backed sealed blob via board helpers.
final class HelperCloudEd25519SealedStore implements CloudEd25519SealedStore {
  HelperCloudEd25519SealedStore({
    this.readHelperPath = kReadCloudEd25519SealedPath,
    this.writeHelperPath = kWriteCloudEd25519SealedPath,
  });

  final String readHelperPath;
  final String writeHelperPath;

  @override
  Future<bool> isPresent() async {
    try {
      final r = await Process.run(readHelperPath, const <String>['--present']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> readSealed() async {
    try {
      final r = await Process.run(
        readHelperPath,
        const <String>[],
        stdoutEncoding: null,
      );
      if (r.exitCode != 0) {
        return null;
      }
      final out = r.stdout;
      if (out is! List<int> || out.isEmpty) {
        return null;
      }
      return Uint8List.fromList(out);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeSealed(Uint8List sealed, {bool force = false}) async {
    if (sealed.isEmpty) {
      throw const HalIoException('cloud ed25519: refuse empty sealed blob');
    }
    final tmp = await File(
      '${Directory.systemTemp.path}/cloud-ed25519-$pid.bin',
    ).create();
    try {
      await tmp.writeAsBytes(sealed, flush: true);
      final args = <String>['-i', tmp.path];
      if (force) {
        args.add('--force');
      }
      final r = await Process.run(writeHelperPath, args);
      if (r.exitCode != 0) {
        final err = '${r.stderr}'.trim();
        final out = '${r.stdout}'.trim();
        throw HalIoException(
          'cloud ed25519 write failed (exit ${r.exitCode}): '
          '${err.isNotEmpty ? err : out}',
        );
      }
    } finally {
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}

/// In-memory Ed25519 key material for cloud identity (seed + raw public key).
final class CloudEd25519KeyMaterial {
  const CloudEd25519KeyMaterial({
    required this.privateKeySeed,
    required this.publicKeyBytes,
  });

  /// 32-byte Ed25519 private key seed.
  final Uint8List privateKeySeed;

  /// 32-byte raw Ed25519 public key.
  final Uint8List publicKeyBytes;

  String get publicKeyBase64 => encodeEd25519PublicKeyBase64(publicKeyBytes);
}

/// Generate / seal / load device cloud Ed25519 identity (no HTTP).
///
/// Lifecycle (crash-safe): generate → seal + write Vendor Storage → caller
/// POSTs activate. When a sealed blob already exists, never regenerate.
final class CloudEd25519Identity {
  CloudEd25519Identity({
    required KekProvider secrets,
    CloudEd25519SealedStore? store,
    Ed25519? algorithm,
  })  : _secrets = secrets,
        _store = store ?? HelperCloudEd25519SealedStore(),
        _ed25519 = algorithm ?? Ed25519();

  final KekProvider _secrets;
  final CloudEd25519SealedStore _store;
  final Ed25519 _ed25519;

  /// True when Vendor Storage (or injected store) already has a sealed blob.
  Future<bool> hasSealedBlob() => _store.isPresent();

  /// Generate a new Ed25519 keypair (does not persist).
  Future<CloudEd25519KeyMaterial> generateKeyPair() async {
    final pair = await _ed25519.newKeyPair();
    final seed = Uint8List.fromList(await pair.extractPrivateKeyBytes());
    final pub = await pair.extractPublicKey();
    final pubBytes = Uint8List.fromList(pub.bytes);
    if (seed.length != 32 || pubBytes.length != 32) {
      throw HalIoException(
        'ed25519 key sizes unexpected (seed=${seed.length}, pub=${pubBytes.length})',
      );
    }
    return CloudEd25519KeyMaterial(
      privateKeySeed: seed,
      publicKeyBytes: pubBytes,
    );
  }

  /// Seal [material] private seed and write to store. Refuses overwrite.
  Future<void> sealAndPersist({
    required CloudEd25519KeyMaterial material,
    required String productSn,
  }) async {
    final sn = productSn.trim();
    if (sn.isEmpty) {
      throw const HalIoException('cloud ed25519: empty product SN');
    }
    if (await _store.isPresent()) {
      throw const HalIoException(
        'cloud ed25519: sealed blob already present — refuse regenerate',
        code: 'already_present',
      );
    }
    final aad = cloudEd25519AadForSn(sn);
    final sealed = await _secrets.seal(
      plaintext: material.privateKeySeed,
      aad: aad,
    );
    await _store.writeSealed(sealed);
  }

  /// Load and unseal existing identity for [productSn] (AAD must match seal).
  Future<CloudEd25519KeyMaterial?> loadUnsealed(String productSn) async {
    final sn = productSn.trim();
    if (sn.isEmpty) {
      return null;
    }
    final sealed = await _store.readSealed();
    if (sealed == null || sealed.isEmpty) {
      return null;
    }
    final seed = await _secrets.unseal(
      blob: sealed,
      aad: cloudEd25519AadForSn(sn),
    );
    if (seed.length != 32) {
      throw HalIoException(
        'cloud ed25519: unsealed seed length ${seed.length} != 32',
      );
    }
    final pair = await _ed25519.newKeyPairFromSeed(seed);
    final pub = await pair.extractPublicKey();
    return CloudEd25519KeyMaterial(
      privateKeySeed: Uint8List.fromList(seed),
      publicKeyBytes: Uint8List.fromList(pub.bytes),
    );
  }

  /// Ensure a sealed identity exists: load if present, else generate+seal+write.
  ///
  /// Does **not** call activate. Empty [productSn] → null (no generate).
  Future<CloudEd25519KeyMaterial?> ensureLocalKey({
    required String productSn,
  }) async {
    final sn = productSn.trim();
    if (sn.isEmpty) {
      return null;
    }
    final existing = await loadUnsealed(sn);
    if (existing != null) {
      return existing;
    }
    final generated = await generateKeyPair();
    await sealAndPersist(material: generated, productSn: sn);
    return generated;
  }

  /// Sign the token-mint canonical message with the given private seed.
  Future<Uint8List> signTokenMessage({
    required Uint8List privateKeySeed,
    required String sn,
    required int tsUnixSeconds,
    required String nonce,
  }) async {
    if (privateKeySeed.length != 32) {
      throw HalIoException(
        'cloud ed25519: seed length ${privateKeySeed.length} != 32',
      );
    }
    final pair = await _ed25519.newKeyPairFromSeed(privateKeySeed);
    final sig = await _ed25519.sign(
      cloudEd25519TokenMessage(
        sn: sn,
        tsUnixSeconds: tsUnixSeconds,
        nonce: nonce,
      ),
      keyPair: pair,
    );
    return Uint8List.fromList(sig.bytes);
  }
}
