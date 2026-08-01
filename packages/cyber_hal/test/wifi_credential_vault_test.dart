import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_hal/network/wifi_session.dart';
import 'package:cyber_hal/secrets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WifiVaultDocument', () {
    test('encode/decode round-trip', () {
      final blob = Uint8List.fromList(List<int>.generate(24, (i) => i + 1));
      final doc = WifiVaultDocument(
        entries: {'Home': blob, 'Office': Uint8List.fromList([9, 8, 7])},
      );
      final decoded = WifiVaultDocument.decode(doc.encode());
      expect(decoded.version, wifiVaultFormatVersion);
      expect(decoded.entries.keys, unorderedEquals(['Home', 'Office']));
      expect(decoded.entries['Home'], blob);
      expect(decoded.entries['Office'], Uint8List.fromList([9, 8, 7]));
    });

    test('empty bytes decode to empty document', () {
      final doc = WifiVaultDocument.decode(Uint8List(0));
      expect(doc.entries, isEmpty);
      expect(doc.version, wifiVaultFormatVersion);
    });

    test('rejects unsupported version', () {
      final raw = utf8.encode(jsonEncode({
        'v': 99,
        'entries': <String, String>{},
      }));
      expect(
        () => WifiVaultDocument.decode(Uint8List.fromList(raw)),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('wifiVaultAadForSsid', () {
    test('binds purpose wifi-psk and ssid', () {
      final aad = wifiVaultAadForSsid('Home');
      expect(utf8.decode(aad), 'wifi-psk\x00Home');
    });
  });

  group('WifiCredentialVault', () {
    late Directory tmp;
    late FakeKekProvider kek;
    late WifiCredentialVault vault;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('wifi-vault-');
      kek = FakeKekProvider();
      vault = WifiCredentialVault(
        secrets: kek,
        path: '${tmp.path}/credentials.vault',
      );
    });

    tearDown(() {
      if (tmp.existsSync()) {
        tmp.deleteSync(recursive: true);
      }
    });

    test('put/get/delete round-trip via Secrets fake', () async {
      await vault.put('Home', 'secret-pass');
      expect(await vault.contains('Home'), isTrue);
      expect(await vault.get('Home'), 'secret-pass');
      expect(await vault.listSsids(), {'Home'});

      // On-disk file must not contain plaintext PSK.
      final disk = File(vault.path).readAsStringSync();
      expect(disk.contains('secret-pass'), isFalse);
      expect(disk.contains('"v":1') || disk.contains('"v": 1'), isTrue);

      await vault.delete('Home');
      expect(await vault.contains('Home'), isFalse);
      expect(await vault.get('Home'), isNull);
    });

    test('put replaces prior entry for same SSID', () async {
      await vault.put('Home', 'old');
      await vault.put('Home', 'new');
      expect(await vault.get('Home'), 'new');
    });

    test('uses abstract KekProvider (fake backend id)', () async {
      await vault.put('A', 'x');
      expect(vault.secretsBackendId, SecretsBackendId.fake);
    });
  });

  group('WpaConfPskMigration', () {
    const sample = '''
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=root
update_config=1
country=CN

network={
	ssid="Home"
	psk="hunter2"
	key_mgmt=WPA-PSK
}

network={
	ssid="OpenCafe"
	key_mgmt=NONE
}

network={
	ssid="Office"
	psk=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
}
''';

    test('extractPlaintextPsks finds Home and Office', () {
      final entries = WpaConfPskMigration.extractPlaintextPsks(sample);
      expect(entries.map((e) => e.ssid), unorderedEquals(['Home', 'Office']));
      expect(
        entries.firstWhere((e) => e.ssid == 'Home').psk,
        'hunter2',
      );
      expect(WpaConfPskMigration.hasPlaintextPsk(sample), isTrue);
    });

    test('scrubPlaintextPsks removes psk= and adds mem_only_psk', () {
      final scrubbed = WpaConfPskMigration.scrubPlaintextPsks(sample);
      // Avoid naive contains('psk=') — that also matches mem_only_psk=.
      expect(WpaConfPskMigration.extractPlaintextPsks(scrubbed), isEmpty);
      expect(scrubbed.contains('hunter2'), isFalse);
      expect(scrubbed.contains('ssid="Home"'), isTrue);
      expect(scrubbed.contains('ssid="Office"'), isTrue);
      expect(scrubbed.contains('ssid="OpenCafe"'), isTrue);
      expect(scrubbed.contains('mem_only_psk=1'), isTrue);
      expect(WpaConfPskMigration.hasPlaintextPsk(scrubbed), isFalse);
    });

    test('migrateFile imports into vault and rewrites conf', () async {
      final tmp = Directory.systemTemp.createTempSync('wifi-mig-');
      addTearDown(() {
        if (tmp.existsSync()) {
          tmp.deleteSync(recursive: true);
        }
      });
      final confPath = '${tmp.path}/wpa_supplicant.conf';
      await File(confPath).writeAsString(sample);
      final vault = WifiCredentialVault(
        secrets: FakeKekProvider(),
        path: '${tmp.path}/credentials.vault',
      );

      final n = await WpaConfPskMigration.migrateFile(
        confPath: confPath,
        vault: vault,
      );
      expect(n, 2);
      expect(await vault.get('Home'), 'hunter2');
      expect(await vault.contains('Office'), isTrue);

      final after = await File(confPath).readAsString();
      expect(WpaConfPskMigration.hasPlaintextPsk(after), isFalse);
      expect(after.contains('hunter2'), isFalse);

      // Idempotent second pass.
      final n2 = await WpaConfPskMigration.migrateFile(
        confPath: confPath,
        vault: vault,
      );
      expect(n2, 0);
    });
  });
}
