import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/secrets/device_binding_material.dart';
import 'package:cyber_hal/src/secrets/kek_provider.dart';
import 'package:cyber_hal/src/secrets/secrets_backends.dart';
import 'package:cyber_hal/src/sys_info/sys_info.dart';
import 'package:cryptography/cryptography.dart';

/// Device-bound software KEK: HKDF over live hardware factors → AES-256-GCM.
///
/// **No KEK or salt is written to disk.** Factors are collected at runtime
/// (chip id + eth/wlan MAC and/or eMMC CID / DT serial). Ciphertext alone
/// cannot be unsealed on another board. Root on the *same* device can still
/// re-read the same sysfs/DT values and derive the KEK.
final class SoftwareFallbackKekProvider implements KekProvider {
  SoftwareFallbackKekProvider({
    DeviceBindingMaterialReader? materialReader,
    DeviceBindingMaterialCollector? collector,
    DeviceSnReader? deviceSnReader,
    /// Test helper: chip id only (pairs with a synthetic eth MAC).
    ChipIdReader? chipIdReader,
    Random? random,
  })  : _materialReader = materialReader ??
            (chipIdReader != null
                ? () async {
                    final chip = (await chipIdReader()).trim();
                    return DeviceBindingMaterial(
                      chipId: chip,
                      ethMac: '02:00:00:00:00:01',
                    );
                  }
                : (collector ??
                        DeviceBindingMaterialCollector(
                          deviceSnReader:
                              deviceSnReader ?? const DeviceSnReader(),
                        ))
                    .collect),
        _random = random ?? Random.secure();

  final DeviceBindingMaterialReader _materialReader;
  final Random _random;

  static const _magic = [0x4c, 0x57, 0x53, 0x53]; // LWSS
  static const _version = 3;
  static const _nonceLen = 12;
  /// Public HKDF salt (domain separation only — not a secret).
  static const _hkdfSalt = 'lws-hmi-software-kek-v3';
  static const _hkdfInfo = 'lws-hmi-secrets-v3';

  final _aes = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Uint8List? _cachedKek;

  @override
  String get backendId => SecretsBackendId.softwareFallback;

  @override
  bool get isHardwareBound => false;

  Future<Uint8List> _masterKek() async {
    final cached = _cachedKek;
    if (cached != null) {
      return cached;
    }
    final material = await _materialReader();
    DeviceBindingMaterialCollector.validate(material);
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(material.canonicalIkm)),
      nonce: utf8.encode(_hkdfSalt),
      info: utf8.encode(_hkdfInfo),
    );
    final bytes = Uint8List.fromList(await derived.extractBytes());
    _cachedKek = bytes;
    return bytes;
  }

  @override
  Future<Uint8List> seal({
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    final kek = await _masterKek();
    final nonce = Uint8List(_nonceLen);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = _random.nextInt(256);
    }
    final box = await _aes.encrypt(
      plaintext,
      secretKey: SecretKey(kek),
      nonce: nonce,
      aad: aad,
    );
    final backend = utf8.encode(SecretsBackendId.softwareFallback);
    if (backend.length > 255) {
      throw const HalIoException('software seal: backend id too long');
    }
    return Uint8List.fromList(<int>[
      ..._magic,
      _version,
      backend.length,
      ...backend,
      ...nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  @override
  Future<Uint8List> unseal({
    required Uint8List blob,
    required Uint8List aad,
  }) async {
    if (blob.length < 4 + 1 + 1 + _nonceLen + 16) {
      throw const HalIoException('software unseal: blob too short');
    }
    for (var i = 0; i < 4; i++) {
      if (blob[i] != _magic[i]) {
        throw const HalIoException('software unseal: bad magic');
      }
    }
    final version = blob[4];
    if (version != _version) {
      throw HalIoException('software unseal: unsupported version $version');
    }
    final idLen = blob[5];
    var off = 6;
    if (blob.length < off + idLen + _nonceLen + 16) {
      throw const HalIoException('software unseal: truncated');
    }
    final id = utf8.decode(blob.sublist(off, off + idLen));
    off += idLen;
    if (id != SecretsBackendId.softwareFallback) {
      throw HalIoException('software unseal: unexpected backend id $id');
    }
    final nonce = blob.sublist(off, off + _nonceLen);
    off += _nonceLen;
    final body = blob.sublist(off);
    if (body.length < 16) {
      throw const HalIoException('software unseal: missing mac');
    }
    final cipherText = body.sublist(0, body.length - 16);
    final macBytes = body.sublist(body.length - 16);
    final kek = await _masterKek();
    try {
      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: SecretKey(kek),
        aad: aad,
      );
      return Uint8List.fromList(clear);
    } catch (e) {
      throw HalIoException(
        'software unseal failed (AAD, binding, or corrupt blob)',
        cause: e,
      );
    }
  }
}
