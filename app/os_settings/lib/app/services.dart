import 'dart:async';

import 'package:cyber_hal/bluetooth.dart';
import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/input.dart';
import 'package:cyber_hal/locale.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:cyber_hal/usb_otg.dart';
import 'package:os_settings/app/os_wall_clock.dart';

/// Thin wrappers around [BoardBindings] for platform controllers.
final class OsSettingsServices {
  OsSettingsServices({required this.boardProfile})
      : bindings = BoardBindings(boardProfile) {
    wallClock = OsWallClock(dateTime())..start();
    uiScale().warmRead();
  }

  final BoardProfile boardProfile;
  final BoardBindings bindings;

  late final OsWallClock wallClock;

  LinuxSysInfo? _sysInfo;
  LocaleSettings? _locale;
  LinuxWifiSession? _wifi;
  LinuxEthernetSession? _ethernet;
  LinuxBluezBluetoothController? _bluetooth;
  LinuxProxy? _proxy;
  LinuxDateTimeController? _dateTime;
  LinuxSshDebugController? _ssh;
  LinuxSysfsBacklight? _backlight;
  LinuxAutoSleep? _autoSleep;
  LinuxWallpaper? _wallpaper;
  LinuxUiScale? _uiScale;
  LinuxMediaAudioController? _mediaAudio;
  LinuxButtonFeedback? _buttonFeedback;
  LinuxKeyboard? _keyboard;
  LinuxMouseSettingsController? _mouse;
  LinuxUsbOtg? _usbOtg;
  LinuxLoadProfile? _loadProfile;
  RegionSettingsApplier? _regionSettings;

  /// Region → Wi‑Fi regulatory + linked timezone / NTP.
  RegionSettingsApplier regionSettings() {
    return _regionSettings ??= RegionSettingsApplier(
      dateTime: dateTime(),
      wifiIface: bindings.wifiIface(),
    );
  }

  LinuxSysInfo sysInfo({
    DeviceSnReader deviceSnReader = const DeviceSnReader(),
    String? appVersion,
  }) {
    return _sysInfo ??= bindings.sysInfo(
      deviceSnReader: deviceSnReader,
      appVersion: appVersion,
    );
  }

  Future<ProductInfo> productInfo() => bindings.productInfo();

  LocaleSettings locale() => _locale ??= LocaleSettings();

  LinuxDateTimeController dateTime() =>
      _dateTime ??= bindings.dateTime();

  LinuxSshDebugController sshDebug() => _ssh ??= bindings.sshDebug();

  LinuxWifiSession wifi() => _wifi ??= bindings.wifiSession();

  LinuxEthernetSession ethernet() =>
      _ethernet ??= bindings.ethernetSession();

  LinuxProxy proxy() => _proxy ??= bindings.proxy();

  LinuxPrimaryNetworkController primaryNetwork({
    WifiController? wifi,
    EthernetController? ethernet,
  }) {
    return bindings.primaryNetwork(wifi: wifi, ethernet: ethernet);
  }

  LinuxSysfsBacklight backlight() => _backlight ??= bindings.backlight();

  LinuxAutoSleep autoSleep() => _autoSleep ??= bindings.autoSleep();

  LinuxWallpaper wallpaper() => _wallpaper ??= bindings.wallpaper();

  LinuxUiScale uiScale() => _uiScale ??= bindings.uiScale();

  LinuxMediaAudioController mediaAudio() =>
      _mediaAudio ??= bindings.mediaAudio();

  LinuxButtonFeedback buttonFeedback() =>
      _buttonFeedback ??= bindings.buttonFeedback(mediaAudio: mediaAudio());

  LinuxKeyboard keyboard() {
    return _keyboard ??= bindings.keyboard();
  }

  LinuxMouseSettingsController mouse() => _mouse ??= bindings.mouse();

  LinuxUsbOtg usbOtg() => _usbOtg ??= bindings.usbOtg();

  LinuxLoadProfile loadProfile() =>
      _loadProfile ??= bindings.loadProfile();

  LinuxBluezBluetoothController bluetooth() =>
      _bluetooth ??= bindings.bluetooth();

  LinuxPlatformVersions platformVersions() => bindings.platformVersions();

  String secretsSealStatus() => bindings.secretsSealStatus();

  bool _observed = false;

  Future<void> observePlatformStacks() async {
    if (_observed) return;
    _observed = true;
    try {
      await wifi().syncFromSystem();
    } catch (_) {}
    try {
      await ethernet().syncFromSystem();
    } catch (_) {}
    try {
      await bluetooth().syncFromSystem();
    } catch (_) {}
  }
}
