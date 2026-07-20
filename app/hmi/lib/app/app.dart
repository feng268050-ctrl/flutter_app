import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/app_theme.dart';
import 'package:lws_hmi/features/home/presentation/home_page.dart';
import 'package:lws_hmi/features/monitor/presentation/monitor_page.dart';
import 'package:lws_hmi/features/settings/presentation/settings_page.dart';
import 'package:lws_hmi/ui/cyber/app_media_click_sound.dart';
import 'package:lws_hmi/ui/demo/p2_demo_page.dart';

/// Root MaterialApp: Home launcher, Settings, Monitor, hidden Demo.
class LwsHmiApp extends StatefulWidget {
  const LwsHmiApp({
    super.key,
    required this.boardProfile,
    this.services,
  });

  final BoardProfile boardProfile;

  /// Optional override for tests (inject fakes).
  final AppServices? services;

  @override
  State<LwsHmiApp> createState() => _LwsHmiAppState();
}

class _LwsHmiAppState extends State<LwsHmiApp> {
  late final AppServices _services =
      widget.services ?? AppServices(boardProfile: widget.boardProfile);

  late final AppMediaClickSound _clickSound = AppMediaClickSound();

  @override
  void initState() {
    super.initState();
    CyberClickSoundRegistry.register(_clickSound);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Settings restore only — do not start Modbus here. Home / Demo pull it
      // when needed so the first Home frames are not fighting RTU poll.
      unawaited(_services.restorePersistedSettingsOnce());
    });
  }

  @override
  void dispose() {
    CyberClickSoundRegistry.register(null);
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

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: _services,
      child: MaterialApp(
        title: 'HMI',
        theme: buildAppTheme(),
        scrollBehavior: const AppScrollBehavior(),
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
    );
  }
}
