import 'dart:async';

import 'package:cyber_hal/bluetooth.dart';
import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/locale.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/usb_otg.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/app/services.dart';
import 'package:os_settings/chrome/exit_to_hmi.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/cloud/cloud_environment_tier.dart';
import 'package:os_settings/l10n/app_localizations.dart';
import 'package:os_settings/shell/os_settings_nav.dart';
import 'package:os_settings/util/keyboard_profile.dart';
import 'package:os_settings/util/product_display.dart';
import 'package:os_settings/util/storage_capacity.dart';

/// OS Settings root — same layout in landscape and portrait.
///
/// Matches product HMI Device Info / General Settings: **multiple untitled**
/// frosted [SettingsGroup] cards of [SettingsNavRow] that push detail pages.
/// Logical plan group names are Dart comments only — never section headers.
///
/// Trailing [SettingsNavRow.value] summaries match HMI Common Settings
/// (SSID / Off / %, Automatic, endonym, …) and extend the same pattern to
/// migrated rows (Ethernet, Bluetooth, SSH, Keyboard, Mouse, USB OTG).
class OsSettingsShell extends StatefulWidget {
  const OsSettingsShell({super.key});

  @override
  State<OsSettingsShell> createState() => _OsSettingsShellState();
}

class _OsSettingsShellState extends State<OsSettingsShell> {
  String? _aboutSummary;
  String? _osSummary;
  String? _storageSummary;
  String? _ethernetSummary;
  bool _proxyEnabled = false;
  String _proxyEndpoint = '';
  String? _sshSummary;
  TimeSyncMode? _dateTimeMode;
  String? _countrySummary;
  String? _languageSummary;
  String? _unitSummary;
  String? _displaySummary;
  String? _soundSummary;
  String? _powerModeSummary;
  String? _keyboardSummary;
  String? _mouseSummary;
  String? _usbOtgSummary;
  String? _cloudEnvironmentSummary;

  StreamSubscription<WifiConnectionState>? _wifiConnSub;
  StreamSubscription<WifiRadioState>? _wifiRadioSub;
  StreamSubscription<EthAdminState>? _ethAdminSub;
  StreamSubscription<EthLinkState>? _ethLinkSub;
  StreamSubscription<BluetoothAdapterState>? _btStateSub;
  StreamSubscription<BluetoothAdapterInfo>? _btInfoSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final services = OsSettingsScope.of(context);
      _wifiConnSub = services.wifi().connection.listen((_) {
        if (mounted) setState(() {});
      });
      _wifiRadioSub = services.wifi().radio.listen((_) {
        if (mounted) setState(() {});
      });
      _ethAdminSub = services.ethernet().admin.listen((_) {
        if (mounted) unawaited(_refreshEthernet());
      });
      _ethLinkSub = services.ethernet().link.listen((_) {
        if (mounted) unawaited(_refreshEthernet());
      });
      _btStateSub = services.bluetooth().adapterState.listen((_) {
        if (mounted) setState(() {});
      });
      _btInfoSub = services.bluetooth().adapterInfo.listen((_) {
        if (mounted) setState(() {});
      });
      unawaited(_loadSummaries());
    });
  }

  @override
  void dispose() {
    unawaited(_wifiConnSub?.cancel() ?? Future<void>.value());
    unawaited(_wifiRadioSub?.cancel() ?? Future<void>.value());
    unawaited(_ethAdminSub?.cancel() ?? Future<void>.value());
    unawaited(_ethLinkSub?.cancel() ?? Future<void>.value());
    unawaited(_btStateSub?.cancel() ?? Future<void>.value());
    unawaited(_btInfoSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _loadSummaries() async {
    final services = OsSettingsScope.of(context);
    await Future.wait([
      _refreshAbout(services),
      _refreshOsAndStorage(services),
      _refreshEthernet(),
      _refreshProxy(services),
      _refreshSsh(services),
      _refreshDateTime(services),
      _refreshLocale(services),
      _refreshDisplay(services),
      _refreshSound(services),
      _refreshPowerMode(services),
      _refreshKeyboard(services),
      _refreshMouse(services),
      _refreshUsbOtg(services),
      _refreshCloudEnvironment(),
    ]);
  }

  Future<void> _refreshCloudEnvironment() async {
    final l10n = AppLocalizations.of(context)!;
    final store = OsSettingsScope.cloudSettingsOf(context);
    store.warmRead();
    if (!mounted) return;
    setState(() {
      _cloudEnvironmentSummary = switch (store.environmentTier) {
        CloudEnvironmentTier.prod => l10n.cloudEnvironmentTierProd,
        CloudEnvironmentTier.test => l10n.cloudEnvironmentTierTest,
      };
    });
  }

  Future<void> _refreshAbout(OsSettingsServices services) async {
    try {
      final product = await services.productInfo();
      final display = productDeviceModelDisplay(product.brand, product.model);
      if (!mounted) return;
      setState(() {
        _aboutSummary = display == kUnavailableDisplay ? null : display;
      });
    } catch (_) {
      try {
        final snap = await services.sysInfo().snapshot();
        final display = productDeviceModelDisplay(snap.brand, snap.model);
        if (!mounted) return;
        setState(() {
          _aboutSummary = display == kUnavailableDisplay ? null : display;
        });
      } catch (_) {}
    }
  }

  Future<void> _refreshOsAndStorage(OsSettingsServices services) async {
    try {
      final snap = await services.sysInfo().snapshot();
      final versions = await services.platformVersions().snapshot();
      final storage = summarizeStorage(snap.storage);
      if (!mounted) return;
      setState(() {
        _osSummary = versions.operatingSystem;
        _storageSummary =
            storage.hasData ? storageSummaryLine(storage) : null;
      });
    } catch (_) {
      try {
        final versions = await services.platformVersions().snapshot();
        if (!mounted) return;
        setState(() => _osSummary = versions.operatingSystem);
      } catch (_) {}
    }
  }

  String _wifiSummary(OsSettingsServices services, AppLocalizations l10n) {
    final c = services.wifi().currentConnection;
    if (c.isAssociated && c.ssid != null && c.ssid!.isNotEmpty) {
      return c.ssid!;
    }
    if (services.wifi().currentRadio != WifiRadioState.on) {
      return l10n.offLabel;
    }
    return l10n.notConnected;
  }

  Future<void> _refreshEthernet() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final eth = OsSettingsScope.of(context).ethernet();
      final admin = eth.currentAdmin;
      if (admin == EthAdminState.off) {
        if (!mounted) return;
        setState(() => _ethernetSummary = l10n.offLabel);
        return;
      }
      final cfg = await eth.getIpv4Config();
      if (!mounted) return;
      final addr = cfg.address.trim();
      setState(() {
        _ethernetSummary = addr.isNotEmpty ? addr : l10n.notConnected;
      });
    } catch (_) {
      if (mounted) setState(() => _ethernetSummary = null);
    }
  }

  String _bluetoothSummary(OsSettingsServices services, AppLocalizations l10n) {
    final bt = services.bluetooth();
    final on = bt.currentAdapterInfo.powered ||
        bt.currentAdapterState == BluetoothAdapterState.on;
    return on ? l10n.onLabel : l10n.offLabel;
  }

  Future<void> _refreshProxy(OsSettingsServices services) async {
    try {
      final p = await services.proxy().getSettings();
      if (!mounted) return;
      final http = p.httpProxy ?? p.allProxy;
      setState(() {
        _proxyEnabled = p.enabled;
        _proxyEndpoint = p.enabled && http != null && http.host.isNotEmpty
            ? '${http.host}:${http.port}'
            : '';
      });
    } catch (_) {}
  }

  String _proxyTrailing(AppLocalizations l10n) {
    if (!_proxyEnabled) return l10n.offLabel;
    return _proxyEndpoint.isEmpty ? l10n.onLabel : _proxyEndpoint;
  }

  Future<void> _refreshSsh(OsSettingsServices services) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final on = await services.sshDebug().isEnabled();
      if (!mounted) return;
      setState(() => _sshSummary = on ? l10n.onLabel : l10n.offLabel);
    } catch (_) {
      if (mounted) setState(() => _sshSummary = null);
    }
  }

  Future<void> _refreshDateTime(OsSettingsServices services) async {
    try {
      final mode = await services.dateTime().getSyncMode();
      if (!mounted) return;
      setState(() => _dateTimeMode = mode);
    } catch (_) {
      if (mounted) setState(() => _dateTimeMode = null);
    }
  }

  String? _dateTimeTrailing(AppLocalizations l10n) {
    final mode = _dateTimeMode;
    if (mode == null) return null;
    return mode == TimeSyncMode.network
        ? l10n.dateTimeAutomatic
        : l10n.dateTimeModeManual;
  }

  Future<void> _refreshLocale(OsSettingsServices services) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final locale = services.locale();
      await locale.read();
      if (!mounted) return;
      setState(() {
        _countrySummary = RegionCatalog.displayName(
          locale.region,
          chineseUi: locale.language.isChinese,
        );
        _languageSummary = locale.language.endonym;
        _unitSummary = switch (locale.unit) {
          UnitSystem.metric => l10n.metricLabel,
          UnitSystem.imperial => l10n.imperialLabel,
        };
      });
    } catch (_) {}
  }

  Future<void> _refreshDisplay(OsSettingsServices services) async {
    try {
      final v = await services.backlight().getBrightnessPercent();
      if (!mounted) return;
      setState(() => _displaySummary = '$v%');
    } catch (_) {
      if (mounted) setState(() => _displaySummary = null);
    }
  }

  Future<void> _refreshSound(OsSettingsServices services) async {
    try {
      final v = await services.mediaAudio().getVolumePercent();
      if (!mounted) return;
      setState(() => _soundSummary = '$v%');
    } catch (_) {
      if (mounted) setState(() => _soundSummary = null);
    }
  }

  Future<void> _refreshPowerMode(OsSettingsServices services) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final mode = await services.loadProfile().getMode();
      if (!mounted) return;
      setState(() {
        _powerModeSummary = switch (mode) {
          LoadProfileMode.performance => l10n.performanceLabel,
          LoadProfileMode.balanced => l10n.balancedLabel,
        };
      });
    } catch (_) {
      if (mounted) setState(() => _powerModeSummary = null);
    }
  }

  Future<void> _refreshKeyboard(OsSettingsServices services) async {
    try {
      final layout = await services.keyboard().getLayout();
      if (!mounted) return;
      setState(() {
        _keyboardSummary = KeyboardProfile.fromLayout(layout).segmentLabel;
      });
    } catch (_) {
      if (mounted) setState(() => _keyboardSummary = null);
    }
  }

  Future<void> _refreshMouse(OsSettingsServices services) async {
    try {
      final s = await services.mouse().getSettings();
      if (!mounted) return;
      setState(() {
        _mouseSummary = s.naturalScroll ? 'Natural Scroll' : 'Standard Scroll';
      });
    } catch (_) {
      if (mounted) setState(() => _mouseSummary = null);
    }
  }

  Future<void> _refreshUsbOtg(OsSettingsServices services) async {
    try {
      final mode = await services.usbOtg().getMode();
      if (!mounted) return;
      setState(() {
        _usbOtgSummary = switch (mode) {
          UsbOtgMode.debug => 'USB Debug',
          UsbOtgMode.mtp => 'MTP',
          UsbOtgMode.host => 'Host',
        };
      });
    } catch (_) {
      if (mounted) setState(() => _usbOtgSummary = null);
    }
  }

  String? _subtitleFor(OsSettingsDestination dest, AppLocalizations l10n) {
    final scope = OsSettingsScope.maybeOf(context);
    final services = scope?.services;
    return switch (dest) {
      OsSettingsDestination.about => _aboutSummary,
      OsSettingsDestination.operatingSystem => _osSummary,
      OsSettingsDestination.storage => _storageSummary,
      OsSettingsDestination.wifi =>
        services == null ? null : _wifiSummary(services, l10n),
      OsSettingsDestination.ethernet => _ethernetSummary,
      OsSettingsDestination.bluetooth =>
        services == null ? null : _bluetoothSummary(services, l10n),
      OsSettingsDestination.proxy => _proxyTrailing(l10n),
      OsSettingsDestination.ssh => _sshSummary,
      OsSettingsDestination.cloudEnvironment => _cloudEnvironmentSummary,
      OsSettingsDestination.dateTime => _dateTimeTrailing(l10n),
      OsSettingsDestination.countryRegion => _countrySummary,
      OsSettingsDestination.language => _languageSummary,
      OsSettingsDestination.unit => _unitSummary,
      OsSettingsDestination.display => _displaySummary,
      OsSettingsDestination.sound => _soundSummary,
      OsSettingsDestination.powerMode => _powerModeSummary,
      OsSettingsDestination.keyboard => _keyboardSummary,
      OsSettingsDestination.mouse => _mouseSummary,
      OsSettingsDestination.usbOtg => _usbOtgSummary,
    };
  }

  Future<void> _open(OsSettingsDestination dest) async {
    await pushSettingsPage(context, dest.buildPage());
    if (!mounted) return;
    // Re-read after any sub-page — prefs / radio may have changed.
    unawaited(_loadSummaries());
  }

  Widget _nav(OsSettingsDestination dest, AppLocalizations l10n) {
    return SettingsNavRow(
      title: dest.localizedTitle(l10n),
      value: _subtitleFor(dest, l10n),
      onTap: () => unawaited(_open(dest)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
        title: l10n.osSettingsText,
        exitToHmi: true,
        onExitToHmi: () {
          CyberClickSoundRegistry.playClick();
          unawaited(exitToHmi(context));
        },
        body: SettingsScrollView(
        children: [
          // Basic Info — About / Operating System / Storage
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.leftRight,
            children: [
              _nav(OsSettingsDestination.about, l10n),
              _nav(OsSettingsDestination.operatingSystem, l10n),
              _nav(OsSettingsDestination.storage, l10n),
            ],
          ),
          // Network — Wi-Fi / Ethernet / Bluetooth / Proxy / SSH / Cloud Env
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.topBottom,
            children: [
              _nav(OsSettingsDestination.wifi, l10n),
              _nav(OsSettingsDestination.ethernet, l10n),
              _nav(OsSettingsDestination.bluetooth, l10n),
              _nav(OsSettingsDestination.proxy, l10n),
              _nav(OsSettingsDestination.ssh, l10n),
              _nav(OsSettingsDestination.cloudEnvironment, l10n),
            ],
          ),
          // Date & Time
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              _nav(OsSettingsDestination.dateTime, l10n),
            ],
          ),
          // Locale — Country/Region / Language / Unit
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              _nav(OsSettingsDestination.countryRegion, l10n),
              _nav(OsSettingsDestination.language, l10n),
              _nav(OsSettingsDestination.unit, l10n),
            ],
          ),
          // Display & Sound — Display / Sound / Power Mode
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.topBottom,
            children: [
              _nav(OsSettingsDestination.display, l10n),
              _nav(OsSettingsDestination.sound, l10n),
              _nav(OsSettingsDestination.powerMode, l10n),
            ],
          ),
          // Input — Keyboard / Mouse / USB OTG
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.leftRight,
            bottomInset: 0,
            children: [
              _nav(OsSettingsDestination.keyboard, l10n),
              _nav(OsSettingsDestination.mouse, l10n),
              _nav(OsSettingsDestination.usbOtg, l10n),
            ],
          ),
        ],
      ),
    );
  }
}
