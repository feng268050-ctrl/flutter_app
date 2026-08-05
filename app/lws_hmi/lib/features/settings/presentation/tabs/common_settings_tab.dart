import 'dart:async';

import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/usb_otg.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_scope.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/pages/bluetooth_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/cloud_services_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/date_time_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/display_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/http_proxy_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/ip_camera_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/keyboard_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/language_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/lan_ssh_debug_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/led_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/mouse_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/sound_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/unit_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/usb_otg_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/wifi_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime_scope.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_scope.dart';

/// Common Settings — CyberUI untitled cards (nav rows → sub-pages).
class CommonSettingsTab extends StatefulWidget {
  const CommonSettingsTab({
    super.key,
    required this.services,
    this.cameraDeviceInfoCache,
  });

  final AppServices services;
  final CameraDeviceInfoCache? cameraDeviceInfoCache;

  @override
  State<CommonSettingsTab> createState() => _CommonSettingsTabState();
}

class _CommonSettingsTabState extends State<CommonSettingsTab> {
  String _wifiValue = '';
  String _proxyValue = '';
  String _sshDebugValue = '';
  String _usbOtgValue = '';
  String _btValue = '';
  String _brightnessValue = '';
  String _volumeValue = '';
  TimeSyncMode? _dateTimeMode;
  StreamSubscription<WifiConnectionState>? _wifiSub;

  AppServices get services => widget.services;

  @override
  void initState() {
    super.initState();
    // AppLocalizations / Theme.of are illegal during initState. Defer any
    // work that reads InheritedWidgets (including sync stream emits).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _wifiSub = services.wifi.connection.listen((c) {
        if (!mounted) return;
        setState(
          () => _wifiValue = _wifiSummary(AppLocalizations.of(context)!, c),
        );
      });
      unawaited(_refreshProxy());
      unawaited(_refreshSshDebug());
      unawaited(_refreshUsbOtg());
      unawaited(_refreshBt());
      unawaited(_refreshBrightness());
      unawaited(_refreshVolume());
      unawaited(_refreshDateTime());
    });
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

  String _usbOtgLabel(AppLocalizations l10n, UsbOtgMode mode) {
    return switch (mode) {
      UsbOtgMode.debug => l10n.usbOtgModeDebug,
      UsbOtgMode.mtp => l10n.usbOtgModeMtp,
      UsbOtgMode.host => l10n.usbOtgModeHost,
    };
  }

  String _unitLabel(AppLocalizations l10n, String unit) {
    switch (unit) {
      case CommonSettingsStore.unitImperial:
        // lws-ui `unit_option_imperial`
        return l10n.unitOptionImperial;
      case CommonSettingsStore.unitMetric:
      default:
        // lws-ui `unit_option_metric`
        return l10n.unitOptionMetric;
    }
  }

  String? _dateTimeSummary(AppLocalizations l10n) {
    final mode = _dateTimeMode;
    if (mode == null) return null;
    return mode == TimeSyncMode.network
        ? l10n.dateTimeAutomatic
        : l10n.dateTimeModeManual;
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

  Future<void> _refreshBrightness() async {
    try {
      final v = await services.backlight.getBrightnessPercent();
      if (!mounted) return;
      setState(() => _brightnessValue = '$v%');
    } catch (_) {
      if (mounted) setState(() => _brightnessValue = '');
    }
  }

  Future<void> _refreshVolume() async {
    try {
      final v = await services.audio.getVolumePercent();
      if (!mounted) return;
      setState(() => _volumeValue = '$v%');
    } catch (_) {
      if (mounted) setState(() => _volumeValue = '');
    }
  }

  Future<void> _refreshDateTime() async {
    try {
      final mode = await services.dateTime.getSyncMode();
      if (!mounted) return;
      setState(() => _dateTimeMode = mode);
    } catch (_) {
      if (mounted) setState(() => _dateTimeMode = null);
    }
  }

  @override
  void dispose() {
    unawaited(_wifiSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final store = CommonSettingsScope.maybeOf(context);

    return SettingsScrollView(
      children: [
        // Network — lws-ui `top-bottom`
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.topBottom,
          children: [
            SettingsNavRow(
              // lws-ui `wifi_network_text`
              title: l10n.wifiNetworkText,
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
              // lws-ui `http_proxy_settings_title`
              title: l10n.httpProxySettingsTitle,
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
            Builder(
              builder: (context) {
                final cloudStore = CloudSettingsScope.maybeOf(context);
                final runtime = CloudLocalRuntimeScope.maybeOf(context);
                if (cloudStore == null) {
                  return SettingsNavRow(
                    title: l10n.cloudServicesText,
                    value: l10n.offLabel,
                  );
                }
                return ListenableBuilder(
                  listenable: cloudStore,
                  builder: (context, _) => SettingsNavRow(
                    title: l10n.cloudServicesText,
                    value: cloudServicesNetworkSummary(l10n, cloudStore),
                    onTap: () async {
                      await pushSettingsPage(
                        context,
                        CloudServicesSettingsPage(
                          cloudSettings: cloudStore,
                          runtime: runtime,
                        ),
                      );
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
        // Display & Sound — lws-ui `top-left-bottom-right`
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
          children: [
            if (store == null)
              SettingsNavRow(
                title: l10n.languageSettingText,
                value: l10n.languageOptionEnglish,
                onTap: () => pushSettingsPage(
                  context,
                  const LanguageSettingsPage(),
                ),
              )
            else
              ListenableBuilder(
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
              ),
            if (store == null)
              SettingsNavRow(
                title: l10n.unitSettingText,
                value: l10n.unitOptionMetric,
                onTap: () => pushSettingsPage(
                  context,
                  const UnitSettingsPage(),
                ),
              )
            else
              ListenableBuilder(
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
              ),
            SettingsNavRow(
              title: l10n.screenSettings,
              value: _brightnessValue.isEmpty ? null : _brightnessValue,
              onTap: () async {
                await pushSettingsPage(
                  context,
                  DisplaySettingsPage(services: services),
                );
                await _refreshBrightness();
              },
            ),
            SettingsNavRow(
              title: l10n.soundSettings,
              value: _volumeValue.isEmpty ? null : _volumeValue,
              onTap: () async {
                await pushSettingsPage(
                  context,
                  SoundSettingsPage(services: services),
                );
                await _refreshVolume();
              },
            ),
          ],
        ),
        // RGB LED + Camera — before Date & Time
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.topRightBottomLeft,
          children: [
            SettingsNavRow(
              title: l10n.rgbLedText,
              onTap: () => pushSettingsPage(
                context,
                LedSettingsPage(services: services),
              ),
            ),
            SettingsNavRow(
              title: l10n.ipCameraText,
              onTap: () => pushSettingsPage(
                context,
                IpCameraSettingsPage(
                  services: services,
                  deviceInfoCache: widget.cameraDeviceInfoCache,
                ),
              ),
            ),
          ],
        ),
        // Date & Time — lws-ui `bottom-left-top-right`
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.bottomLeftTopRight,
          children: [
            SettingsNavRow(
              title: l10n.dateTimeSettings,
              value: _dateTimeSummary(l10n),
              onTap: () async {
                await pushSettingsPage(
                  context,
                  DateTimeSettingsPage(services: services),
                );
                await _refreshDateTime();
              },
            ),
          ],
        ),
        // Input
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.leftRight,
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
          ],
        ),
        // Misc — lws-ui `top-bottom`
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.topBottom,
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
            Builder(
              builder: (context) {
                final misc = MiscSettingsScope.maybeOf(context);
                final enabled = misc?.showGroundLockAlarm ?? false;
                return SettingsSwitchRow(
                  title: l10n.commonSettingsShowSafetyGroundLockAlarm,
                  subtitle: misc == null ? l10n.unavailable : null,
                  value: enabled,
                  onChanged: misc == null
                      ? null
                      : (v) {
                          unawaited(() async {
                            await misc.setShowGroundLockAlarm(v);
                            if (mounted) setState(() {});
                          }());
                        },
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
