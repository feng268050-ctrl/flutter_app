import 'package:flutter/material.dart';
import 'package:os_settings/l10n/app_localizations.dart';
import 'package:os_settings/pages/about_page.dart';
import 'package:os_settings/pages/bluetooth_page.dart';
import 'package:os_settings/pages/cloud_environment_page.dart';
import 'package:os_settings/pages/country_region_page.dart';
import 'package:os_settings/pages/date_time_page.dart';
import 'package:os_settings/pages/display_page.dart';
import 'package:os_settings/pages/ethernet_page.dart';
import 'package:os_settings/pages/keyboard_page.dart';
import 'package:os_settings/pages/language_page.dart';
import 'package:os_settings/pages/mouse_page.dart';
import 'package:os_settings/pages/operating_system_page.dart';
import 'package:os_settings/pages/power_mode_page.dart';
import 'package:os_settings/pages/proxy_page.dart';
import 'package:os_settings/pages/sound_page.dart';
import 'package:os_settings/pages/ssh_page.dart';
import 'package:os_settings/pages/storage_page.dart';
import 'package:os_settings/pages/unit_page.dart';
import 'package:os_settings/pages/usb_otg_page.dart';
import 'package:os_settings/pages/wifi_page.dart';

/// Flat top-level OS Settings destinations (order fixed by product plan).
enum OsSettingsDestination {
  about,
  operatingSystem,
  storage,
  wifi,
  ethernet,
  bluetooth,
  proxy,
  ssh,
  dateTime,
  countryRegion,
  language,
  unit,
  display,
  sound,
  powerMode,
  keyboard,
  mouse,
  usbOtg,
  cloudEnvironment;

  String localizedTitle(AppLocalizations l10n) => switch (this) {
        about => l10n.aboutText,
        operatingSystem => l10n.operatingSystemText,
        storage => l10n.storageTitle,
        wifi => l10n.wifiNetworkText,
        ethernet => l10n.ethernetText,
        bluetooth => l10n.bluetoothText,
        proxy => l10n.httpProxySettingsTitle,
        ssh => l10n.sshText,
        dateTime => l10n.dateTimeSettings,
        countryRegion => l10n.countrySettingText,
        language => l10n.languageSettingText,
        unit => l10n.unitSettingText,
        display => l10n.screenSettings,
        sound => l10n.soundSettings,
        powerMode => l10n.powerModeSettingText,
        keyboard => l10n.keyboardText,
        mouse => l10n.mouseText,
        usbOtg => l10n.usbOtgText,
        cloudEnvironment => l10n.cloudEnvironmentTier,
      };

  Widget buildPage() => switch (this) {
        about => const AboutPage(),
        operatingSystem => const OperatingSystemPage(),
        storage => const StoragePage(),
        wifi => const WifiPage(),
        ethernet => const EthernetPage(),
        bluetooth => const BluetoothPage(),
        proxy => const ProxyPage(),
        ssh => const SshPage(),
        dateTime => const DateTimePage(),
        countryRegion => const CountryRegionPage(),
        language => const LanguagePage(),
        unit => const UnitPage(),
        display => const DisplayPage(),
        sound => const SoundPage(),
        powerMode => const PowerModePage(),
        keyboard => const KeyboardPage(),
        mouse => const MousePage(),
        usbOtg => const UsbOtgPage(),
        cloudEnvironment => const CloudEnvironmentPage(),
      };
}

/// Ordered list for the root Settings list (same layout landscape / portrait).
const List<OsSettingsDestination> kOsSettingsDestinations =
    OsSettingsDestination.values;
