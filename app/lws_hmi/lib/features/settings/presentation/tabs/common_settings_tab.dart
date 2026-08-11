import 'dart:async';

import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/locale.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_scope.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/pages/cloud_services_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/country_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/date_time_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/display_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/http_proxy_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/ip_camera_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/language_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/led_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/sound_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/unit_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/pages/wifi_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime_scope.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_scope.dart';

/// Common Settings — CyberUI untitled cards (nav rows → sub-pages).
///
/// **Role:** HMI Settings is the simplified + product-customized Settings subset.
/// Full platform/system Settings live in OS Settings (`app/os_settings`).
/// Policy: `docs/settings-apps-roles.md`.
///
/// OS Settings seat: Device Info → tap Device SN 5× (`switch-to-os-settings`).
/// Ethernet / Bluetooth / SSH / Keyboard / Mouse / USB OTG / Cloud Env /
/// Power Mode live in OS Settings, not product HMI.
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
  /// RGB LED row kept for product reopen; hidden from Common Settings for now.
  static const bool _showRgbLed = false;

  /// Semantic trailing state — resolve labels in [build] so locale switches
  /// refresh Off/On without leaving the tab.
  bool _proxyEnabled = false;
  String _proxyEndpoint = '';
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
      _wifiSub = services.wifi.connection.listen((_) {
        if (!mounted) return;
        setState(() {});
      });
      unawaited(_refreshProxy());
      unawaited(_refreshBrightness());
      unawaited(_refreshVolume());
      unawaited(_refreshDateTime());
    });
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

  String _unitLabel(AppLocalizations l10n, UnitSystem unit) {
    switch (unit) {
      case UnitSystem.imperial:
        return l10n.unitOptionImperial;
      case UnitSystem.metric:
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

  String _proxyTrailing(AppLocalizations l10n) {
    if (!_proxyEnabled) {
      return l10n.offLabel;
    }
    return _proxyEndpoint.isEmpty ? l10n.onLabel : _proxyEndpoint;
  }

  Future<void> _refreshProxy() async {
    try {
      final p = await services.http.getProxy();
      if (!mounted) return;
      setState(() {
        _proxyEnabled = p.enabled;
        _proxyEndpoint =
            p.enabled && p.host.isNotEmpty ? '${p.host}:${p.port}' : '';
      });
    } catch (_) {}
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
    final wifiValue = _wifiSummary(l10n, services.wifi.currentConnection);
    final proxyValue = _proxyTrailing(l10n);

    return SettingsScrollView(
      children: [
        // Network — lws-ui `top-bottom`
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.topBottom,
          children: [
            SettingsNavRow(
              // lws-ui `wifi_network_text`
              title: l10n.wifiNetworkText,
              value: wifiValue,
              onTap: () async {
                await pushSettingsPage(
                  context,
                  WifiSettingsPage(services: services),
                );
                if (mounted) {
                  setState(() {});
                }
              },
            ),
            SettingsNavRow(
              // lws-ui `http_proxy_settings_title`
              title: l10n.httpProxySettingsTitle,
              value: proxyValue,
              onTap: () async {
                await pushSettingsPage(
                  context,
                  HttpProxySettingsPage(services: services),
                );
                await _refreshProxy();
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
        // Date & Time — before Country/Region
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
        // Locale — Country / Language / Unit
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
          children: [
            if (store == null)
              SettingsNavRow(
                title: l10n.countrySettingText,
                value: CountrySettingsPage.countryLabel(
                  context,
                  RegionCatalog.defaultRegion,
                ),
                onTap: () => pushSettingsPage(
                  context,
                  CountrySettingsPage(services: services),
                ),
              )
            else
              ListenableBuilder(
                listenable: store,
                builder: (context, _) {
                  return SettingsNavRow(
                    title: l10n.countrySettingText,
                    value: CountrySettingsPage.countryLabel(
                      context,
                      store.region,
                    ),
                    onTap: () => pushSettingsPage(
                      context,
                      CountrySettingsPage(services: services),
                    ),
                  );
                },
              ),
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
                    value: store.language.endonym,
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
          ],
        ),
        // Display + Sound + Camera (+ optional RGB LED, hidden for now)
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.topRightBottomLeft,
          children: [
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
            if (_showRgbLed)
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
