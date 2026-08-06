import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/app_theme.dart';
import 'package:lws_hmi/app/hmi_route_restore.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_gate.dart';
import 'package:lws_hmi/features/device_registration/device_registration_dialogs.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_ids.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_scope.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_gate.dart';
import 'package:lws_hmi/features/safety_tips/presentation/safety_tips_dialog.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/platform/cloud/device_users_client.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime_scope.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_scope.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/platform/cloud/remote_lock_scope.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_scope.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_settings.dart';
import 'package:lws_hmi/features/home/presentation/home_page.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/monitor/presentation/monitor_page.dart';
import 'package:lws_hmi/features/monitor/presentation/ai_vision_video_choose_page.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_repository.dart';
import 'package:lws_hmi/features/process_library/infrastructure/sqlite_process_library_repository.dart';
import 'package:lws_hmi/features/process_library/presentation/engineer_mode_page.dart';
import 'package:lws_hmi/features/process_library/presentation/quick_mode_page.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_detail_page.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_thresholds_controller.dart';
import 'package:lws_hmi/features/ai/application/live_weld_stream_detect_coordinator.dart';
import 'package:lws_hmi/features/settings/application/ai_assistance_settings.dart';
import 'package:lws_hmi/features/settings/application/app_cyber_ime_language_provider.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';
import 'package:lws_hmi/features/settings/application/laser_work_guard.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_store.dart';
import 'package:lws_hmi/features/settings/application/product_keyboard_profile.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_scope.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';
import 'package:lws_hmi/features/settings/presentation/settings_page.dart';
import 'package:lws_hmi/features/system_status/presentation/gpio_led_overlay_host.dart';
import 'package:lws_hmi/features/system_status/presentation/system_status_overlay_host.dart';
import 'package:lws_hmi/features/statistics/application/job_runtime_statistics_recorder.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/sqlite_alarm_log_repository.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/features/bundled_firmware/infrastructure/sync_firmware_command_watcher.dart';
import 'package:lws_hmi/features/process_library/infrastructure/upgrade_process_library_command_watcher.dart';
import 'package:lws_hmi/features/system_ota/application/system_ota_coordinator.dart';
import 'package:lws_hmi/features/system_ota/infrastructure/ota_manifest_url.dart';
import 'package:lws_hmi/features/system_ota/infrastructure/upgrade_ota_command_watcher.dart';
import 'package:lws_hmi/features/system_ota/presentation/system_upgrade_page.dart';
import 'package:lws_hmi/gpio/rgb_led_policy_driver.dart';
import 'package:lws_hmi/l10n/app_locales.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/cyber/app_indexed_click_sound.dart';
import 'package:lws_hmi/ui/demo/p2_demo_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The existing QEMU screen is the visual reference: DPR 1.358 on its
/// 1536×960 output. The physical ynh960 panel is 1280×800 at the same size,
/// so it needs 1/1.2 its DPR to keep every DP control the same physical size.
/// Weston+eLinux defaults to DPR 1.0; `--force-scale-factor` blacks the frame.
const double _kSimulatorReferenceDevicePixelRatio = 1.3582342954159592;
const double _kSimulatorReferenceLongEdgePx = 1536;

/// Root MaterialApp: Home launcher, Settings, Monitor, hidden Demo.
class LwsHmiApp extends StatefulWidget {
  const LwsHmiApp({
    super.key,
    required this.boardProfile,
    this.services,
    this.soundEffectStore,
    this.miscSettingsStore,
    this.commonSettingsStore,
    this.advancedSettingsStore,
    this.bootSelfCheckSettings,
    this.processLibraryRepository,
    this.cloudSettingsStore,
    this.remoteLockStore,
  });

  final BoardProfile boardProfile;

  /// Optional override for tests (inject fakes).
  final AppServices? services;

  /// Optional override for tests (inject fake prefs path / store).
  final SoundEffectStore? soundEffectStore;

  /// Optional override for tests (inject fake Misc JSON path / store).
  final MiscSettingsStore? miscSettingsStore;

  /// Optional override for tests (inject fake Common JSON path / store).
  final CommonSettingsStore? commonSettingsStore;

  /// Optional override for tests (inject fake Advanced JSON path / store).
  final AdvancedSettingsStore? advancedSettingsStore;

  /// Optional override for tests (disable overlay / fake prefs path).
  final BootSelfCheckSettings? bootSelfCheckSettings;

  /// Optional in-memory/test repository override.
  final ProcessLibraryRepository? processLibraryRepository;

  /// Optional cloud settings override for tests.
  final CloudSettingsStore? cloudSettingsStore;

  /// Optional remote lock store override for tests.
  final DeviceRemoteLockStore? remoteLockStore;

  @override
  State<LwsHmiApp> createState() => _LwsHmiAppState();
}

class _LwsHmiAppState extends State<LwsHmiApp> with WidgetsBindingObserver {
  late final AppServices _services =
      widget.services ?? AppServices(boardProfile: widget.boardProfile);

  late final SoundEffectStore _soundEffectStore = widget.soundEffectStore ??
      SoundEffectStore(feedback: _services.buttonFeedback);

  late final MiscSettingsStore _miscSettingsStore =
      widget.miscSettingsStore ?? MiscSettingsStore();

  late final CommonSettingsStore _commonSettingsStore =
      widget.commonSettingsStore ?? CommonSettingsStore();

  late final AdvancedSettingsStore _advancedSettingsStore =
      widget.advancedSettingsStore ?? AdvancedSettingsStore();

  late final AiAssistanceSettings _aiAssistanceSettings =
      AiAssistanceSettings(_advancedSettingsStore);

  late final LiveWeldStreamDetectCoordinator _liveWeldStreamDetect =
      LiveWeldStreamDetectCoordinator(
    services: _services,
    aiAssistance: _aiAssistanceSettings,
  );

  late final DangerousOperationsSettings _dangerousOperationsSettings =
      DangerousOperationsSettings(_advancedSettingsStore);

  late final AdvancedSettingsThresholdsController _thresholdsController =
      AdvancedSettingsThresholdsController(
    store: _advancedSettingsStore,
    services: _services,
  );

  late final BootSelfCheckSettings _bootSelfCheckSettings =
      widget.bootSelfCheckSettings ??
          BootSelfCheckSettings(miscStore: _miscSettingsStore);

  late final CloudSettingsStore _cloudSettingsStore =
      widget.cloudSettingsStore ?? CloudSettingsStore();

  late final DeviceRemoteLockStore _remoteLockStore =
      widget.remoteLockStore ?? DeviceRemoteLockStore();

  late final ProcessVideoRepository _processVideoRepository =
      SqliteProcessVideoRepository();

  late final ProcessLibraryRepository _processLibraryRepository =
      widget.processLibraryRepository ?? SqliteProcessLibraryRepository();

  late final ProcessLibraryController _processLibrary =
      ProcessLibraryController(
    repository: _processLibraryRepository,
    importer: ProcessLibraryImporter(
      repository: _processLibraryRepository,
      deviceModel: widget.boardProfile.info.boardId,
      deviceModelLoader: () async =>
          (await _services.ensureProductInfo()).model,
    ),
    applier: ProcessParameterApplier(
      modbus: _services.modbus,
      interlockFailure: () async {
        final block = await LaserWorkGuard.processChangeBlock(_services);
        return switch (block) {
          null => null,
          ProcessChangeBlockReason.statusUnavailable =>
            ProcessApplyFailure.statusUnavailable,
          ProcessChangeBlockReason.laserActive =>
            ProcessApplyFailure.unsafeMachineState,
          ProcessChangeBlockReason.wireFeeding =>
            ProcessApplyFailure.wireFeedingActive,
        };
      },
    ),
  );

  late final AppIndexedClickSound _clickSound =
      AppIndexedClickSound(_soundEffectStore);

  late final CyberImeMutableRegionalLayoutProvider _regionalLayout =
      CyberImeMutableRegionalLayoutProvider();

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  late final GlobalPromptQueue _promptQueue = GlobalPromptQueue(
    navigatorKey: _navKey,
    // lws-ui: no AutoDialog / home prompts until SafetyTips done and
    // BootSelfCheck completed (HomePromptQueue + BootSelfCheckGate).
    isPumpSuppressed: () =>
        SafetyTipsGate.isActive || !BootSelfCheckGate.isCompletedInProcess,
  );

  late final WarnAlarmController _warnAlarm = WarnAlarmController(
    services: _services,
    promptQueue: _promptQueue,
    dangerousOperations: _dangerousOperationsSettings,
  );

  late final SyncFirmwareCommandWatcher _syncFirmwareCommandWatcher =
      SyncFirmwareCommandWatcher(
    services: _services,
    navigatorContext: () => _navKey.currentContext,
  );

  late final UpgradeProcessLibraryCommandWatcher
      _upgradeProcessLibraryCommandWatcher =
      UpgradeProcessLibraryCommandWatcher(
    processLibrary: _processLibrary,
  );

  late final UpgradeOtaCommandWatcher _upgradeOtaCommandWatcher =
      UpgradeOtaCommandWatcher();

  late final RgbLedPolicyDriver _rgbLedPolicy = RgbLedPolicyDriver(
    services: _services,
    warnAlarm: _warnAlarm,
    dangerous: _dangerousOperationsSettings,
  );

  final _cameraDeviceInfoCache = CameraDeviceInfoCache();

  late final JobRuntimeStatisticsRecorder _jobRuntimeStatistics =
      JobRuntimeStatisticsRecorder();

  late final CloudLocalRuntime _cloudLocalRuntime = CloudLocalRuntime(
    services: _services,
    cloudSettings: _cloudSettingsStore,
    lockStore: _remoteLockStore,
    processLibrary: _processLibrary,
    processVideoRepository: _processVideoRepository,
    commonSettings: _commonSettingsStore,
    miscSettings: _miscSettingsStore,
    soundEffectStore: _soundEffectStore,
    warnLogQuery: ({int? limit}) => _warnAlarm.log.query(limit: limit),
    cameraVersionFetch: (host) => _cameraDeviceInfoCache.fetch(host),
  );

  bool _restoreScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _soundEffectStore.warmRead();
    _miscSettingsStore.warmRead();
    _commonSettingsStore.warmRead();
    _advancedSettingsStore.warmRead();
    _thresholdsController.warmFromStore();
    _bootSelfCheckSettings.warmRead();
    _cloudSettingsStore.warmRead();
    _remoteLockStore.warmRead();
    unawaited(_processLibrary.initialize());
    final alarmLog = _warnAlarm.log;
    if (alarmLog is SqliteAlarmLogRepository) {
      _cloudLocalRuntime.attachAlarmLog(alarmLog);
    }
    _dangerousOperationsSettings.onBypassDisabled = () {
      unawaited(
        LaserWorkGuard.evaluateAndInterruptIfNeeded(
          services: _services,
          dangerous: _dangerousOperationsSettings,
          warnAlarm: _warnAlarm,
        ),
      );
    };
    _services.rgbLedPolicy = _rgbLedPolicy;
    CyberClickSoundRegistry.register(_clickSound);
    CyberImeLanguageRegistry.register(
      AppCyberImeLanguageProvider(_commonSettingsStore),
    );
    CyberImeRegionalLayoutRegistry.register(_regionalLayout);
    CyberImePhysicalKeyboard.register(
      CyberImeCallbackPhysicalKeyboardDetector(_services.keyboard.isPresent),
    );
    // Prime ALSA + sticky mpg123 so the first UI click is not cold-start.
    unawaited(_services.audio.warmClickSession());
    unawaited(_bootstrapKeyboardProfile());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Settings restore only. Modbus live poll + warn alarm start from Home
      // after boot self-check finishes (or immediately when self-check is skipped).
      unawaited(_services.restorePersistedSettingsOnce());
      unawaited(_maybeRestoreRoute());
      _services.autoSleep.arm(backlight: _services.backlight);
      SystemOtaCoordinator.instance.configure(
        navigatorKey: _navKey,
        services: _services,
        manifestUrlResolver: () => OtaManifestUrl.resolve(
          cloudSettings: _cloudSettingsStore,
          pinnedApiBase: _cloudLocalRuntime.pinnedApiBase,
        ),
        progressSink: (progress) {
          unawaited(
            _cloudLocalRuntime.emitOtaProgress(progress.toJson()),
          );
        },
      );
      _syncFirmwareCommandWatcher.start();
      _upgradeProcessLibraryCommandWatcher.start();
      _upgradeOtaCommandWatcher.start();
      unawaited(_startCloudLocalRuntime());
      unawaited(_liveWeldStreamDetect.start());
      _jobRuntimeStatistics.resume();
    });
  }

  Future<void> _startCloudLocalRuntime() async {
    _cloudLocalRuntime.onAuthError = () {
      if (!_cloudSettingsStore.cloudServicesEnabled) {
        return;
      }
      unawaited(
        DeviceRegistrationDialogs.enqueueRegistration(
          queue: _promptQueue,
          services: _services,
          onReconnect: () => _cloudLocalRuntime.reprobeAndReconnect(),
          onDismissedWithoutReconnect: () =>
              _cloudLocalRuntime.refreshUsersBindingProbe(
            notifyAuthError: false,
          ),
        ),
      );
    };
    _cloudLocalRuntime.onUsersProbe = (DeviceUsersProbeResult result) {
      if (!_cloudSettingsStore.cloudServicesEnabled || !result.unbound) {
        return;
      }
      unawaited(
        DeviceRegistrationDialogs.enqueueBindPrompt(
          queue: _promptQueue,
          services: _services,
        ),
      );
    };
    _cloudLocalRuntime.onClearAlerts = () async {
      try {
        await _warnAlarm.clearHistory();
        return true;
      } catch (e) {
        debugPrint('cloud clear_alerts failed: $e');
        return false;
      }
    };
    _cloudLocalRuntime.onRemoteLockChanged = (locked) async {
      final nav = _navKey.currentState;
      if (nav == null) {
        return;
      }
      if (locked) {
        // Eject Quick / Engineer / Monitor back to home (lws-ui parity).
        nav.popUntil((route) => route.isFirst);
        final ctx = nav.context;
        if (ctx.mounted) {
          unawaited(
            DeviceRegistrationDialogs.confirmNotLocked(
              ctx,
              _remoteLockStore,
              queue: _promptQueue,
            ),
          );
        }
      } else {
        unawaited(_promptQueue.dismiss(GlobalPromptIds.remoteLock));
      }
    };
    _cloudLocalRuntime.onForcedDisconnect = (reason) async {
      // Do not overlay Safety Tips / Boot Self-Check.
      await BootSelfCheckGate.waitUntilCompletedInProcess();
      final nav = _navKey.currentState;
      final ctx = nav?.context;
      if (ctx == null || !ctx.mounted || SafetyTipsGate.isActive) {
        return;
      }
      final l10n = AppLocalizations.of(ctx);
      final body = reason.trim().isEmpty
          ? 'Cloud disconnected this device.'
          : reason.trim();
      await TipDialogHost.showDarkPrompt<void>(
        context: ctx,
        barrierDismissible: true,
        builder: (dialogCtx) {
          return CyberPromptContent(
            title: 'Disconnected',
            body: Text(body),
            actions: [
              HmiButton(
                label: l10n?.closeText ?? 'Close',
                size: HmiButtonSize.medium,
                variant: CyberButtonVariant.primary,
                onPressed: () => Navigator.of(dialogCtx).pop(),
              ),
            ],
          );
        },
      );
    };
    await _cloudLocalRuntime.startAfterFirstFrame();
  }

  Future<void> _bootstrapKeyboardProfile() async {
    try {
      final layout = await _services.keyboard.getLayout();
      final profile = ProductKeyboardProfile.fromLayout(layout);
      _regionalLayout.profile = profile.imeProfile;
    } catch (e) {
      debugPrint('keyboard profile bootstrap failed: $e');
    }
  }

  Future<void> _maybeRestoreRoute() async {
    if (_restoreScheduled) return;
    _restoreScheduled = true;
    final token = await HmiRouteRestore.take();
    if (token == null) return;
    final route = HmiRouteRestore.namedRouteFor(token);
    if (route == null || route == AppRoutes.home) return;
    final nav = _navKey.currentState;
    if (nav == null) return;
    nav.pushNamed(
      route,
      arguments: HmiRouteRestore.wantsKeyboardPage(token)
          ? HmiRouteRestore.settingsKeyboard
          : null,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _jobRuntimeStatistics.resume();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_jobRuntimeStatistics.pause());
    }
    // Process teardown / embedder detach — leave the laser disarmed.
    // Do not clear on `paused` (auto-sleep) so a mid-session Laser Enable is
    // not silently closed when the backlight dims.
    if (state == AppLifecycleState.detached) {
      unawaited(
        _services.disarmLaserEnableForSafety(reason: 'lifecycle-detached'),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _services.disarmLaserEnableForSafety(reason: 'app-dispose'),
    );
    CyberClickSoundRegistry.register(null);
    CyberImeRegionalLayoutRegistry.register(null);
    CyberImePhysicalKeyboard.register(null);
    unawaited(_services.autoSleep.dispose());
    _services.disposeNetworkTimeSyncWatcher();
    unawaited(_jobRuntimeStatistics.dispose());
    unawaited(_warnAlarm.dispose());
    unawaited(_syncFirmwareCommandWatcher.dispose());
    unawaited(_upgradeProcessLibraryCommandWatcher.dispose());
    unawaited(_upgradeOtaCommandWatcher.dispose());
    unawaited(_rgbLedPolicy.dispose());
    if (widget.miscSettingsStore == null) {
      _miscSettingsStore.dispose();
    }
    _aiAssistanceSettings.dispose();
    unawaited(_liveWeldStreamDetect.stop());
    _dangerousOperationsSettings.dispose();
    _thresholdsController.dispose();
    unawaited(_processLibrary.close());
    _processLibrary.dispose();
    unawaited(_cloudLocalRuntime.dispose());
    _cameraDeviceInfoCache.dispose();
    if (widget.cloudSettingsStore == null) {
      _cloudSettingsStore.dispose();
    }
    if (widget.remoteLockStore == null) {
      _remoteLockStore.dispose();
    }
    if (widget.advancedSettingsStore == null) {
      _advancedSettingsStore.dispose();
    }
    super.dispose();
  }

  void _noteUserActivity() => _services.autoSleep.noteActivity();

  Widget _demoPage() {
    return P2DemoPage(
      boardProfile: _services.boardProfile,
      deviceSnReader: _services.deviceSnReader,
      sysInfo: _services.sysInfo,
      modbusClient: _services.modbus,
      audioController: _services.audio,
      backlightController: _services.backlight,
      ethernetController: _services.ethernet,
      wifiController: _services.wifi,
      httpClientController: _services.http,
      dateTimeController: _services.dateTime,
      bluetoothController: _services.bluetooth,
      skipPlatformSections: true,
      skipSettingsRestore: true,
    );
  }

  /// When embedder DPR is ~1 (Weston path), scale the widget tree to match the
  /// existing simulator's physical density.
  Widget _matchFlutterPiDensity(BuildContext context, Widget? child) {
    final content = child ?? const SizedBox.shrink();
    final mq = MediaQuery.of(context);
    final dpr = mq.devicePixelRatio;
    final isSimulator = widget.boardProfile.info.boardId == 'sim';
    final targetDpr = isSimulator
        ? _kSimulatorReferenceDevicePixelRatio
        : _kSimulatorReferenceDevicePixelRatio *
            (mq.size.longestSide / _kSimulatorReferenceLongEdgePx);
    // Already at reference density (or host/test with other DPR) — no-op.
    if ((dpr - targetDpr).abs() < 0.05) {
      return content;
    }
    if ((dpr - 1.0).abs() > 0.05) {
      return content;
    }
    final scale = targetDpr / dpr;
    final logical = Size(mq.size.width / scale, mq.size.height / scale);
    return SizedBox(
      width: mq.size.width,
      height: mq.size.height,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: logical.width,
          height: logical.height,
          child: MediaQuery(
            data: mq.copyWith(
              size: logical,
              devicePixelRatio: dpr * scale,
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _appBuilder(BuildContext context, Widget? child) {
    return ListenableBuilder(
      listenable: _services.wallClock,
      builder: (context, _) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            alwaysUse24HourFormat: _services.wallClock.use24HourFormat,
          ),
          child: SystemStatusOverlayHost(
            store: _miscSettingsStore,
            child: GpioLedOverlayHost(
              // P3.2 QEMU / sim OEM only — never on ynh960 (or other) hardware.
              enabled: widget.boardProfile.info.boardId == 'sim',
              child: _matchFlutterPiDensity(context, child),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: _services,
      child: CloudLocalRuntimeScope(
        runtime: _cloudLocalRuntime,
        child: CloudSettingsScope(
          store: _cloudSettingsStore,
          child: RemoteLockScope(
            store: _remoteLockStore,
            child: ProcessLibraryScope(
              controller: _processLibrary,
              child: GlobalPromptScope(
                queue: _promptQueue,
                child: WarnAlarmScope(
                  controller: _warnAlarm,
                  child: MiscSettingsScope(
                    store: _miscSettingsStore,
                    child: CommonSettingsScope(
                      store: _commonSettingsStore,
                      child: AdvancedSettingsScope(
                        store: _advancedSettingsStore,
                        aiAssistance: _aiAssistanceSettings,
                        dangerousOperations: _dangerousOperationsSettings,
                        thresholds: _thresholdsController,
                        child: BootSelfCheckScope(
                          settings: _bootSelfCheckSettings,
                          child: SoundEffectScope(
                            store: _soundEffectStore,
                            clickSound: _clickSound,
                            child: Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (_) => _noteUserActivity(),
                              onPointerMove: (_) {
                                // Moves reset idle only while awake; blanked wake is double-tap.
                                if (!_services.autoSleep.isBlanked) {
                                  _noteUserActivity();
                                }
                              },
                              child: ListenableBuilder(
                                listenable: _commonSettingsStore,
                                builder: (context, _) {
                                  return MaterialApp(
                                    title: 'HMI',
                                    theme: buildAppTheme(),
                                    scrollBehavior: const AppScrollBehavior(),
                                    locale: _commonSettingsStore.locale,
                                    supportedLocales: kAppSupportedLocales,
                                    localeListResolutionCallback:
                                        (locales, supported) {
                                      final preferred =
                                          locales == null || locales.isEmpty
                                              ? null
                                              : locales.first;
                                      return resolveAppLocale(
                                            preferred,
                                            supported,
                                          ) ??
                                          supported.first;
                                    },
                                    localizationsDelegates: const [
                                      AppLocalizations.delegate,
                                      GlobalMaterialLocalizations.delegate,
                                      GlobalWidgetsLocalizations.delegate,
                                      GlobalCupertinoLocalizations.delegate,
                                    ],
                                    builder: _appBuilder,
                                    navigatorKey: _navKey,
                                    navigatorObservers: [appRouteObserver],
                                    initialRoute: AppRoutes.home,
                                    onGenerateRoute: (settings) {
                                      // In-module nested routes: L/R slide.
                                      // Home → five modules: fade (below).
                                      switch (settings.name) {
                                        case AppRoutes.processVideoDetail:
                                          final videoArgs = settings.arguments;
                                          return buildAppSlideRoute<void>(
                                            settings: settings,
                                            builder: (_) => videoArgs
                                                    is ProcessVideoDetailArgs
                                                ? ProcessVideoDetailPage(
                                                    args: videoArgs)
                                                : const MonitorPage(),
                                          );
                                        case AppRoutes.aiVisionChoose:
                                          return buildAppSlideRoute<void>(
                                            settings: settings,
                                            builder: (_) =>
                                                const AiVisionVideoChoosePage(),
                                          );
                                        case AppRoutes.productDisclaimer:
                                          // lws-ui UseSafetyTipsActivity — L/R
                                          // slide over Safety Tips, not a
                                          // second dialog stacked on Home.
                                          return buildAppSlideRoute<void>(
                                            settings: settings,
                                            builder: (_) =>
                                                const ProductDisclaimerPage(),
                                          );
                                        case AppRoutes.engineerMode:
                                          final engineerArgs =
                                              settings.arguments;
                                          // Quick → Engineer handoff: slide.
                                          // Home → Engineer: fade (fall through).
                                          if (engineerArgs
                                              is EngineerModeRouteArgs) {
                                            return buildAppSlideRoute<void>(
                                              settings: settings,
                                              builder: (_) => _LockedModeGate(
                                                lockStore: _remoteLockStore,
                                                child: EngineerModePage(
                                                  initialProcessType:
                                                      engineerArgs.processType,
                                                  initialPresetUuid:
                                                      engineerArgs.presetUuid,
                                                  fromQuickHandoff: true,
                                                ),
                                              ),
                                            );
                                          }
                                      }

                                      final Widget page;
                                      switch (settings.name) {
                                        case AppRoutes.settings:
                                          page = SettingsPage(
                                            openKeyboardOnLaunch: settings
                                                    .arguments ==
                                                HmiRouteRestore
                                                    .settingsKeyboard,
                                            cameraDeviceInfoCache:
                                                _cameraDeviceInfoCache,
                                          );
                                        case AppRoutes.monitor:
                                          final monitorArgs =
                                              settings.arguments;
                                          page = MonitorPage(
                                            initialTabIndex: monitorArgs
                                                    is MonitorRouteArgs
                                                ? monitorArgs.initialTabIndex
                                                : MonitorPage
                                                    .tabWorkInformation,
                                          );
                                        case AppRoutes.quickMode:
                                          page = _LockedModeGate(
                                            lockStore: _remoteLockStore,
                                            child: const QuickModePage(),
                                          );
                                        case AppRoutes.engineerMode:
                                          page = _LockedModeGate(
                                            lockStore: _remoteLockStore,
                                            child: const EngineerModePage(),
                                          );
                                        case AppRoutes.demo:
                                          page = _demoPage();
                                        case AppRoutes.systemUpgrade:
                                          page = const SystemUpgradePage(
                                            progressOnly: true,
                                          );
                                        case AppRoutes.home:
                                        default:
                                          page = const HomePage();
                                      }
                                      return buildAppPageRoute(
                                        settings: settings,
                                        child: page,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocks Quick/Engineer when remote lock is active.
final class _LockedModeGate extends StatefulWidget {
  const _LockedModeGate({
    required this.lockStore,
    required this.child,
  });

  final DeviceRemoteLockStore lockStore;
  final Widget child;

  @override
  State<_LockedModeGate> createState() => _LockedModeGateState();
}

final class _LockedModeGateState extends State<_LockedModeGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final ok = await DeviceRegistrationDialogs.confirmNotLocked(
        context,
        widget.lockStore,
      );
      if (!ok && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
