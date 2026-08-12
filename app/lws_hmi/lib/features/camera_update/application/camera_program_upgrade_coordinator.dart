import 'dart:async';
import 'dart:io';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/peripheral_firmware_newest_wins.dart';
import 'package:lws_hmi/features/camera_update/application/camera_program_upgrade_applicator.dart';
import 'package:lws_hmi/features/camera_update/application/camera_program_upgrade_checker.dart';
import 'package:lws_hmi/features/camera_update/domain/bundled_camera_firmware_version_gate.dart';
import 'package:lws_hmi/features/camera_update/domain/camera_cloud_manifest.dart';
import 'package:lws_hmi/features/camera_update/infrastructure/bundled_camera_firmware_assets.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/upgrade_safety/upgrade_safety.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';

/// Bundled, cloud, or host-pushed camera firmware candidate.
final class CameraProgramFirmwareOffer {
  const CameraProgramFirmwareOffer({
    required this.fileName,
    required this.deviceVersionLabel,
    required this.bundledVersionLabel,
    required this.cameraHost,
    this.assetKey,
    this.hostFile,
    this.packageUrl,
    this.title,
    this.content,
  });

  final String fileName;
  final String deviceVersionLabel;
  final String bundledVersionLabel;
  final String cameraHost;

  /// Flutter asset key when upgrading from ship tree.
  final String? assetKey;

  /// Absolute path when upgrading from host `make upgrade-camera`.
  final File? hostFile;

  /// Cloud / host-HTTP package URL (download + verify before apply).
  final String? packageUrl;

  /// Optional release title from cloud `release.json`.
  final String? title;

  /// Optional release notes body from cloud `release.json`.
  final String? content;

  bool get isHostPush => hostFile != null;
  bool get isCloud => packageUrl != null && hostFile == null && assetKey == null;
}

/// Progress snapshot for the dedicated camera program upgrade page.
final class CameraProgramUpgradeProgress {
  const CameraProgramUpgradeProgress({
    this.phase = CameraProgramUpgradePhase.transfer,
    this.percent = 0,
    this.isRunning = false,
    this.isTerminalOk = false,
    this.isTerminalFail = false,
    this.errorMessage,
  });

  final CameraProgramUpgradePhase phase;
  final int percent;
  final bool isRunning;
  final bool isTerminalOk;
  final bool isTerminalFail;
  final String? errorMessage;

  static const idle = CameraProgramUpgradeProgress();
}

/// Orchestrates camera CGI flash for Settings / Home / host make.
final class CameraProgramUpgradeCoordinator {
  CameraProgramUpgradeCoordinator._();

  static final CameraProgramUpgradeCoordinator instance =
      CameraProgramUpgradeCoordinator._();

  GlobalKey<NavigatorState>? _navKey;
  AppServices? _services;
  CameraDeviceInfoCache? _deviceInfo;
  String? Function()? _cloudManifestUrlResolver;
  WarnAlarmController? _warnAlarm;
  OtaHttpClient _http = HttpOtaClient();
  SignedBlobFetch _signedFetch = SignedBlobFetch();

  final _progressController =
      StreamController<CameraProgramUpgradeProgress>.broadcast();
  CameraProgramUpgradeProgress _lastProgress = CameraProgramUpgradeProgress.idle;
  Future<void>? _runFuture;
  File? _pendingHostFile;

  Stream<CameraProgramUpgradeProgress> get progress =>
      _progressController.stream;
  CameraProgramUpgradeProgress get lastProgress => _lastProgress;
  bool get isSessionActive => _runFuture != null;
  File? get pendingHostFile => _pendingHostFile;

  void configure({
    required GlobalKey<NavigatorState> navigatorKey,
    required AppServices services,
    required CameraDeviceInfoCache deviceInfoCache,
    String? Function()? cloudManifestUrlResolver,
    OtaHttpClient? httpClient,
    SignedBlobFetch? signedFetch,
    WarnAlarmController? warnAlarm,
  }) {
    _navKey = navigatorKey;
    _services = services;
    _deviceInfo = deviceInfoCache;
    _cloudManifestUrlResolver = cloudManifestUrlResolver;
    _warnAlarm = warnAlarm;
    if (httpClient != null) {
      _http = httpClient;
    }
    if (signedFetch != null) {
      _signedFetch = signedFetch;
    }
  }

  /// Drop terminal / stale UI progress so a later page open starts clean.
  void clearProgress() {
    if (_runFuture != null) {
      return;
    }
    if (_lastProgress.isRunning ||
        _lastProgress.isTerminalOk ||
        _lastProgress.isTerminalFail ||
        _lastProgress.percent != 0) {
      _emit(CameraProgramUpgradeProgress.idle);
    }
  }

  void _emit(CameraProgramUpgradeProgress p) {
    _lastProgress = p;
    if (!_progressController.isClosed) {
      _progressController.add(p);
    }
  }

  Future<void> navigateToUpgradePage() async {
    final nav = _navKey?.currentState;
    if (nav == null) {
      return;
    }
    nav.pushNamedAndRemoveUntil(
      AppRoutes.cameraProgramUpgrade,
      (route) => false,
    );
  }

  Future<String?> _resolveCameraHost() async {
    final services = _services;
    if (services == null) {
      return null;
    }
    try {
      final product = await services.ensureProductInfo();
      final host = effectiveCameraHost(product).trim();
      return host.isEmpty ? null : host;
    } catch (_) {
      return null;
    }
  }

  Future<PeripheralFirmwareOfferEvaluation<CameraProgramFirmwareOffer>>
      evaluateOffer({
    UpgradePolicy policy = UpgradePolicy.operator,
  }) async {
    final deviceInfo = _deviceInfo;
    if (deviceInfo == null) {
      return const PeripheralFirmwareOfferEvaluation();
    }
    final host = await _resolveCameraHost();
    if (host == null) {
      return const PeripheralFirmwareOfferEvaluation();
    }

    deviceInfo.invalidate();
    final raw = await deviceInfo.fetchRawAppVersion(host);
    final display = raw == null
        ? null
        : parseCameraAppVersionDisplay(raw);

    final checker = CameraProgramUpgradeChecker(
      deviceAppVersionRaw: raw,
    );
    final result = await checker.check(
      currentVersion: display ?? '',
      policy: policy,
    );

    CameraProgramFirmwareOffer? bundled;
    if (result is UpgradeCheckAvailable) {
      final fileName = result.offer.payload;
      if (fileName is String) {
        final parsed =
            BundledCameraFirmwareVersionGate.parseFileName(fileName);
        if (parsed != null) {
          bundled = CameraProgramFirmwareOffer(
            assetKey: '${BundledCameraFirmwareAssets.assetPrefix}$fileName',
            fileName: fileName,
            deviceVersionLabel: display ?? raw ?? '—',
            bundledVersionLabel: parsed.label,
            cameraHost: host,
          );
        }
      }
    }

    final cloudLeg = await _evaluateCloudOffer(
      host: host,
      deviceAppVersionRaw: raw,
      deviceVersionLabel: display ?? raw ?? '—',
      policy: policy,
    );

    final selected = PeripheralFirmwareNewestWins.select(
      bundled: bundled,
      cloud: cloudLeg.offer,
      compare: (a, b) {
        final av = BundledCameraFirmwareVersionGate.parseFileName(a.fileName);
        final bv = BundledCameraFirmwareVersionGate.parseFileName(b.fileName);
        if (av == null || bv == null) {
          return 0;
        }
        return PeripheralFirmwareNewestWins.compareCameraKeys(
          (av.major, av.minor, av.patch, av.build),
          (bv.major, bv.minor, bv.patch, bv.build),
        );
      },
    );
    return PeripheralFirmwareOfferEvaluation(
      offer: selected,
      cloudCheckFailed: cloudLeg.failed,
    );
  }

  Future<({CameraProgramFirmwareOffer? offer, bool failed})> _evaluateCloudOffer({
    required String host,
    required String? deviceAppVersionRaw,
    required String deviceVersionLabel,
    required UpgradePolicy policy,
  }) async {
    if (!shouldRunVersionCheck(policy)) {
      return (offer: null, failed: false);
    }
    final manifestUrl = _cloudManifestUrlResolver?.call();
    if (manifestUrl == null) {
      return (offer: null, failed: false);
    }
    try {
      final json = await _http.getJson(manifestUrl);
      final candidate = CameraCloudManifest.tryParseOffer(
        json: json,
        deviceAppVersionRaw: deviceAppVersionRaw,
      );
      if (candidate == null) {
        return (offer: null, failed: false);
      }
      final channelVersion = (json['version'] as String?)?.trim();
      if (channelVersion != null &&
          channelVersion.isNotEmpty &&
          !CameraCloudManifest.channelVersionMatches(
            channelVersion,
            candidate.version,
          )) {
        debugPrint(
          'CameraProgramUpgrade: cloud version "$channelVersion" '
          'does not match filename ${candidate.version.label}; '
          'using filename',
        );
      }
      return (
        offer: CameraProgramFirmwareOffer(
          fileName: candidate.fileName,
          deviceVersionLabel: deviceVersionLabel,
          bundledVersionLabel: candidate.version.label,
          cameraHost: host,
          packageUrl: candidate.packageUrl,
          title: candidate.title,
          content: candidate.content,
        ),
        failed: false,
      );
    } catch (e, st) {
      debugPrint('CameraProgramUpgrade: cloud check soft-fail: $e\n$st');
      return (offer: null, failed: true);
    }
  }

  /// Host `make upgrade-camera`: stash file, open page, skip version gate.
  Future<void> startHostUpgrade(File firmwareFile) async {
    if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      return;
    }
    if (!await firmwareFile.exists()) {
      return;
    }
    final services = _services;
    if (services != null) {
      await UpgradeSafety.stopWork(services, reason: 'camera-host');
    }
    _pendingHostFile = firmwareFile;
    await navigateToUpgradePage();
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
  }

  File? takePendingHostFile() {
    final f = _pendingHostFile;
    _pendingHostFile = null;
    return f;
  }

  Future<void> runOfferUpgrade(
    CameraProgramFirmwareOffer offer, {
    UpgradePolicy policy = UpgradePolicy.operator,
  }) async {
    if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      throw StateError('upgrade_busy');
    }

    final deviceInfo = _deviceInfo;
    final services = _services;
    await _beginRun(() async {
      FirmwareUpgradeCoordinator.markBundledUpgradeStarted();
      final applicator = CameraProgramUpgradeApplicator(
        deviceInfoCache: deviceInfo,
      );
      var radios = UpgradeRadioSnapshot.none;
      try {
        if (services != null) {
          await UpgradeSafety.stopWork(
            services,
            reason: 'camera-program-upgrade',
          );
        }

        late final Uint8List bytes;
        if (offer.hostFile != null) {
          bytes = await offer.hostFile!.readAsBytes();
        } else if (offer.packageUrl != null) {
          _emit(
            const CameraProgramUpgradeProgress(
              isRunning: true,
              phase: CameraProgramUpgradePhase.transfer,
              percent: 0,
            ),
          );
          try {
            final verified = await _signedFetch.downloadAndVerify(
              packageUrl: offer.packageUrl!,
              stagingDir: kCameraStagingDir,
              fileName: offer.fileName,
            );
            bytes = await verified.readAsBytes();
          } catch (e) {
            _emit(
              CameraProgramUpgradeProgress(
                isTerminalFail: true,
                phase: CameraProgramUpgradePhase.transfer,
                errorMessage: '$e',
              ),
            );
            return;
          }
        } else if (offer.assetKey != null) {
          final data =
              await BundledCameraFirmwareAssets.loadBytes(offer.assetKey!);
          if (data == null) {
            throw StateError('asset_missing');
          }
          bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } else {
          throw StateError('no_firmware_source');
        }

        if (services != null) {
          radios = await UpgradeSafety.quiesceRadios(services);
        }

        final warn = _warnAlarm;
        var cameraLikelyOnline = false;
        if (warn != null) {
          await warn.beginCameraFirmwareUpgradeQuiet();
        }
        try {
          _emit(
            const CameraProgramUpgradeProgress(
              isRunning: true,
              phase: CameraProgramUpgradePhase.transfer,
              percent: 0,
            ),
          );
          final result = await applicator.upgrade(
            cameraHost: offer.cameraHost,
            fileName: offer.fileName,
            bytes: bytes,
            onProgress: (phase, percent) {
              _emit(
                CameraProgramUpgradeProgress(
                  isRunning: true,
                  phase: phase,
                  percent: percent ?? 0,
                ),
              );
            },
          );
          cameraLikelyOnline = result.isSuccess;

          if (result.isSuccess) {
            try {
              deviceInfo?.invalidate();
              await deviceInfo?.fetch(offer.cameraHost);
            } catch (_) {}
            _emit(
              const CameraProgramUpgradeProgress(
                percent: 100,
                phase: CameraProgramUpgradePhase.waitOnline,
                isTerminalOk: true,
              ),
            );
          } else {
            _emit(
              CameraProgramUpgradeProgress(
                isTerminalFail: true,
                phase: switch (result.outcome) {
                  CameraProgramUpgradeOutcome.transferFailed =>
                    CameraProgramUpgradePhase.transfer,
                  CameraProgramUpgradeOutcome.rebootFailed =>
                    CameraProgramUpgradePhase.reboot,
                  CameraProgramUpgradeOutcome.waitTimeout =>
                    CameraProgramUpgradePhase.waitOnline,
                  CameraProgramUpgradeOutcome.success =>
                    CameraProgramUpgradePhase.waitOnline,
                },
                errorMessage: result.errorMessage,
              ),
            );
          }
        } finally {
          if (warn != null) {
            await warn.endCameraFirmwareUpgradeQuiet(
              cameraLikelyOnline: cameraLikelyOnline,
            );
          }
        }
      } finally {
        if (services != null) {
          await UpgradeSafety.restoreRadios(services, radios);
        }
        applicator.dispose();
        FirmwareUpgradeCoordinator.markBundledUpgradeEnded();
      }
    });
  }

  Future<void> _beginRun(Future<void> Function() body) async {
    if (_runFuture != null) {
      throw StateError('session_active');
    }
    final future = body();
    _runFuture = future;
    try {
      await future;
    } finally {
      if (identical(_runFuture, future)) {
        _runFuture = null;
      }
    }
  }
}
