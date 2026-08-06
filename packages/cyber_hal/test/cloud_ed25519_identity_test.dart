import 'dart:convert';
import 'dart:typed_data';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/secrets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cloudEd25519AadForSn', () {
    test('binds purpose and product SN', () {
      final aad = cloudEd25519AadForSn('ABC123');
      expect(utf8.decode(aad), 'cloud-ed25519-v1\x00ABC123');
    });
  });

  group('cloudEd25519TokenMessage', () {
    test('canonical form matches api-server contract', () {
      final msg = cloudEd25519TokenMessage(
        sn: 'SN1',
        tsUnixSeconds: 1700000000,
        nonce: 'abc',
      );
      expect(utf8.decode(msg), 'ed25519-token-v1\nSN1\n1700000000\nabc');
    });
  });

  group('CloudEd25519Identity', () {
    late FakeKekProvider kek;
    late CloudEd25519SealedStore store;
    late CloudEd25519Identity identity;

    setUp(() {
      kek = FakeKekProvider();
      store = CloudEd25519SealedStore.memory();
      identity = CloudEd25519Identity(secrets: kek, store: store);
    });

    test('seal round-trip with matching AAD', () async {
      final material = await identity.generateKeyPair();
      expect(material.publicKeyBytes.length, 32);
      expect(material.privateKeySeed.length, 32);
      expect(material.publicKeyBase64, isNotEmpty);

      await identity.sealAndPersist(material: material, productSn: 'UNIT1');
      expect(await identity.hasSealedBlob(), isTrue);

      final loaded = await identity.loadUnsealed('UNIT1');
      expect(loaded, isNotNull);
      expect(loaded!.privateKeySeed, material.privateKeySeed);
      expect(loaded.publicKeyBytes, material.publicKeyBytes);
    });

    test('wrong SN AAD fails closed', () async {
      final material = await identity.generateKeyPair();
      await identity.sealAndPersist(material: material, productSn: 'UNIT1');
      await expectLater(
        identity.loadUnsealed('OTHER'),
        throwsA(isA<HalIoException>()),
      );
    });

    test('does not regenerate when sealed blob present', () async {
      final first = await identity.ensureLocalKey(productSn: 'UNIT1');
      expect(first, isNotNull);
      final second = await identity.ensureLocalKey(productSn: 'UNIT1');
      expect(second!.publicKeyBytes, first!.publicKeyBytes);
      expect(second.privateKeySeed, first.privateKeySeed);

      final other = await identity.generateKeyPair();
      await expectLater(
        identity.sealAndPersist(material: other, productSn: 'UNIT1'),
        throwsA(
          isA<HalIoException>().having(
            (e) => e.code,
            'code',
            'already_present',
          ),
        ),
      );
    });

    test('empty SN skips generate', () async {
      expect(await identity.ensureLocalKey(productSn: ''), isNull);
      expect(await identity.hasSealedBlob(), isFalse);
    });

    test('sign token message is 64 bytes', () async {
      final material = await identity.generateKeyPair();
      final sig = await identity.signTokenMessage(
        privateKeySeed: material.privateKeySeed,
        sn: 'UNIT1',
        tsUnixSeconds: 1700000000,
        nonce: 'n1',
      );
      expect(sig.length, 64);
    });

    test('encodeEd25519PublicKeyBase64 rejects non-32', () {
      expect(
        () => encodeEd25519PublicKeyBase64(Uint8List(31)),
        throwsA(isA<HalIoException>()),
      );
    });
  });
}
