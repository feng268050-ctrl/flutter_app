import 'dart:async';
import 'dart:io';

import 'http_client.dart';
import 'ota_apply.dart';
import 'ota_constants.dart';
import 'ota_extract.dart';
import 'ota_ingress.dart';
import 'ota_log.dart';
import 'ota_manifest.dart';
import 'ota_phase.dart';
import 'ota_progress.dart';
import 'ota_verify.dart';
import 'version_compare.dart';

/// Result of a manifest check against the device version.
final class CheckUpdateResult {
  const CheckUpdateResult({
    required this.hasUpdate,
    this.manifest,
  });

  final bool hasUpdate;
  final OtaManifest? manifest;
}

/// Whole-device OTA orchestrator — manifest, transfer, verify, extract, apply.
///
/// Board tools (`openssl`, `tar`, `dd`, `systemctl`) are invoked as subprocesses
/// from Dart; progress is emitted on [progress] only. Cloud WS / UI subscribe to
/// that stream. Debug detail is appended to `ota.log` under [stagingDir].
final class OtaSession {
  OtaSession({
    this.stagingDir = kDefaultStagingDir,
    OtaHttpClient? httpClient,
    OtaVerify? verify,
    OtaExtract? extract,
    OtaApply? apply,
    OtaLog? log,
  })  : _http = httpClient ?? HttpOtaClient(),
        _verify = verify ?? OtaVerify(),
        _extract = extract ?? OtaExtract(),
        _apply = apply ?? OtaApply(),
        _log = log ?? OtaLog(stagingDir);

  final String stagingDir;
  final OtaHttpClient _http;
  final OtaVerify _verify;
  final OtaExtract _extract;
  final OtaApply _apply;
  final OtaLog _log;

  final _progressController = StreamController<OtaProgress>.broadcast();
  OtaProgress? _lastProgress;

  /// Progress events for UI / cloud WS subscribers.
  Stream<OtaProgress> get progress => _progressController.stream;

  OtaProgress? get lastProgress => _lastProgress;

  String get packagePath => '$stagingDir$kPackageFileName';

  String get sigPath => '$stagingDir$kSigFileName';

  /// Fetches a remote manifest and compares [currentVersion].
  Future<CheckUpdateResult> checkForUpdate({
    required String manifestUrl,
    required String currentVersion,
  }) async {
    await _emit(
      OtaProgress(
        phase: OtaPhase.checking,
        message: 'Checking for updates',
      ),
    );

    final json = await _http.getJson(manifestUrl);
    final manifest = OtaManifest.fromJson(json);
    final hasUpdate = isNewer(manifest.version, currentVersion);

    await _emit(
      OtaProgress(
        phase: OtaPhase.idle,
        message: hasUpdate ? 'Update available' : 'Already up to date',
      ),
    );

    return CheckUpdateResult(hasUpdate: hasUpdate, manifest: manifest);
  }

  /// Cloud OTA: download archive + signature, verify, then extract/apply.
  Future<void> runCloudUpdate({
    required OtaManifest manifest,
    bool oemOnly = false,
  }) {
    return _runStagedUpdate(
      ingress: const CloudIngress(),
      oemOnly: oemOnly,
      transfer: () => _downloadHttpPackage(
        manifest,
        ingress: OtaIngressKind.cloud,
      ),
    );
  }

  /// Host `make upgrade`: HTTP GET from host ephemeral server.
  Future<void> runHostHttpSession({
    required OtaManifest manifest,
    bool oemOnly = false,
  }) {
    return _runStagedUpdate(
      ingress: const HostHttpIngress(),
      oemOnly: oemOnly,
      transfer: () => _downloadHttpPackage(
        manifest,
        ingress: OtaIngressKind.host,
      ),
    );
  }

  /// Local/testing staging: archive already present or supplied by caller.
  Future<void> runLocalStagingSession({
    bool requireVerify = true,
    bool oemOnly = false,
  }) {
    return _runStagedUpdate(
      ingress: LocalStagingIngress(requireVerify: requireVerify),
      oemOnly: oemOnly,
      transfer: () async {
        await _emit(
          OtaProgress(
            phase: OtaPhase.transferring,
            percent: 100,
            ingress: OtaIngressKind.local,
            message: 'Archive staged locally',
          ),
        );
      },
    );
  }

  Future<void> _runStagedUpdate({
    required OtaIngress ingress,
    required bool oemOnly,
    required Future<void> Function() transfer,
  }) async {
    try {
      await _log.clear();
      await _log.line(
        'session start ingress=${ingress.kind.wireName} oemOnly=$oemOnly',
      );
      await _emit(
        OtaProgress(
          phase: OtaPhase.preparing,
          ingress: ingress.kind,
          message: 'Preparing OTA session',
        ),
      );

      await transfer();

      final archive = File(packagePath);
      final hasArchive = await archive.exists();

      if (ingress.requireVerify) {
        if (!hasArchive) {
          await _fail(
            ingress: ingress.kind,
            errorCode: 'missing_archive',
            message: 'Missing $packagePath',
          );
          return;
        }
        await _emit(
          OtaProgress(
            phase: OtaPhase.verifying,
            percent: 0,
            ingress: ingress.kind,
            message: 'Verifying package signature',
          ),
        );
        try {
          await _verify.verifyPackage(
            archivePath: packagePath,
            sigPath: sigPath,
          );
        } catch (e) {
          await _fail(
            ingress: ingress.kind,
            errorCode: 'verify_failed',
            message: '$e',
          );
          return;
        }
        await _emit(
          OtaProgress(
            phase: OtaPhase.verifying,
            percent: 100,
            ingress: ingress.kind,
            message: 'Signature verified',
          ),
        );
      }

      if (hasArchive) {
        await _emit(
          OtaProgress(
            phase: OtaPhase.extracting,
            percent: 0,
            bytesReceived: 0,
            bytesTotal: 0,
            ingress: ingress.kind,
            message: 'Extracting package',
          ),
        );
        try {
          await _extract.extractArchive(
            archivePath: packagePath,
            stagingDir: stagingDir,
            onProgress: (read, total) {
              final pct =
                  total <= 0 ? 0 : (read * 100 ~/ total).clamp(0, 100);
              unawaited(
                _emit(
                  OtaProgress(
                    phase: OtaPhase.extracting,
                    percent: pct,
                    bytesReceived: read,
                    bytesTotal: total,
                    ingress: ingress.kind,
                    message: 'Extracting package',
                  ),
                ),
              );
            },
          );
        } catch (e) {
          await _fail(
            ingress: ingress.kind,
            errorCode: 'extract_failed',
            message: '$e',
          );
          return;
        }
        await _emit(
          OtaProgress(
            phase: OtaPhase.extracting,
            percent: 100,
            ingress: ingress.kind,
            message: 'Extract done',
          ),
        );
      } else if (ingress is CloudIngress || ingress is HostHttpIngress) {
        await _fail(
          ingress: ingress.kind,
          errorCode: 'missing_archive',
          message: 'Missing $packagePath',
        );
        return;
      }

      try {
        if (oemOnly) {
          await _apply.applyOemOnly(
            stagingDir: stagingDir,
            ingress: ingress.kind,
            emit: _emit,
          );
        } else {
          await _apply.applyFullSystem(
            stagingDir: stagingDir,
            ingress: ingress.kind,
            emit: _emit,
            cameFromArchive: hasArchive,
          );
        }
      } catch (e) {
        await _fail(
          ingress: ingress.kind,
          errorCode: 'apply_failed',
          message: '$e',
        );
        return;
      }
    } catch (error, stackTrace) {
      await _fail(
        ingress: ingress.kind,
        errorCode: 'session_error',
        message: '$error',
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _downloadHttpPackage(
    OtaManifest manifest, {
    required OtaIngressKind ingress,
  }) async {
    await _emit(
      OtaProgress(
        phase: OtaPhase.transferring,
        percent: 0,
        ingress: ingress,
        message: 'Downloading package',
      ),
    );

    var packageBytes = 0;
    var packageTotal = 0;
    await _http.download(
      manifest.packageUrl,
      packagePath,
      onProgress: (received, total) {
        packageBytes = received;
        packageTotal = total ?? received;
        unawaited(
          _emitTransferProgress(
            ingress: ingress,
            bytesReceived: received,
            bytesTotal: total ?? received,
          ),
        );
      },
    );

    await _http.download(manifest.sigUrlResolved, sigPath);

    await _emitTransferProgress(
      ingress: ingress,
      bytesReceived: packageBytes,
      bytesTotal: packageTotal > 0 ? packageTotal : packageBytes,
      message: 'Download complete',
    );
  }

  Future<void> _emitTransferProgress({
    required OtaIngressKind ingress,
    required int bytesReceived,
    required int bytesTotal,
    int? percent,
    String message = 'Transferring',
  }) {
    final pct = percent ??
        (bytesTotal <= 0
            ? 0
            : (100 * bytesReceived / bytesTotal).floor().clamp(0, 100));
    return _emit(
      OtaProgress(
        phase: OtaPhase.transferring,
        percent: pct,
        bytesReceived: bytesReceived,
        bytesTotal: bytesTotal,
        ingress: ingress,
        message: message,
      ),
    );
  }

  Future<void> _fail({
    required OtaIngressKind ingress,
    required String errorCode,
    required String message,
  }) {
    return _emit(
      OtaProgress(
        phase: OtaPhase.fail,
        ingress: ingress,
        message: message,
        errorCode: errorCode,
      ),
    );
  }

  Future<void> _emit(OtaProgress progress) async {
    final monotonic = _monotonicProgress(progress);
    _lastProgress = monotonic;
    if (!_progressController.isClosed) {
      _progressController.add(monotonic);
    }
    await _log.progress(monotonic);
  }

  OtaProgress _monotonicProgress(OtaProgress next) {
    final prev = _lastProgress;
    if (prev == null || prev.phase != next.phase) {
      return next;
    }
    // Per-image write axis: allow 0–100% to restart when the image changes
    // (bytes_total and/or message), matching stream-file-progress one-file mode.
    if (prev.bytesTotal != next.bytesTotal || prev.message != next.message) {
      return next;
    }
    return next.copyWith(
      percent: next.percent < prev.percent ? prev.percent : next.percent,
      bytesReceived: next.bytesReceived < prev.bytesReceived
          ? prev.bytesReceived
          : next.bytesReceived,
    );
  }

  /// Closes the progress stream (for tests / dispose).
  Future<void> close() async {
    await _progressController.close();
  }
}
