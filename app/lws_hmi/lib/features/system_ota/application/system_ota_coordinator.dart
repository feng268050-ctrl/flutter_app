import 'dart:async';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/settings/application/laser_work_guard.dart';

typedef OtaManifestUrlResolver = String? Function();
typedef OtaProgressSink = void Function(OtaProgress progress);

/// Whole-device OTA orchestration for Settings, host triggers, and cloud WS.
final class SystemOtaCoordinator {
  SystemOtaCoordinator._();

  static final SystemOtaCoordinator instance = SystemOtaCoordinator._();

  GlobalKey<NavigatorState>? _navKey;
  AppServices? _services;
  OtaManifestUrlResolver? _manifestUrlResolver;
  OtaProgressSink? _progressSink;

  OtaSession? _session;
  StreamSubscription<OtaProgress>? _progressSub;
  Future<void>? _runFuture;
  final _uiProgressController = StreamController<OtaProgress>.broadcast();

  /// UI + cloud WS progress (fed only from [OtaSession.progress]).
  Stream<OtaProgress> get uiProgress => _uiProgressController.stream;

  void configure({
    required GlobalKey<NavigatorState> navigatorKey,
    required AppServices services,
    required OtaManifestUrlResolver manifestUrlResolver,
    /// Cloud WS sink — called from the session progress subscription.
    OtaProgressSink? progressSink,
  }) {
    _navKey = navigatorKey;
    _services = services;
    _manifestUrlResolver = manifestUrlResolver;
    _progressSink = progressSink;
  }

  OtaSession? get activeSession => _session;
  bool get isSessionActive => _runFuture != null;
  OtaProgress? get lastProgress => _session?.lastProgress;

  static bool isNonCancelablePhase(OtaPhase phase) {
    return phase == OtaPhase.writing ||
        phase == OtaPhase.arming ||
        phase == OtaPhase.ok;
  }

  /// Stop laser work and mark whole-device OTA in progress (mutex vs control-board flash).
  Future<void> safeShutdown() async {
    final services = _services;
    if (services == null) {
      return;
    }
    if (FirmwareUpgradeCoordinator.isBundledUpgradeInProgress) {
      throw StateError('bundled_upgrade_in_progress');
    }
    try {
      await services.ensureModbusLive();
      await services.modbus.writeAttribute(
        LaserWorkGuard.laserEnableAttribute,
        false,
      );
    } catch (e) {
      debugPrint('SystemOtaCoordinator: laser disarm soft-failed: $e');
    }
    await services.disarmLaserEnableForSafety(reason: 'system-ota');
    FirmwareUpgradeCoordinator.setOtaUpgradeInProgress(true);
  }

  /// Clears the entire nav stack and opens the dedicated upgrade page.
  Future<void> navigateToUpgradePage() async {
    final nav = _navKey?.currentState;
    if (nav == null) {
      return;
    }
    nav.pushNamedAndRemoveUntil(
      AppRoutes.systemUpgrade,
      (route) => false,
    );
  }

  /// Manifest check only — no partition writes.
  Future<CheckUpdateResult> checkForUpdate({String? manifestUrl}) async {
    final url = manifestUrl ?? _manifestUrlResolver?.call();
    if (url == null || url.trim().isEmpty) {
      throw StateError('manifest_unavailable');
    }
    final session = _ensureSession();
    return session.checkForUpdate(
      manifestUrl: url,
      currentVersion: kSystemVersion,
    );
  }

  /// Cloud OTA after safe shutdown + upgrade page (Settings / WS).
  Future<void> startCloudUpdateFlow(OtaManifest manifest) async {
    await safeShutdown();
    _ensureSession();
    _wireProgress();
    await navigateToUpgradePage();
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    await _beginRun(() => _session!.runCloudUpdate(manifest: manifest));
  }

  /// Host `make upgrade`: HTTP GET from host ephemeral server, then verify+apply.
  Future<void> startHostDownload({
    required String packageUrl,
    bool oemOnly = false,
  }) async {
    await safeShutdown();
    _ensureSession();
    _wireProgress();
    await navigateToUpgradePage();
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final manifest = OtaManifest(
      version: '0.0.0-host',
      packageUrl: packageUrl,
    );
    unawaited(
      _beginRun(
        () => _session!.runHostHttpSession(
          manifest: manifest,
          oemOnly: oemOnly,
        ),
      ),
    );
  }

  Future<Map<String, Object?>> handleWsCheckUpdate(Object? payload) async {
    try {
      final manifestUrl =
          _manifestUrlFromPayload(payload) ?? _manifestUrlResolver?.call();
      if (manifestUrl == null || manifestUrl.isEmpty) {
        return _otaAckError(
          'manifest_unavailable',
          'OTA manifest URL is not configured',
        );
      }
      final result = await checkForUpdate(manifestUrl: manifestUrl);
      return {
        'ok': true,
        'has_update': result.hasUpdate,
        if (result.manifest != null) 'manifest': result.manifest!.toJson(),
      };
    } catch (e) {
      return _otaAckError('check_failed', '$e');
    }
  }

  Future<Map<String, Object?>> handleWsUpdateSystem(Object? payload) async {
    if (isSessionActive) {
      return {
        'ok': true,
        'started': false,
        'error_message': 'ota_session_active',
      };
    }
    try {
      final OtaManifest manifest;
      if (payload is Map) {
        // Accepts publish-shaped `{url,…}` or internal `{package_url,…}`.
        manifest = OtaManifest.fromJson(
          Map<String, dynamic>.from(payload),
        );
      } else {
        final check = await checkForUpdate();
        if (!check.hasUpdate || check.manifest == null) {
          return {
            'ok': true,
            'started': false,
            'has_update': false,
          };
        }
        manifest = check.manifest!;
      }
      unawaited(startCloudUpdateFlow(manifest));
      return {'ok': true, 'started': true};
    } catch (e) {
      return _otaAckError('update_failed', '$e');
    }
  }

  void cancelIfAllowed() {
    final phase = _session?.lastProgress?.phase;
    if (phase != null && isNonCancelablePhase(phase)) {
      return;
    }
    _tearDownSession();
  }

  OtaSession _ensureSession() {
    _session ??= OtaSession();
    return _session!;
  }

  Future<void> _beginRun(Future<void> Function() run) async {
    if (_runFuture != null) {
      return;
    }
    _ensureSession();
    _wireProgress();
    final future = run();
    _runFuture = future;
    try {
      await future;
    } catch (e, stack) {
      debugPrint('SystemOtaCoordinator: session failed: $e\n$stack');
    } finally {
      final rebootPending = _session?.lastProgress?.phase == OtaPhase.ok;
      _tearDownSession(keepOtaFlag: rebootPending);
      _runFuture = null;
    }
  }

  void _wireProgress() {
    unawaited(_progressSub?.cancel());
    _progressSub = _session?.progress.listen(_onProgress);
  }

  void _onProgress(OtaProgress progress) {
    if (!_uiProgressController.isClosed) {
      _uiProgressController.add(progress);
    }
    final sink = _progressSink;
    if (sink == null) {
      return;
    }
    if (!_shouldEmitRemoteProgress(progress.phase)) {
      return;
    }
    sink(progress);
  }

  static bool _shouldEmitRemoteProgress(OtaPhase phase) {
    return phase == OtaPhase.transferring ||
        phase == OtaPhase.verifying ||
        phase == OtaPhase.extracting ||
        phase == OtaPhase.writing ||
        phase == OtaPhase.arming ||
        phase == OtaPhase.fail;
  }

  void _tearDownSession({bool keepOtaFlag = false}) {
    unawaited(_progressSub?.cancel());
    _progressSub = null;
    if (!keepOtaFlag) {
      FirmwareUpgradeCoordinator.setOtaUpgradeInProgress(false);
    }
  }

  static String? _manifestUrlFromPayload(Object? payload) {
    if (payload is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(payload);
    final direct = map['manifest_url'] ?? map['manifestUrl'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    return null;
  }

  static Map<String, Object?> _otaAckError(String code, String message) {
    return {
      'ok': false,
      'has_update': false,
      'started': false,
      'error_code': code,
      'error_message': message,
    };
  }

  /// Test hook.
  @visibleForTesting
  void resetForTest() {
    unawaited(_progressSub?.cancel());
    _progressSub = null;
    _runFuture = null;
    _session = null;
    FirmwareUpgradeCoordinator.resetForTest();
  }
}
