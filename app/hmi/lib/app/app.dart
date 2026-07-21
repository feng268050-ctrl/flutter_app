import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/app_theme.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_scope.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_settings.dart';
import 'package:lws_hmi/features/home/presentation/home_page.dart';
import 'package:lws_hmi/features/monitor/presentation/monitor_page.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_store.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_scope.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';
import 'package:lws_hmi/features/settings/presentation/settings_page.dart';
import 'package:lws_hmi/features/system_status/presentation/system_status_overlay_host.dart';
import 'package:lws_hmi/ui/cyber/app_indexed_click_sound.dart';
import 'package:lws_hmi/ui/demo/p2_demo_page.dart';

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
    this.bootSelfCheckSettings,
  });

  final BoardProfile boardProfile;

  /// Optional override for tests (inject fakes).
  final AppServices? services;

  /// Optional override for tests (inject fake prefs path / store).
  final SoundEffectStore? soundEffectStore;

  /// Optional override for tests (inject fake Misc JSON path / store).
  final MiscSettingsStore? miscSettingsStore;

  /// Optional override for tests (disable overlay / fake prefs path).
  final BootSelfCheckSettings? bootSelfCheckSettings;

  @override
  State<LwsHmiApp> createState() => _LwsHmiAppState();
}

class _LwsHmiAppState extends State<LwsHmiApp> {
  late final AppServices _services =
      widget.services ?? AppServices(boardProfile: widget.boardProfile);

  late final SoundEffectStore _soundEffectStore =
      widget.soundEffectStore ?? SoundEffectStore();

  late final MiscSettingsStore _miscSettingsStore =
      widget.miscSettingsStore ?? MiscSettingsStore();

  late final BootSelfCheckSettings _bootSelfCheckSettings =
      widget.bootSelfCheckSettings ??
          BootSelfCheckSettings(miscStore: _miscSettingsStore);

  late final AppIndexedClickSound _clickSound = AppIndexedClickSound(
    _soundEffectStore,
    mediaAudio: _services.audio,
  );

  @override
  void initState() {
    super.initState();
    _soundEffectStore.warmRead();
    _miscSettingsStore.warmRead();
    _bootSelfCheckSettings.warmRead();
    CyberClickSoundRegistry.register(_clickSound);
    CyberImeLanguageRegistry.register(
      const CyberImeFixedLanguageProvider(CyberImeGlobalKind.english),
    );
    // Prime ALSA + sticky mpg123 so the first UI click is not cold-start.
    unawaited(_services.audio.warmClickSession());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Settings restore only — do not start Modbus here. Home / Demo pull it
      // when needed so the first Home frames are not fighting RTU poll.
      unawaited(_services.restorePersistedSettingsOnce());
    });
  }

  @override
  void dispose() {
    CyberClickSoundRegistry.register(null);
    if (widget.miscSettingsStore == null) {
      _miscSettingsStore.dispose();
    }
    super.dispose();
  }

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
      sshDebugController: _services.sshDebug,
      usbDebugController: _services.usbDebug,
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
      child: MiscSettingsScope(
        store: _miscSettingsStore,
        child: BootSelfCheckScope(
          settings: _bootSelfCheckSettings,
          child: SoundEffectScope(
            store: _soundEffectStore,
            clickSound: _clickSound,
            child: MaterialApp(
              title: 'HMI',
              theme: buildAppTheme(),
              scrollBehavior: const AppScrollBehavior(),
              builder: _appBuilder,
              initialRoute: AppRoutes.home,
              onGenerateRoute: (settings) {
                final Widget page;
                switch (settings.name) {
                  case AppRoutes.settings:
                    page = const SettingsPage();
                  case AppRoutes.monitor:
                    page = const MonitorPage();
                  case AppRoutes.demo:
                    page = _demoPage();
                  case AppRoutes.home:
                  default:
                    page = const HomePage();
                }
                return buildAppPageRoute(settings: settings, child: page);
              },
            ),
          ),
        ),
      ),
    );
  }
}
