import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/secrets/kek_provider.dart';
import 'package:cyber_hal/src/secrets/secrets_backends.dart';

/// Runs the OP-TEE seal helper (`probe` / `seal` / `unseal`).
typedef OpteeSealRunner = Future<ProcessResult> Function(
  List<String> command,
  String? stdin,
);

/// OP-TEE-backed Secrets provider (production default on real boards).
///
/// Talks to [helperPath] (default `/usr/libexec/hmi/secrets-seal`). Fail-closed:
/// missing TEE/TA → seal/unseal throw [HalIoException] (no silent software).
final class OpteeKekProvider implements KekProvider {
  OpteeKekProvider({
    this.helperPath = defaultHelperPath,
    OpteeSealRunner? runner,
  }) : _runner = runner ?? _defaultRunner;

  static const defaultHelperPath = '/usr/libexec/hmi/secrets-seal';

  final String helperPath;
  final OpteeSealRunner _runner;

  static Future<ProcessResult> _defaultRunner(
    List<String> command,
    String? stdin,
  ) async {
    if (stdin == null) {
      return Process.run(command.first, command.sublist(1));
    }
    final process = await Process.start(command.first, command.sublist(1));
    process.stdin.write(stdin);
    await process.stdin.close();
    final out = await process.stdout.transform(utf8.decoder).join();
    final err = await process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode;
    return ProcessResult(process.pid, code, out, err);
  }

  @override
  String get backendId => SecretsBackendId.optee;

  @override
  bool get isHardwareBound => true;

  /// True when `/dev/tee0` exists and helper `probe` succeeds.
  Future<bool> isAvailable() async {
    if (!File('/dev/tee0').existsSync() &&
        !File('/dev/teepriv0').existsSync()) {
      return false;
    }
    final r = await _runner(<String>[helperPath, 'probe'], null);
    return r.exitCode == 0;
  }

  @override
  Future<Uint8List> seal({
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    final payload = jsonEncode(<String, String>{
      'plaintext_b64': base64Encode(plaintext),
      'aad_b64': base64Encode(aad),
    });
    final r = await _runner(<String>[helperPath, 'seal'], payload);
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      final out = '${r.stdout}'.trim();
      throw HalIoException(
        'optee seal failed (exit ${r.exitCode}): '
        '${err.isNotEmpty ? err : out}',
      );
    }
    final line = '${r.stdout}'.trim().split('\n').last;
    try {
      return Uint8List.fromList(base64Decode(line));
    } catch (e) {
      throw HalIoException('optee seal: bad helper output', cause: e);
    }
  }

  @override
  Future<Uint8List> unseal({
    required Uint8List blob,
    required Uint8List aad,
  }) async {
    final payload = jsonEncode(<String, String>{
      'blob_b64': base64Encode(blob),
      'aad_b64': base64Encode(aad),
    });
    final r = await _runner(<String>[helperPath, 'unseal'], payload);
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      final out = '${r.stdout}'.trim();
      throw HalIoException(
        'optee unseal failed (exit ${r.exitCode}): '
        '${err.isNotEmpty ? err : out}',
      );
    }
    final line = '${r.stdout}'.trim().split('\n').last;
    try {
      return Uint8List.fromList(base64Decode(line));
    } catch (e) {
      throw HalIoException('optee unseal: bad helper output', cause: e);
    }
  }
}
