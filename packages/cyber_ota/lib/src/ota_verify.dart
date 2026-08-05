import 'dart:io';

import 'ota_constants.dart';
import 'process_runner.dart';

/// Ed25519(SHA-512(archive)) verify via openssl (matches `scripts/ota-sign.sh`).
class OtaVerify {
  OtaVerify({
    ProcessRunner? processRunner,
    this.pubkeyPath = kDefaultOtaPubkey,
  }) : _proc = processRunner ?? ProcessRunner();

  final ProcessRunner _proc;
  final String pubkeyPath;

  Future<void> verifyPackage({
    required String archivePath,
    required String sigPath,
  }) async {
    final archive = File(archivePath);
    final sig = File(sigPath);
    final pubkey = File(pubkeyPath);
    if (!await archive.exists()) {
      throw StateError('archive not found: $archivePath');
    }
    if (!await sig.exists()) {
      throw StateError('signature not found: $sigPath');
    }
    if (!await pubkey.exists()) {
      throw StateError('pubkey not found: $pubkeyPath');
    }

    final digest = File(
      '${Directory.systemTemp.path}/lws-ota-digest-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await _proc.runChecked(
        'openssl',
        <String>[
          'dgst',
          '-sha512',
          '-binary',
          '-out',
          digest.path,
          archivePath,
        ],
        errorPrefix: 'openssl sha512',
      );
      await _proc.runChecked(
        'openssl',
        <String>[
          'pkeyutl',
          '-verify',
          '-pubin',
          '-inkey',
          pubkeyPath,
          '-sigfile',
          sigPath,
          '-in',
          digest.path,
        ],
        errorPrefix: 'openssl Ed25519 verify',
      );
    } finally {
      try {
        if (await digest.exists()) {
          await digest.delete();
        }
      } catch (_) {}
    }
  }
}
