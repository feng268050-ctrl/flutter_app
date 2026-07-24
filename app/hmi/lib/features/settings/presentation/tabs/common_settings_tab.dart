import 'dart:async';

import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/usb_otg.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
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
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Common Settings — phone/tablet list groups with chevron sub-pages.
class CommonSettingsTab extends StatefulWidget {
  const CommonSettingsTab({super.key, required this.services});

  final AppServices services;

  @override
  State<CommonSettingsTab> createState() => _CommonSettingsTabState();
}

class _CommonSettingsTabState extends State<CommonSettingsTab> {
  String _wifiValue = '';
  String _proxyValue = '';
  String _sshDebugValue = '';
  String _usbOtgValue = '';
  String _btValue = '';
  StreamSubscription<WifiConnectionState>? _wifiSub;

  AppServices get services => widget.services;

  @override
  void initState() {
    super.initState();
    _wifiSub = services.wifi.connection.listen((c) {
      if (mounted) {
        setState(() => _wifiValue = _wifiSummary(AppLocalizations.of(context)!, c));
      }
    });
    unawaited(_refreshProxy());
    unawaited(_refreshSshDebug());
    unawaited(_refreshUsbOtg());
    unawaited(_refreshBt());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _wifiValue = _wifiSummary(l10n, services.wifi.currentConnection);
    if (_proxyValue.isEmpty) {
      _proxyValue = l10n.offLabel;
    }
    if (_sshDebugValue.isEmpty) {
      _sshDebugValue = l10n.offLabel;
    }
    if (_btValue.isEmpty) {
      _btValue = l10n.offLabel;
    }
  }

  String _wifiSummary(AppLocalizations l10n, WifiConnectionState c) {
    if (c.isAssociated && c.ssid != null && c.ssid!.isNotEmpty) {
      return c.ssid!;
    }
    if (services.wifi.currentRadio != WifiRadioState.on) {
      return l10n.offLabel;
    }
    return l10n.notConnected;
  }

  String _unitLabel(AppLocalizations l10n, String unit) {
    switch (unit) {
      case CommonSettingsStore.unitImperial:
        return l10n.unitImperial;
      case CommonSettingsStore.unitMetric:
      default:
        return l10n.unitMetric;
    }
  }

  String _usbOtgLabel(AppLocalizations l10n, UsbOtgMode mode) {
    return switch (mode) {
      UsbOtgMode.debug => l10n.usbOtgModeDebug,
      UsbOtgMode.mtp => l10n.usbOtgModeMtp,
      UsbOtgMode.host => l10n.usbOtgModeHost,
    };
  }

  Future<void> _refreshProxy() async {
    try {
      final p = await services.http.getProxy();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _proxyValue = p.enabled ? '${p.host}:${p.port}' : l10n.offLabel;
      });
    } catch (_) {}
  }

  Future<void> _refreshSshDebug() async {
    try {
      final on = await services.sshDebug.isEnabled();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _sshDebugValue = on ? l10n.onLabel : l10n.offLabel);
    } catch (_) {
      if (mounted) {
        setState(() => _sshDebugValue = AppLocalizations.of(context)!.offLabel);
      }
    }
  }

  Future<void> _refreshUsbOtg() async {
    try {
      final mode = await services.usbOtg.getMode();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _usbOtgValue = _usbOtgLabel(l10n, mode));
    } catch (_) {
      if (mounted) setState(() => _usbOtgValue = '');
    }
  }

  Future<void> _refreshBt() async {
    final powered = services.bluetooth.currentAdapterInfo.powered;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _btValue = powered ? l10n.onLabel : l10n.offLabel);
  }

  @override
  void dispose() {
    unawaited(_wifiSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScrollView(
      children: [
        SettingsSectionHeader(l10n.commonSettingsGroupNetwork),
        SettingsGroup(
          children: [
            SettingsNavRow(
              title: l10n.wirelessNetworkText,
              value: _wifiValue,
              onTap: () async {
                await pushSettingsPage(
                  context,
                  WifiSettingsPage(services: services),
                );
                if (mounted) {
                  setState(() {
                    _wifiValue = _wifiSummary(
                      l10n,
                      services.wifi.currentConnection,
                    );
                  });
                }
              },
            ),
            SettingsNavRow(
              title: l10n.httpProxyTitle,
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
              title: l10n.sshDebugText,
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
              title: l10n.bluetoothText,
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
        SettingsSectionHeader(l10n.commonSettingsGroupDisplaySound),
        SettingsGroup(
          children: [
            Builder(
              builder: (context) {
                final store = CommonSettingsScope.maybeOf(context);
                if (store == null) {
                  return SettingsNavRow(
                    title: l10n.languageSettingText,
                    value: l10n.languageOptionEnglish,
                    onTap: () => pushSettingsPage(
                      context,
                      const LanguageSettingsPage(),
                    ),
                  );
                }
                return ListenableBuilder(
                  listenable: store,
                  builder: (context, _) {
                    return SettingsNavRow(
                      title: l10n.languageSettingText,
                      value: store.languageLabel,
                      onTap: () => pushSettingsPage(
                        context,
                        const LanguageSettingsPage(),
                      ),
                    );
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final store = CommonSettingsScope.maybeOf(context);
                if (store == null) {
                  return SettingsNavRow(
                    title: l10n.unitSettingText,
                    value: l10n.unitMetric,
                    onTap: () => pushSettingsPage(
                      context,
                      const UnitSettingsPage(),
                    ),
                  );
                }
                return ListenableBuilder(
                  listenable: store,
                  builder: (context, _) {
                    return SettingsNavRow(
                      title: l10n.unitSettingText,
                      value: _unitLabel(l10n, store.unit),
                      onTap: () => pushSettingsPage(
                        context,
                        const UnitSettingsPage(),
                      ),
                    );
                  },
                );
              },
            ),
            SettingsNavRow(
              title: l10n.screenBrightnessText,
              onTap: () => pushSettingsPage(
                context,
                BrightnessSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: l10n.screenOffTimeText,
              onTap: () => pushSettingsPage(
                context,
                ScreenOffSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: l10n.volumeSettingText,
              onTap: () => pushSettingsPage(
                context,
                VolumeSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: l10n.soundEffectCheck,
              value: l10n.defaultLabel,
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
              title: l10n.rgbLedText,
              onTap: () => pushSettingsPage(
                context,
                LedSettingsPage(services: services),
              ),
            ),
          ],
        ),
        SettingsSectionHeader(l10n.commonSettingsGroupDateTime),
        SettingsGroup(
          children: [
            SettingsNavRow(
              title: l10n.dateTimeSetDate,
              onTap: () => pushSettingsPage(
                context,
                DateTimeSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: l10n.dateTimeSetTime,
              onTap: () => pushSettingsPage(
                context,
                DateTimeSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: l10n.dateTimeSetTimeZone,
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
              title: l10n.mouseText,
              onTap: () => pushSettingsPage(
                context,
                MouseSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: l10n.keyboardText,
              onTap: () => pushSettingsPage(
                context,
                KeyboardSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: l10n.usbOtgText,
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
              title: l10n.ipCameraText,
              onTap: () => pushSettingsPage(
                context,
                IpCameraSettingsPage(services: services),
              ),
            ),
          ],
        ),
        SettingsSectionHeader(l10n.commonSettingsGroupMisc),
        SettingsGroup(
          children: [
            Builder(
              builder: (context) {
                final boot = BootSelfCheckScope.maybeOf(context)?.settings;
                final enabled = boot?.isEnabled ?? false;
                return SettingsSwitchRow(
                  title: l10n.showStartupSelfCheck,
                  subtitle: boot == null ? l10n.unavailable : null,
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
                  title: l10n.showSystemStatusOverlay,
                  subtitle: misc == null ? l10n.unavailable : null,
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
              title: l10n.commonSettingsShowSafetyGroundLockAlarm,
              subtitle: l10n.notPersistedYet,
              value: false,
              onChanged: null,
            ),
          ],
        ),
      ],
    );
  }
}
