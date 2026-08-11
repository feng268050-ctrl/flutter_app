import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/secrets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boardsRoot = Directory.current.path.endsWith('cyber_hal')
      ? 'boards'
      : 'packages/cyber_hal/boards';

  final appHalRoot = Directory.current.path.endsWith('cyber_hal')
      ? '../../app/lws_hmi/assets/hal'
      : 'app/lws_hmi/assets/hal';

  final oemYnh960 = Directory.current.path.endsWith('cyber_hal')
      ? '../../oem/boards/ynh960/board_profile.json'
      : 'oem/boards/ynh960/board_profile.json';

  group('FakeKekProvider', () {
    test('seal then unseal round-trip', () async {
      final p = FakeKekProvider();
      final plain = Uint8List.fromList(utf8.encode('psk-secret'));
      final aad = Uint8List.fromList(utf8.encode('wifi-psk\x00ssid'));
      final blob = await p.seal(plaintext: plain, aad: aad);
      final out = await p.unseal(blob: blob, aad: aad);
      expect(out, plain);
      expect(p.backendId, SecretsBackendId.fake);
      expect(p.isHardwareBound, isFalse);
    });

    test('wrong AAD fails closed', () async {
      final p = FakeKekProvider();
      final plain = Uint8List.fromList(utf8.encode('x'));
      final aad = Uint8List.fromList(utf8.encode('aad-a'));
      final blob = await p.seal(plaintext: plain, aad: aad);
      expect(
        () => p.unseal(
          blob: blob,
          aad: Uint8List.fromList(utf8.encode('aad-b')),
        ),
        throwsA(isA<HalIoException>()),
      );
    });
  });

  group('SoftwareFallbackKekProvider', () {
    SoftwareFallbackKekProvider provider({
      String chipId = 'CHIP-TEST-001',
      String ethMac = 'aa:bb:cc:dd:ee:01',
      String mmcCid = '',
    }) {
      return SoftwareFallbackKekProvider(
        materialReader: () async => DeviceBindingMaterial(
          chipId: chipId,
          ethMac: ethMac,
          mmcCid: mmcCid,
        ),
      );
    }

    test('seal then unseal round-trip (no disk state)', () async {
      final p = provider();
      final plain = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final aad = Uint8List.fromList(utf8.encode('purpose=wifi'));
      final blob = await p.seal(plaintext: plain, aad: aad);
      final out = await p.unseal(blob: blob, aad: aad);
      expect(out, plain);
      expect(p.backendId, SecretsBackendId.softwareFallback);
      expect(p.isHardwareBound, isFalse);
    });

    test('wrong AAD fails closed', () async {
      final p = provider();
      final plain = Uint8List.fromList(utf8.encode('secret'));
      final blob = await p.seal(
        plaintext: plain,
        aad: Uint8List.fromList(utf8.encode('A')),
      );
      expect(
        () => p.unseal(
          blob: blob,
          aad: Uint8List.fromList(utf8.encode('B')),
        ),
        throwsA(isA<HalIoException>()),
      );
    });

    test('different chip id cannot unseal', () async {
      final a = provider(chipId: 'CHIP-A');
      final plain = Uint8List.fromList(utf8.encode('bound'));
      final aad = Uint8List.fromList(utf8.encode('aad'));
      final blob = await a.seal(plaintext: plain, aad: aad);

      final b = provider(chipId: 'CHIP-B');
      expect(
        () => b.unseal(blob: blob, aad: aad),
        throwsA(isA<HalIoException>()),
      );
    });

    test('different eth MAC cannot unseal', () async {
      final a = provider(ethMac: 'aa:bb:cc:dd:ee:01');
      final plain = Uint8List.fromList(utf8.encode('bound'));
      final aad = Uint8List.fromList(utf8.encode('aad'));
      final blob = await a.seal(plaintext: plain, aad: aad);
      final b = provider(ethMac: 'aa:bb:cc:dd:ee:02');
      expect(
        () => b.unseal(blob: blob, aad: aad),
        throwsA(isA<HalIoException>()),
      );
    });

    test('chip-only material fails closed', () async {
      final p = SoftwareFallbackKekProvider(
        materialReader: () async =>
            const DeviceBindingMaterial(chipId: 'CHIP-ONLY'),
      );
      expect(
        () => p.seal(
          plaintext: Uint8List.fromList(utf8.encode('x')),
          aad: Uint8List(0),
        ),
        throwsA(isA<HalIoException>()),
      );
    });

    test('canonical IKM is stable and ordered', () {
      const m = DeviceBindingMaterial(
        chipId: 'AbC',
        ethMac: 'AA:BB:CC:DD:EE:FF',
        mmcCid: 'CID123',
      );
      expect(
        m.canonicalIkm,
        'v3\nchip=abc\neth=aa:bb:cc:dd:ee:ff\nmmc=cid123\n',
      );
      expect(m.distinctFactorCount, 3);
    });
  });

  group('BoardBindings.secrets', () {
    test('sim profile selects software', () {
      final json = File('$boardsRoot/sim.json').readAsStringSync();
      final profile = BoardProfile.fromJsonString(json);
      expect(profile.secretsBackend, 'software');
      final bindings = BoardBindings(profile);
      final s = bindings.secrets(
        materialReader: () async => const DeviceBindingMaterial(
          chipId: 'SIM-CHIP',
          ethMac: '02:00:00:00:00:01',
        ),
      );
      expect(s, isA<SoftwareFallbackKekProvider>());
      expect(s.backendId, SecretsBackendId.softwareFallback);
      expect(s.isHardwareBound, isFalse);
      expect(
        bindings.secretsSealStatus(
          materialReader: () async => const DeviceBindingMaterial(
            chipId: 'SIM-CHIP',
            ethMac: '02:00:00:00:00:01',
          ),
        ),
        SecretsSealStatus.software,
      );
    });

    test('portable-smoke selects software', () {
      final json = File('$boardsRoot/portable-smoke.json').readAsStringSync();
      final profile = BoardProfile.fromJsonString(json);
      final s = BoardBindings(profile).secrets(
        chipIdReader: () async => 'SMOKE-CHIP',
      );
      expect(s, isA<SoftwareFallbackKekProvider>());
    });

    test('ynh960 OEM defaults to optee via secrets_backend', () async {
      final profile = await BoardProfile.loadFile(oemYnh960);
      expect(profile.secretsBackend, 'optee');
      expect(
        BoardBindings.resolveSecretsBackend(profile),
        SecretsBackendPreference.optee,
      );
      final s = BoardBindings(profile).secrets(
        materialReader: () async => const DeviceBindingMaterial(
          chipId: 'YNH-CHIP',
          ethMac: '02:00:00:00:00:02',
          mmcCid: 'emmc-cid',
        ),
      );
      expect(s, isA<OpteeKekProvider>());
      expect(s.isHardwareBound, isTrue);
    });

    test('ynh960 app asset selects optee', () {
      final json = File('$appHalRoot/board_profile.json').readAsStringSync();
      final profile = BoardProfile.fromJsonString(json);
      expect(profile.info.boardId, 'ynh960');
      expect(profile.secretsBackend, 'optee');
      final s = BoardBindings(profile).secrets(
        chipIdReader: () async => 'ASSET-CHIP',
      );
      expect(s, isA<OpteeKekProvider>());
    });

    test('explicit secrets_backend optee selects OP-TEE', () {
      final profile = BoardProfile.fromJsonString('''
{
  "board_id": "ynh960",
  "secrets_backend": "optee",
  "capabilities": [],
  "net_roles": {}
}
''');
      expect(
        BoardBindings.resolveSecretsBackend(profile),
        SecretsBackendPreference.optee,
      );
      final bindings = BoardBindings(profile);
      final s = bindings.secrets();
      expect(s, isA<OpteeKekProvider>());
      expect(s.backendId, SecretsBackendId.optee);
      expect(s.isHardwareBound, isTrue);
      expect(bindings.secretsSealStatus(), SecretsSealStatus.opTee);
    });

    test('optee profile with mocked helper round-trips', () async {
      final profile = BoardProfile.fromJsonString('''
{
  "board_id": "ynh960",
  "secrets_backend": "optee",
  "capabilities": [],
  "net_roles": {}
}
''');
      final store = <String, Uint8List>{};
      Future<ProcessResult> runner(List<String> cmd, String? stdin) async {
        final op = cmd.last;
        if (op == 'probe') {
          return ProcessResult(0, 0, 'ok\n', '');
        }
        final map = jsonDecode(stdin!) as Map<String, dynamic>;
        if (op == 'seal') {
          final plain = base64Decode(map['plaintext_b64'] as String);
          final aad = base64Decode(map['aad_b64'] as String);
          final token = base64Encode(aad);
          store[token] = Uint8List.fromList(plain);
          return ProcessResult(0, 0, '${base64Encode(utf8.encode(token))}\n', '');
        }
        if (op == 'unseal') {
          final blob = utf8.decode(base64Decode(map['blob_b64'] as String));
          final aad = base64Decode(map['aad_b64'] as String);
          final token = base64Encode(aad);
          if (blob != token || !store.containsKey(token)) {
            return ProcessResult(0, 1, '', 'aad mismatch');
          }
          return ProcessResult(
            0,
            0,
            '${base64Encode(store[token]!)}\n',
            '',
          );
        }
        return ProcessResult(0, 2, '', 'bad op');
      }

      final s = BoardBindings(profile).secrets(opteeRunner: runner);
      expect(s, isA<OpteeKekProvider>());
      final plain = Uint8List.fromList(utf8.encode('device-psk'));
      final aad = Uint8List.fromList(utf8.encode('wifi'));
      final blob = await s.seal(plaintext: plain, aad: aad);
      final out = await s.unseal(blob: blob, aad: aad);
      expect(out, plain);
    });

    test('override injects fake on hardware profile', () {
      final json = File('$appHalRoot/board_profile.json').readAsStringSync();
      final profile = BoardProfile.fromJsonString(json);
      final s = BoardBindings(profile).secrets(override: FakeKekProvider());
      expect(s, isA<FakeKekProvider>());
    });
  });
}
