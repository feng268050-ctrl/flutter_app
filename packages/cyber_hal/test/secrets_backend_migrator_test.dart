import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/network/wifi_session.dart';
import 'package:cyber_hal/secrets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SealedBlobMagic', () {
    test('detects LWSS / LWS1', () {
      expect(
        SealedBlobMagic.isSoftware(
          Uint8List.fromList([0x4c, 0x57, 0x53, 0x53, 1]),
        ),
        isTrue,
      );
      expect(
        SealedBlobMagic.isOptee(
          Uint8List.fromList([0x4c, 0x57, 0x53, 0x31, 1]),
        ),
        isTrue,
      );
      expect(
        SealedBlobMagic.isSoftware(
          Uint8List.fromList([0x4c, 0x57, 0x53, 0x31]),
        ),
        isFalse,
      );
    });
  });

  group('SecretsBackendMigrator', () {
    late Directory tmp;
    late SoftwareFallbackKekProvider soft;
    late _Lws1KekProvider tee;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('secrets-migrate-');
      soft = SoftwareFallbackKekProvider(
        materialReader: () async => const DeviceBindingMaterial(
          chipId: 'MIGRATE-CHIP',
          ethMac: '02:00:00:00:00:99',
          mmcCid: 'cid-migrate',
        ),
      );
      tee = _Lws1KekProvider();
    });

    tearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    test('wifi vault software → optee round-trip', () async {
      final vaultPath = '${tmp.path}/credentials.vault';
      final softVault = WifiCredentialVault(secrets: soft, path: vaultPath);
      await softVault.put('Net-A', 'psk-aaa');
      await softVault.put('Net-B', 'psk-bbb');

      final store = CloudEd25519SealedStore.memory();
      final migrator = SecretsBackendMigrator(
        source: soft,
        target: tee,
        wifiVaultPath: vaultPath,
        cloudStore: store,
      );
      final report = await migrator.migrate(
        wifi: true,
        cloud: false,
      );
      expect(report.wifiMigrated, 2);
      expect(report.wifiSkipped, 0);
      expect(report.wifiFailed, 0);
      expect(report.ok, isTrue);

      final teeVault = WifiCredentialVault(secrets: tee, path: vaultPath);
      expect(await teeVault.get('Net-A'), 'psk-aaa');
      expect(await teeVault.get('Net-B'), 'psk-bbb');

      final doc = WifiVaultDocument.decode(
        await File(vaultPath).readAsBytes(),
      );
      for (final blob in doc.entries.values) {
        expect(SealedBlobMagic.isOptee(blob), isTrue);
      }

      // Idempotent second pass.
      final again = await migrator.migrateWifiVault();
      expect(again.wifiMigrated, 0);
      expect(again.wifiSkipped, 2);
    });

    test('cloud ed25519 software → optee with force write', () async {
      const sn = 'SN-MIGRATE-001';
      final store = CloudEd25519SealedStore.memory();
      final softId = CloudEd25519Identity(secrets: soft, store: store);
      final material = await softId.generateKeyPair();
      await softId.sealAndPersist(material: material, productSn: sn);

      final before = await store.readSealed();
      expect(before, isNotNull);
      expect(SealedBlobMagic.isSoftware(before!), isTrue);

      final migrator = SecretsBackendMigrator(
        source: soft,
        target: tee,
        wifiVaultPath: '${tmp.path}/no-vault',
        cloudStore: store,
      );
      final report = await migrator.migrateCloudEd25519(productSn: sn);
      expect(report.cloudMigrated, isTrue);
      expect(report.cloudError, isNull);

      final after = await store.readSealed();
      expect(after, isNotNull);
      expect(SealedBlobMagic.isOptee(after!), isTrue);

      final teeId = CloudEd25519Identity(secrets: tee, store: store);
      final loaded = await teeId.loadUnsealed(sn);
      expect(loaded, isNotNull);
      expect(loaded!.privateKeySeed, material.privateKeySeed);
      expect(loaded.publicKeyBytes, material.publicKeyBytes);

      final skip = await migrator.migrateCloudEd25519(productSn: sn);
      expect(skip.cloudSkipped, isTrue);
    });

    test('cloud absent is not an error', () async {
      final migrator = SecretsBackendMigrator(
        source: soft,
        target: tee,
        wifiVaultPath: '${tmp.path}/no-vault',
        cloudStore: CloudEd25519SealedStore.memory(),
      );
      final report = await migrator.migrateCloudEd25519(productSn: 'ANY');
      expect(report.cloudAbsent, isTrue);
      expect(report.cloudError, isNull);
    });
  });
}

/// Minimal OP-TEE-shaped KEK for host tests (`LWS1` magic + XOR toy cipher).
final class _Lws1KekProvider implements KekProvider {
  final Map<String, Uint8List> _plain = {};

  @override
  String get backendId => SecretsBackendId.optee;

  @override
  bool get isHardwareBound => true;

  @override
  Future<Uint8List> seal({
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    final token = base64Url.encode(aad);
    _plain[token] = Uint8List.fromList(plaintext);
    return Uint8List.fromList(<int>[
      ...SealedBlobMagic.optee,
      1,
      ...utf8.encode(token),
    ]);
  }

  @override
  Future<Uint8List> unseal({
    required Uint8List blob,
    required Uint8List aad,
  }) async {
    if (!SealedBlobMagic.isOptee(blob) || blob.length < 5) {
      throw HalIoException('lws1 test unseal: bad magic');
    }
    final token = utf8.decode(blob.sublist(5));
    final expected = base64Url.encode(aad);
    if (token != expected) {
      throw HalIoException('lws1 test unseal: AAD mismatch');
    }
    final p = _plain[token];
    if (p == null) {
      throw HalIoException('lws1 test unseal: unknown');
    }
    return Uint8List.fromList(p);
  }
}
