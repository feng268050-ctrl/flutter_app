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
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_scope.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_settings.dart';
import 'package:lws_hmi/features/home/presentation/home_page.dart';
import 'package:lws_hmi/features/monitor/presentation/monitor_page.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_repository.dart';
import 'package:lws_hmi/features/process_library/infrastructure/sqlite_process_library_repository.dart';
import 'package:lws_hmi/features/process_library/presentation/process_library_page.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_thresholds_controller.dart';
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
import 'package:lws_hmi/features/system_status/presentation/system_status_overlay_host.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/l10n/app_locales.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/cyber/app_indexed_click_sound.dart';
import 'package:lws_hmi/ui/demo/p2_demo_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// flutter-pi on ynh960 reports ~1.358 DPR (logical ≈942×589 on 1280×800).
/// Weston+eLinux defaults to DPR 1.0; `--force-scale-factor` blacks the frame.
/// Scale the widget tree instead so icons/buttons/text match flutter-pi.
const double _kFlutterPiDevicePixelRatio = 1.3582342954159592;

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

  @override
  State<LwsHmiApp> createState() => _LwsHmiAppState();
}

class _LwsHmiAppState extends State<LwsHmiApp> {
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
      isSafeToApply: () => LaserWorkGuard.isProcessChangeSafe(_services),
    ),
  );

  late final AppIndexedClickSound _clickSound =
      AppIndexedClickSound(_soundEffectStore);

  late final CyberImeMutableRegionalLayoutProvider _regionalLayout =
      CyberImeMutableRegionalLayoutProvider();

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  late final WarnAlarmController _warnAlarm = WarnAlarmController(
    services: _services,
    navigatorKey: _navKey,
    dangerousOperations: _dangerousOperationsSettings,
  );

  bool _restoreScheduled = false;

  @override
  void initState() {
    super.initState();
    _soundEffectStore.warmRead();
    _miscSettingsStore.warmRead();
    _commonSettingsStore.warmRead();
    _advancedSettingsStore.warmRead();
    _thresholdsController.warmFromStore();
    _bootSelfCheckSettings.warmRead();
    unawaited(_processLibrary.initialize());
    _dangerousOperationsSettings.onBypassDisabled = () {
      unawaited(
        LaserWorkGuard.evaluateAndInterruptIfNeeded(
          services: _services,
          dangerous: _dangerousOperationsSettings,
          warnAlarm: _warnAlarm,
        ),
      );
    };
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
    });
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
  void dispose() {
    CyberClickSoundRegistry.register(null);
    CyberImeRegionalLayoutRegistry.register(null);
    CyberImePhysicalKeyboard.register(null);
    unawaited(_services.autoSleep.dispose());
    unawaited(_warnAlarm.dispose());
    if (widget.miscSettingsStore == null) {
      _miscSettingsStore.dispose();
    }
    _aiAssistanceSettings.dispose();
    _dangerousOperationsSettings.dispose();
    _thresholdsController.dispose();
    unawaited(_processLibrary.close());
    _processLibrary.dispose();
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

  /// When embedder DPR is ~1 (Weston path), layout at flutter-pi logical size
  /// and FittedBox-scale up so physical pixels match flutter-pi density.
  Widget _matchFlutterPiDensity(BuildContext context, Widget? child) {
    final content = child ?? const SizedBox.shrink();
    final mq = MediaQuery.of(context);
    final dpr = mq.devicePixelRatio;
    // Already at flutter-pi density (or host/test with other DPR) — no-op.
    if ((dpr - _kFlutterPiDevicePixelRatio).abs() < 0.05) {
      return content;
    }
    if ((dpr - 1.0).abs() > 0.05) {
      return content;
    }
    final scale = _kFlutterPiDevicePixelRatio / dpr;
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
    return SystemStatusOverlayHost(
      store: _miscSettingsStore,
      child: _matchFlutterPiDensity(context, child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: _services,
      child: ProcessLibraryScope(
        controller: _processLibrary,
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
                            initialRoute: AppRoutes.home,
                            onGenerateRoute: (settings) {
                              final Widget page;
                              switch (settings.name) {
                                case AppRoutes.settings:
                                  page = SettingsPage(
                                    openKeyboardOnLaunch:
                                        settings.arguments ==
                                            HmiRouteRestore
                                                .settingsKeyboard,
                                  );
                                case AppRoutes.monitor:
                                  page = const MonitorPage();
                                case AppRoutes.quickMode:
                                  page = const ProcessLibraryPage(
                                    mode: ProcessLibraryPageMode.quick,
                                  );
                                case AppRoutes.engineerMode:
                                  page = const ProcessLibraryPage(
                                    mode: ProcessLibraryPageMode.engineer,
                                  );
                                case AppRoutes.demo:
                                  page = _demoPage();
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
    );
  }
}
