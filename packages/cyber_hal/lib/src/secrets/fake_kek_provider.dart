import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/secrets/kek_provider.dart';
import 'package:cyber_hal/src/secrets/secrets_backends.dart';

/// In-memory fake for host unit tests (counts as hardware unavailable).
final class FakeKekProvider implements KekProvider {
  FakeKekProvider({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  final Map<String, _Entry> _store = {};

  @override
  String get backendId => SecretsBackendId.fake;

  @override
  bool get isHardwareBound => false;

  @override
  Future<Uint8List> seal({
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    final token = Uint8List(16);
    for (var i = 0; i < token.length; i++) {
      token[i] = _random.nextInt(256);
    }
    final key = base64Url.encode(token);
    _store[key] = _Entry(
      plaintext: Uint8List.fromList(plaintext),
      aad: Uint8List.fromList(aad),
    );
    // Opaque blob: magic + token (no plaintext).
    return Uint8List.fromList(<int>[
      0x46, 0x41, 0x4b, 0x45, // FAKE
      ...token,
    ]);
  }

  @override
  Future<Uint8List> unseal({
    required Uint8List blob,
    required Uint8List aad,
  }) async {
    if (blob.length < 20 ||
        blob[0] != 0x46 ||
        blob[1] != 0x41 ||
        blob[2] != 0x4b ||
        blob[3] != 0x45) {
      throw const HalIoException('fake unseal: invalid blob');
    }
    final token = blob.sublist(4, 20);
    final key = base64Url.encode(token);
    final entry = _store[key];
    if (entry == null) {
      throw const HalIoException('fake unseal: unknown blob');
    }
    if (!_bytesEqual(aad, entry.aad)) {
      throw const HalIoException('fake unseal: AAD mismatch');
    }
    return Uint8List.fromList(entry.plaintext);
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

final class _Entry {
  _Entry({required this.plaintext, required this.aad});

  final Uint8List plaintext;
  final Uint8List aad;
}
