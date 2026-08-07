import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/network/wifi_credential_vault.dart';
import 'package:cyber_hal/src/secrets/cloud_ed25519_identity.dart';
import 'package:cyber_hal/src/secrets/kek_provider.dart';
import 'package:cyber_hal/src/secrets/optee_kek_provider.dart';

/// Opaque blob magic: software KEK (`LWSS`) vs OP-TEE TA (`LWS1`).
abstract final class SealedBlobMagic {
  /// `LWSS` — [SoftwareFallbackKekProvider].
  static const software = [0x4c, 0x57, 0x53, 0x53];

  /// `LWS1` — native seal TA.
  static const optee = [0x4c, 0x57, 0x53, 0x31];

  static bool isSoftware(Uint8List blob) => _matches(blob, software);

  static bool isOptee(Uint8List blob) => _matches(blob, optee);

  static bool _matches(Uint8List blob, List<int> magic) {
    if (blob.length < magic.length) {
      return false;
    }
    for (var i = 0; i < magic.length; i++) {
      if (blob[i] != magic[i]) {
        return false;
      }
    }
    return true;
  }
}

/// Counts / errors from one software → OP-TEE re-seal pass.
final class SecretsBackendMigrationReport {
  const SecretsBackendMigrationReport({
    this.wifiMigrated = 0,
    this.wifiSkipped = 0,
    this.wifiFailed = 0,
    this.wifiErrors = const {},
    this.cloudMigrated = false,
    this.cloudSkipped = false,
    this.cloudAbsent = false,
    this.cloudError,
  });

  final int wifiMigrated;
  final int wifiSkipped;
  final int wifiFailed;

  /// SSID → error message for failed Wi‑Fi entries.
  final Map<String, String> wifiErrors;

  final bool cloudMigrated;
  final bool cloudSkipped;

  /// No Vendor Storage blob present.
  final bool cloudAbsent;
  final String? cloudError;

  bool get ok => wifiFailed == 0 && cloudError == null;

  @override
  String toString() {
    final wifi =
        'wifi migrated=$wifiMigrated skipped=$wifiSkipped failed=$wifiFailed';
    final cloud = cloudError != null
        ? 'cloud error=$cloudError'
        : cloudMigrated
            ? 'cloud migrated'
            : cloudSkipped
                ? 'cloud skipped'
                : cloudAbsent
                    ? 'cloud absent'
                    : 'cloud untouched';
    return 'SecretsBackendMigrationReport($wifi; $cloud)';
  }
}

/// One-shot re-seal: unseal with [source] (software), seal with [target] (OP-TEE).
///
/// Skips blobs that already look like OP-TEE (`LWS1`). Fail-closed per entry —
/// does not wipe a vault entry when unseal/seal fails.
final class SecretsBackendMigrator {
  SecretsBackendMigrator({
    required KekProvider source,
    required KekProvider target,
    this.wifiVaultPath = wifiCredentialVaultDefaultPath,
    CloudEd25519SealedStore? cloudStore,
  })  : _source = source,
        _target = target,
        _cloudStore = cloudStore ?? HelperCloudEd25519SealedStore();

  final KekProvider _source;
  final KekProvider _target;
  final String wifiVaultPath;
  final CloudEd25519SealedStore _cloudStore;

  /// Probe OP-TEE seal helper; throws [HalIoException] if unavailable.
  static Future<void> ensureOpteeProbe({
    String helperPath = OpteeKekProvider.defaultHelperPath,
    OpteeSealRunner? runner,
  }) async {
    final run = runner ??
        (List<String> cmd, String? _) =>
            Process.run(cmd.first, cmd.sublist(1));
    final r = await run([helperPath, 'probe'], null);
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      final out = '${r.stdout}'.trim();
      throw HalIoException(
        'optee probe failed (exit ${r.exitCode}): '
        '${err.isNotEmpty ? err : out}',
      );
    }
  }

  /// Migrate Wi‑Fi vault and/or cloud Ed25519 sealed blob.
  Future<SecretsBackendMigrationReport> migrate({
    bool wifi = true,
    bool cloud = true,
    String? productSn,
  }) async {
    var wifiMigrated = 0;
    var wifiSkipped = 0;
    var wifiFailed = 0;
    final wifiErrors = <String, String>{};

    if (wifi) {
      final w = await migrateWifiVault();
      wifiMigrated = w.wifiMigrated;
      wifiSkipped = w.wifiSkipped;
      wifiFailed = w.wifiFailed;
      wifiErrors.addAll(w.wifiErrors);
    }

    var cloudMigrated = false;
    var cloudSkipped = false;
    var cloudAbsent = false;
    String? cloudError;
    if (cloud) {
      final sn = productSn?.trim() ?? '';
      if (sn.isEmpty) {
        cloudError = 'empty product SN';
      } else {
        try {
          final c = await migrateCloudEd25519(productSn: sn);
          cloudMigrated = c.cloudMigrated;
          cloudSkipped = c.cloudSkipped;
          cloudAbsent = c.cloudAbsent;
          cloudError = c.cloudError;
        } catch (e) {
          cloudError = '$e';
        }
      }
    }

    return SecretsBackendMigrationReport(
      wifiMigrated: wifiMigrated,
      wifiSkipped: wifiSkipped,
      wifiFailed: wifiFailed,
      wifiErrors: wifiErrors,
      cloudMigrated: cloudMigrated,
      cloudSkipped: cloudSkipped,
      cloudAbsent: cloudAbsent,
      cloudError: cloudError,
    );
  }

  /// Re-seal each software (`LWSS`) vault entry with [target].
  Future<SecretsBackendMigrationReport> migrateWifiVault() async {
    final f = File(wifiVaultPath);
    if (!await f.exists()) {
      return const SecretsBackendMigrationReport();
    }
    final bytes = await f.readAsBytes();
    if (bytes.isEmpty) {
      return const SecretsBackendMigrationReport();
    }
    final doc = WifiVaultDocument.decode(bytes);
    if (doc.entries.isEmpty) {
      return const SecretsBackendMigrationReport();
    }

    var migrated = 0;
    var skipped = 0;
    var failed = 0;
    final errors = <String, String>{};
    final next = Map<String, Uint8List>.from(doc.entries);
    var dirty = false;

    for (final e in doc.entries.entries) {
      final ssid = e.key;
      final blob = e.value;
      if (SealedBlobMagic.isOptee(blob)) {
        skipped++;
        continue;
      }
      if (!SealedBlobMagic.isSoftware(blob)) {
        failed++;
        errors[ssid] = 'unrecognized sealed blob magic';
        continue;
      }
      try {
        final aad = wifiVaultAadForSsid(ssid);
        final plain = await _source.unseal(blob: blob, aad: aad);
        final neu = await _target.seal(plaintext: plain, aad: aad);
        plain.fillRange(0, plain.length, 0);
        next[ssid] = neu;
        migrated++;
        dirty = true;
      } catch (err) {
        failed++;
        errors[ssid] = '$err';
      }
    }

    if (dirty) {
      await f.parent.create(recursive: true);
      final tmp = File('$wifiVaultPath.tmp');
      await tmp.writeAsBytes(
        doc.copyWith(entries: next).encode(),
        flush: true,
      );
      await tmp.rename(wifiVaultPath);
      try {
        await Process.run('chmod', ['600', wifiVaultPath]);
      } catch (_) {}
    }

    return SecretsBackendMigrationReport(
      wifiMigrated: migrated,
      wifiSkipped: skipped,
      wifiFailed: failed,
      wifiErrors: errors,
    );
  }

  /// Re-seal Vendor Storage cloud Ed25519 blob for [productSn] (AAD must match).
  Future<SecretsBackendMigrationReport> migrateCloudEd25519({
    required String productSn,
  }) async {
    final sn = productSn.trim();
    if (sn.isEmpty) {
      return const SecretsBackendMigrationReport(
        cloudError: 'empty product SN',
      );
    }
    final sealed = await _cloudStore.readSealed();
    if (sealed == null || sealed.isEmpty) {
      return const SecretsBackendMigrationReport(cloudAbsent: true);
    }
    if (SealedBlobMagic.isOptee(sealed)) {
      try {
        final probe = await _target.unseal(
          blob: sealed,
          aad: cloudEd25519AadForSn(sn),
        );
        probe.fillRange(0, probe.length, 0);
        return const SecretsBackendMigrationReport(cloudSkipped: true);
      } catch (e) {
        return SecretsBackendMigrationReport(
          cloudError:
              'optee blob present but unseal failed (TEE FS/KEK likely lost '
              'across A/B — clear VS cloud key and re-activate): $e',
        );
      }
    }
    if (!SealedBlobMagic.isSoftware(sealed)) {
      return const SecretsBackendMigrationReport(
        cloudError: 'unrecognized sealed blob magic',
      );
    }
    final aad = cloudEd25519AadForSn(sn);
    try {
      final seed = await _source.unseal(blob: sealed, aad: aad);
      if (seed.length != 32) {
        return SecretsBackendMigrationReport(
          cloudError: 'unsealed seed length ${seed.length} != 32',
        );
      }
      final neu = await _target.seal(plaintext: seed, aad: aad);
      seed.fillRange(0, seed.length, 0);
      await _cloudStore.writeSealed(neu, force: true);
      return const SecretsBackendMigrationReport(cloudMigrated: true);
    } catch (e) {
      return SecretsBackendMigrationReport(cloudError: '$e');
    }
  }
}
