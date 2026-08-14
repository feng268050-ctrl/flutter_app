// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get osSettingsText => 'OS Settings';

  @override
  String get storageTitle => 'Storage';

  @override
  String get wifiNetworkText => 'Wi‑Fi';

  @override
  String get ethernetText => 'Ethernet';

  @override
  String get ethernetLink => 'Link';

  @override
  String get ethernetManualIp => 'Manual IP';

  @override
  String get ethernetPrefix => 'Prefix';

  @override
  String get bluetoothText => 'Bluetooth';

  @override
  String get httpProxySettingsTitle => 'Proxy';

  @override
  String get dateTimeSettings => 'Date & Time';

  @override
  String get countrySettingText => 'Country/Region';

  @override
  String get languageSettingText => 'Language';

  @override
  String get unitSettingText => 'Unit';

  @override
  String get screenSettings => 'Display';

  @override
  String get soundSettings => 'Sound';

  @override
  String get powerModeSettingText => 'Power Mode';

  @override
  String get powerModePersistedFooter =>
      'Performance keeps full clocks and motion. Balanced lowers SoC load and heat by capping clocks and reducing decorative animation.';

  @override
  String get keyboardText => 'Keyboard';

  @override
  String get mouseText => 'Mouse';

  @override
  String get usbOtgText => 'USB OTG';

  @override
  String get offLabel => 'Off';

  @override
  String get onLabel => 'On';

  @override
  String get notConnected => 'Not Connected';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get cancelText => 'Cancel';

  @override
  String get confirmText => 'Confirm';

  @override
  String get wifiApply => 'Apply';

  @override
  String get screenBrightnessText => 'Brightness';

  @override
  String get screenOffTimeText => 'Auto Screen Off';

  @override
  String get screenOffNever => 'Never';

  @override
  String get screenOffOption10Min => '10 min';

  @override
  String get screenOffOption30Min => '30 min';

  @override
  String get screenOffOption60Min => '60 min';

  @override
  String get wallpaperSettingText => 'Wallpaper';

  @override
  String get wallpaperOptionDefault => 'Default';

  @override
  String get wallpaperApplyRestarts =>
      'Changing wallpaper restarts the application.';

  @override
  String get storageMountSystem => 'System';

  @override
  String get storageMountUserData => 'User Data';

  @override
  String get storageAvailableLegend => 'Available';

  @override
  String storageUsedOfTotal(String used, String total) {
    return '$used of $total used';
  }

  @override
  String get wifiConfigureIp => 'Configure IP';

  @override
  String get wifiIpModeDhcp => 'DHCP';

  @override
  String get wifiManual => 'Manual';

  @override
  String get wifiIpAddress => 'IP Address';

  @override
  String get wifiRouter => 'Router';

  @override
  String get wifiDns => 'DNS';

  @override
  String get wifiIpMode => 'IP Mode';

  @override
  String get wifiIpModeStatic => 'Static';

  @override
  String get customHomeReplacementSelected => 'Selected';

  @override
  String get wifiScanning => 'Scanning…';

  @override
  String get wifiNoSavedNetworks => 'No saved networks';

  @override
  String get wifiAutoJoin => 'Auto Join';

  @override
  String get wifiForgetNetwork => 'Forget Network';

  @override
  String get wifiAutomatic => 'Automatic';

  @override
  String get wifiSubnetMask => 'Subnet Mask';

  @override
  String get wifiDnsServers => 'DNS Servers';

  @override
  String get keyboardSoftLayoutPreview => 'Software Keyboard Layout Preview';

  @override
  String get keyboardPhysicalSection => 'Physical Keyboard';

  @override
  String get keyboardLayoutHelp =>
      'Attach a physical keyboard that matches the selected specification. A mismatch may make some keys produce unexpected characters.';

  @override
  String get keyboardApplyConfirmTitle => 'Apply Keyboard Layout?';

  @override
  String get keyboardApplyConfirmBody =>
      'Saves the selected layout and restarts HMI so soft CyberIME and physical keyboard both take effect. This page will reopen after relaunch.';

  @override
  String get keyboardLongPressAccentHint =>
      'Long-Press For Accented Characters';

  @override
  String get keyboardNotDetected => 'Not Detected';

  @override
  String get cameraStatus => 'Status';

  @override
  String get dateTimeAutomatic => 'Automatic';

  @override
  String get dateTimeModeManual => 'Manual';

  @override
  String get exitLabel => 'Exit';

  @override
  String get backLabel => 'Back';

  @override
  String get aboutText => 'About';

  @override
  String get operatingSystemText => 'Operating System';

  @override
  String get sshText => 'SSH';

  @override
  String get cloudEnvironmentTier => 'Cloud Environment';

  @override
  String get cloudEnvironmentTierProd => 'Production';

  @override
  String get cloudEnvironmentTierTest => 'Test';

  @override
  String get cloudEnvironmentFooter =>
      'Choose which cloud service environment this device connects to. Use Production for normal operation. Use Test only when working with a test cloud. This applies to every app on the device.';

  @override
  String get volumeText => 'Volume';

  @override
  String get myNetworks => 'My Networks';

  @override
  String get otherNetworks => 'Other Networks';

  @override
  String get wifiHiddenNetwork => 'Hidden Network';

  @override
  String get wifiConnectHidden => 'Connect to Hidden Network';

  @override
  String get wifiNoNetworks => 'No networks found';

  @override
  String get wifiForgetConfirm => 'Forget this network and disconnect?';

  @override
  String get wifiDetails => 'Wi‑Fi Details';

  @override
  String get wifiAddDns => 'Add DNS Server';

  @override
  String get naturalScrolling => 'Natural Scrolling';

  @override
  String get trackingSpeed => 'Tracking Speed';

  @override
  String get pointerSize => 'Pointer Size';

  @override
  String get primaryButton => 'Primary Button';

  @override
  String get leftLabel => 'Left';

  @override
  String get rightLabel => 'Right';

  @override
  String get performanceLabel => 'Performance';

  @override
  String get balancedLabel => 'Balanced';

  @override
  String get metricLabel => 'Metric';

  @override
  String get imperialLabel => 'Imperial';

  @override
  String get searchHint => 'Search';

  @override
  String get noMatches => 'No matches';

  @override
  String get secretsSealText => 'Secrets Seal';

  @override
  String get uiScaleText => 'UI Scale';

  @override
  String uiScaleLabel(Object percent) {
    return 'UI Scale ($percent%)';
  }

  @override
  String get uiScaleHelp =>
      'UI Scale at 100% matches the panel’s natural size. Raise or lower the scale if on-screen content looks too small or too large.';

  @override
  String get volumeOnlyHelp =>
      'Controls the volume for media and system sounds on this device.';

  @override
  String get osPlatformSection => 'Platform';

  @override
  String get osSecuritySection => 'Security';

  @override
  String get osRuntimeSection => 'Runtime';

  @override
  String get osConnectivitySection => 'Connectivity';

  @override
  String get operatingSystemLabel => 'Operating System';

  @override
  String get linuxKernelLabel => 'Linux Kernel';

  @override
  String get selinuxLabel => 'SELinux';

  @override
  String get busyboxLabel => 'BusyBox';

  @override
  String get glibcLabel => 'Glibc';

  @override
  String get wpaSupplicantLabel => 'WPA Supplicant';

  @override
  String get bluezLabel => 'BlueZ';

  @override
  String get opensslLabel => 'OpenSSL';

  @override
  String get opensshLabel => 'OpenSSH';

  @override
  String get gstreamerLabel => 'GStreamer';

  @override
  String get flutterLabel => 'Flutter';

  @override
  String get buildrootLabel => 'Buildroot';

  @override
  String get ethLinkConnected => 'Connected';

  @override
  String get ethLinkDisconnected => 'Disconnected';

  @override
  String get ethLinkNoCarrier => 'Cable Unplugged';

  @override
  String get ethLinkConfiguring => 'Obtaining IP…';

  @override
  String get ethLinkError => 'Error';

  @override
  String get languageSettingHelp =>
      'Choose the language used in menus and messages on this device.';

  @override
  String get regionSettingHelp =>
      'Sets the Wi‑Fi regulatory region and the default time zone and network time server. Language is set separately.';

  @override
  String get unitSettingHelp =>
      'Choose Metric (°C, mm) or Imperial (°F, in) for values shown on this device.';

  @override
  String get previewLabel => 'Preview';

  @override
  String get wlanLabel => 'Wi-Fi';

  @override
  String get connectingLabel => 'Connecting…';

  @override
  String get secretsSealHelp =>
      'Secrets Seal shows how this device protects saved secrets such as Wi‑Fi passwords and cloud keys. software means software encryption; op-tee means the secure hardware chip.';

  @override
  String get selinuxHelp =>
      'SELinux is the Linux security policy layer. Disabled means it is off. Permissive means policy violations are logged but not blocked. Enforcing means the policy is enforced.';

  @override
  String get wallpaperSectionHelp =>
      'Wallpaper is used for the desktop background and in apps. Changing it briefly restarts Settings so the new image can load.';

  @override
  String get keyboardApplyConfirmOsBody =>
      'The keyboard layout will be saved, and Settings will restart so a matching physical keyboard works correctly.';

  @override
  String get keyboardApplySuccessTitle => 'Layout Applied';

  @override
  String get keyboardApplySuccessBody => 'Done';

  @override
  String get keyboardLayoutHelpOs =>
      'The preview shows the on-screen keyboard layout. Tap Apply to save; Settings will restart so a matching physical keyboard works correctly.';

  @override
  String get mousePointerHelp =>
      'Changing the pointer size briefly restarts the app you are using.';

  @override
  String get wifiConfigureDns => 'Configure DNS';

  @override
  String get wifiIpv4AddressSection => 'IPv4 Address';

  @override
  String get wifiGateway => 'Gateway';

  @override
  String get wifiDnsLimit => 'You can add up to 3 DNS servers';

  @override
  String get wifiOthersSection => 'Others';

  @override
  String get wifiMacAddress => 'MAC Address';

  @override
  String get wifiLinkSpeed => 'Link Speed';

  @override
  String get ethernetCableLink => 'Cable';

  @override
  String ethernetSpeedMbps(int speed) {
    return '$speed Mbps';
  }
}
