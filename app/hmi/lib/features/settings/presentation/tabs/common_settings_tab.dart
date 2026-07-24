import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/usb_otg.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_scope.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/pages/bluetooth_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/brightness_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/date_time_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/http_proxy_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/ip_camera_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/keyboard_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/language_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/lan_ssh_debug_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/led_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/mouse_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/screen_off_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/sound_effect_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/unit_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/usb_otg_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/volume_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/wifi_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

/// Common Settings — phone/tablet list groups with chevron sub-pages.
class CommonSettingsTab extends StatefulWidget {
  const CommonSettingsTab({super.key, required this.services});

  final AppServices services;

  @override
  State<CommonSettingsTab> createState() => _CommonSettingsTabState();
}

class _CommonSettingsTabState extends State<CommonSettingsTab> {
  String _wifiValue = '';
  String _proxyValue = 'Off';
  String _sshDebugValue = 'Off';
  String _usbOtgValue = '';
  String _btValue = '';
  StreamSubscription<WifiConnectionState>? _wifiSub;

  AppServices get services => widget.services;

  @override
  void initState() {
    super.initState();
    _wifiValue = _wifiSummary(services.wifi.currentConnection);
    _wifiSub = services.wifi.connection.listen((c) {
      if (mounted) setState(() => _wifiValue = _wifiSummary(c));
    });
    unawaited(_refreshProxy());
    unawaited(_refreshSshDebug());
    unawaited(_refreshUsbOtg());
    unawaited(_refreshBt());
  }

  String _wifiSummary(WifiConnectionState c) {
    if (c.isAssociated && c.ssid != null && c.ssid!.isNotEmpty) {
      return c.ssid!;
    }
    if (services.wifi.currentRadio != WifiRadioState.on) {
      return 'Off';
    }
    return 'Not Connected';
  }

  Future<void> _refreshProxy() async {
    try {
      final p = await services.http.getProxy();
      if (!mounted) return;
      setState(() {
        _proxyValue = p.enabled
            ? '${p.host}:${p.port}'
            : 'Off';
      });
    } catch (_) {}
  }

  Future<void> _refreshSshDebug() async {
    try {
      final on = await services.sshDebug.isEnabled();
      if (!mounted) return;
      setState(() => _sshDebugValue = on ? 'On' : 'Off');
    } catch (_) {
      if (mounted) setState(() => _sshDebugValue = 'Off');
    }
  }

  Future<void> _refreshUsbOtg() async {
    try {
      final mode = await services.usbOtg.getMode();
      if (!mounted) return;
      setState(() {
        _usbOtgValue = switch (mode) {
          UsbOtgMode.debug => 'Debug',
          UsbOtgMode.mtp => 'MTP',
          UsbOtgMode.host => 'Host',
        };
      });
    } catch (_) {
      if (mounted) setState(() => _usbOtgValue = '');
    }
  }

  Future<void> _refreshBt() async {
    final powered = services.bluetooth.currentAdapterInfo.powered;
    if (!mounted) return;
    setState(() => _btValue = powered ? 'On' : 'Off');
  }

  @override
  void dispose() {
    unawaited(_wifiSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScrollView(
      children: [
        const SettingsSectionHeader('Network'),
        SettingsGroup(
          children: [
            SettingsNavRow(
              title: 'Wireless Network',
              value: _wifiValue,
              onTap: () async {
                await pushSettingsPage(
                  context,
                  WifiSettingsPage(services: services),
                );
                if (mounted) {
                  setState(() {
                    _wifiValue =
                        _wifiSummary(services.wifi.currentConnection);
                  });
                }
              },
            ),
            SettingsNavRow(
              title: 'HTTP Proxy',
              value: _proxyValue,
              onTap: () async {
                await pushSettingsPage(
                  context,
                  HttpProxySettingsPage(services: services),
                );
                await _refreshProxy();
              },
            ),
            SettingsNavRow(
              title: 'SSH Debug',
              value: _sshDebugValue,
              onTap: () async {
                await pushSettingsPage(
                  context,
                  LanSshDebugSettingsPage(services: services),
                );
                await _refreshSshDebug();
              },
            ),
            SettingsNavRow(
              title: 'Bluetooth',
              value: _btValue,
              onTap: () async {
                await pushSettingsPage(
                  context,
                  BluetoothSettingsPage(services: services),
                );
                await _refreshBt();
              },
            ),
          ],
        ),
        const SettingsSectionHeader('Display & Sound'),
        SettingsGroup(
          children: [
            SettingsNavRow(
              title: 'Language',
              value: 'English',
              onTap: () => pushSettingsPage(
                context,
                const LanguageSettingsPage(),
              ),
            ),
            SettingsNavRow(
              title: 'Unit',
              value: 'Metric',
              onTap: () => pushSettingsPage(
                context,
                const UnitSettingsPage(),
              ),
            ),
            SettingsNavRow(
              title: 'Screen Brightness',
              onTap: () => pushSettingsPage(
                context,
                BrightnessSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: 'Screen-off Time',
              onTap: () => pushSettingsPage(
                context,
                ScreenOffSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: 'Volume',
              onTap: () => pushSettingsPage(
                context,
                VolumeSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: 'Sound Effect',
              value: 'Default',
              onTap: () => pushSettingsPage(
                context,
                const SoundEffectSettingsPage(),
              ),
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsNavRow(
              title: 'RGB LED',
              onTap: () => pushSettingsPage(
                context,
                LedSettingsPage(services: services),
              ),
            ),
          ],
        ),
        const SettingsSectionHeader('Date & Time'),
        SettingsGroup(
          children: [
            SettingsNavRow(
              title: 'Date',
              onTap: () => pushSettingsPage(
                context,
                DateTimeSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: 'Time',
              onTap: () => pushSettingsPage(
                context,
                DateTimeSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: 'Time Zone',
              onTap: () => pushSettingsPage(
                context,
                DateTimeSettingsPage(services: services),
              ),
            ),
          ],
        ),
        const SettingsSectionHeader('Input'),
        SettingsGroup(
          children: [
            SettingsNavRow(
              title: 'Mouse',
              onTap: () => pushSettingsPage(
                context,
                MouseSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: 'Keyboard',
              onTap: () => pushSettingsPage(
                context,
                KeyboardSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: 'USB OTG',
              value: _usbOtgValue.isEmpty ? null : _usbOtgValue,
              onTap: () async {
                await pushSettingsPage(
                  context,
                  UsbOtgSettingsPage(services: services),
                );
                await _refreshUsbOtg();
              },
            ),
            SettingsNavRow(
              title: 'IP Camera',
              onTap: () => pushSettingsPage(
                context,
                IpCameraSettingsPage(services: services),
              ),
            ),
          ],
        ),
        const SettingsSectionHeader('Misc'),
        SettingsGroup(
          children: [
            Builder(
              builder: (context) {
                final boot = BootSelfCheckScope.maybeOf(context)?.settings;
                final enabled = boot?.isEnabled ?? false;
                return SettingsSwitchRow(
                  title: 'Show Startup Self-Check',
                  subtitle: boot == null ? 'Unavailable' : null,
                  value: enabled,
                  onChanged: boot == null
                      ? null
                      : (v) {
                          unawaited(() async {
                            await boot.setEnabled(v);
                            if (mounted) setState(() {});
                          }());
                        },
                );
              },
            ),
            Builder(
              builder: (context) {
                final misc = MiscSettingsScope.maybeOf(context);
                final enabled = misc?.showSystemStatusOverlay ?? false;
                return SettingsSwitchRow(
                  title: 'Show System Status Overlay',
                  subtitle: misc == null ? 'Unavailable' : null,
                  value: enabled,
                  onChanged: misc == null
                      ? null
                      : (v) {
                          unawaited(() async {
                            await misc.setShowSystemStatusOverlay(v);
                            if (mounted) setState(() {});
                          }());
                        },
                );
              },
            ),
            SettingsSwitchRow(
              title: 'Show Ground Lock Alarm',
              subtitle: 'Not persisted yet',
              value: false,
              onChanged: null,
            ),
          ],
        ),
      ],
    );
  }
}
