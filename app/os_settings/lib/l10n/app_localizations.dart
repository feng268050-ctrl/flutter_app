import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @osSettingsText.
  ///
  /// In en, this message translates to:
  /// **'OS Settings'**
  String get osSettingsText;

  /// No description provided for @storageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storageTitle;

  /// No description provided for @wifiNetworkText.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi'**
  String get wifiNetworkText;

  /// No description provided for @ethernetText.
  ///
  /// In en, this message translates to:
  /// **'Ethernet'**
  String get ethernetText;

  /// No description provided for @ethernetLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get ethernetLink;

  /// No description provided for @ethernetManualIp.
  ///
  /// In en, this message translates to:
  /// **'Manual IP'**
  String get ethernetManualIp;

  /// No description provided for @ethernetPrefix.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get ethernetPrefix;

  /// No description provided for @bluetoothText.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetoothText;

  /// No description provided for @httpProxySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get httpProxySettingsTitle;

  /// No description provided for @dateTimeSettings.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateTimeSettings;

  /// No description provided for @countrySettingText.
  ///
  /// In en, this message translates to:
  /// **'Country/Region'**
  String get countrySettingText;

  /// No description provided for @languageSettingText.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettingText;

  /// No description provided for @unitSettingText.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitSettingText;

  /// No description provided for @screenSettings.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get screenSettings;

  /// No description provided for @soundSettings.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundSettings;

  /// No description provided for @powerModeSettingText.
  ///
  /// In en, this message translates to:
  /// **'Power Mode'**
  String get powerModeSettingText;

  /// No description provided for @powerModePersistedFooter.
  ///
  /// In en, this message translates to:
  /// **'Performance keeps full clocks and motion. Balanced lowers SoC load and heat by capping clocks and reducing decorative animation.'**
  String get powerModePersistedFooter;

  /// No description provided for @keyboardText.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get keyboardText;

  /// No description provided for @mouseText.
  ///
  /// In en, this message translates to:
  /// **'Mouse'**
  String get mouseText;

  /// No description provided for @usbOtgText.
  ///
  /// In en, this message translates to:
  /// **'USB OTG'**
  String get usbOtgText;

  /// No description provided for @offLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get offLabel;

  /// No description provided for @onLabel.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get onLabel;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get notConnected;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @cancelText.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelText;

  /// No description provided for @confirmText.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmText;

  /// No description provided for @wifiApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get wifiApply;

  /// No description provided for @screenBrightnessText.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get screenBrightnessText;

  /// No description provided for @screenOffTimeText.
  ///
  /// In en, this message translates to:
  /// **'Auto Screen Off'**
  String get screenOffTimeText;

  /// No description provided for @screenOffNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get screenOffNever;

  /// No description provided for @screenOffOption10Min.
  ///
  /// In en, this message translates to:
  /// **'10 min'**
  String get screenOffOption10Min;

  /// No description provided for @screenOffOption30Min.
  ///
  /// In en, this message translates to:
  /// **'30 min'**
  String get screenOffOption30Min;

  /// No description provided for @screenOffOption60Min.
  ///
  /// In en, this message translates to:
  /// **'60 min'**
  String get screenOffOption60Min;

  /// No description provided for @wallpaperSettingText.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get wallpaperSettingText;

  /// No description provided for @wallpaperOptionDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get wallpaperOptionDefault;

  /// No description provided for @wallpaperApplyRestarts.
  ///
  /// In en, this message translates to:
  /// **'Changing wallpaper restarts the application.'**
  String get wallpaperApplyRestarts;

  /// No description provided for @storageMountSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get storageMountSystem;

  /// No description provided for @storageMountUserData.
  ///
  /// In en, this message translates to:
  /// **'User Data'**
  String get storageMountUserData;

  /// No description provided for @storageAvailableLegend.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get storageAvailableLegend;

  /// No description provided for @storageUsedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} used'**
  String storageUsedOfTotal(String used, String total);

  /// No description provided for @wifiConfigureIp.
  ///
  /// In en, this message translates to:
  /// **'Configure IP'**
  String get wifiConfigureIp;

  /// No description provided for @wifiIpModeDhcp.
  ///
  /// In en, this message translates to:
  /// **'DHCP'**
  String get wifiIpModeDhcp;

  /// No description provided for @wifiManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get wifiManual;

  /// No description provided for @wifiIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get wifiIpAddress;

  /// No description provided for @wifiRouter.
  ///
  /// In en, this message translates to:
  /// **'Router'**
  String get wifiRouter;

  /// No description provided for @wifiDns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get wifiDns;

  /// No description provided for @wifiIpMode.
  ///
  /// In en, this message translates to:
  /// **'IP Mode'**
  String get wifiIpMode;

  /// No description provided for @wifiIpModeStatic.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get wifiIpModeStatic;

  /// No description provided for @customHomeReplacementSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get customHomeReplacementSelected;

  /// No description provided for @wifiScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get wifiScanning;

  /// No description provided for @wifiNoSavedNetworks.
  ///
  /// In en, this message translates to:
  /// **'No saved networks'**
  String get wifiNoSavedNetworks;

  /// No description provided for @wifiAutoJoin.
  ///
  /// In en, this message translates to:
  /// **'Auto Join'**
  String get wifiAutoJoin;

  /// No description provided for @wifiForgetNetwork.
  ///
  /// In en, this message translates to:
  /// **'Forget Network'**
  String get wifiForgetNetwork;

  /// No description provided for @wifiAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get wifiAutomatic;

  /// No description provided for @wifiSubnetMask.
  ///
  /// In en, this message translates to:
  /// **'Subnet Mask'**
  String get wifiSubnetMask;

  /// No description provided for @wifiDnsServers.
  ///
  /// In en, this message translates to:
  /// **'DNS Servers'**
  String get wifiDnsServers;

  /// No description provided for @keyboardSoftLayoutPreview.
  ///
  /// In en, this message translates to:
  /// **'Software Keyboard Layout Preview'**
  String get keyboardSoftLayoutPreview;

  /// No description provided for @keyboardPhysicalSection.
  ///
  /// In en, this message translates to:
  /// **'Physical Keyboard'**
  String get keyboardPhysicalSection;

  /// No description provided for @keyboardLayoutHelp.
  ///
  /// In en, this message translates to:
  /// **'Attach a physical keyboard that matches the selected specification. A mismatch may make some keys produce unexpected characters.'**
  String get keyboardLayoutHelp;

  /// No description provided for @keyboardApplyConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply Keyboard Layout?'**
  String get keyboardApplyConfirmTitle;

  /// No description provided for @keyboardApplyConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Saves the selected layout and restarts HMI so soft CyberIME and physical keyboard both take effect. This page will reopen after relaunch.'**
  String get keyboardApplyConfirmBody;

  /// No description provided for @keyboardLongPressAccentHint.
  ///
  /// In en, this message translates to:
  /// **'Long-Press For Accented Characters'**
  String get keyboardLongPressAccentHint;

  /// No description provided for @keyboardNotDetected.
  ///
  /// In en, this message translates to:
  /// **'Not Detected'**
  String get keyboardNotDetected;

  /// No description provided for @cameraStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get cameraStatus;

  /// No description provided for @dateTimeAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get dateTimeAutomatic;

  /// No description provided for @dateTimeModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get dateTimeModeManual;

  /// No description provided for @exitLabel.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitLabel;

  /// No description provided for @backLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backLabel;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutText;

  /// No description provided for @operatingSystemText.
  ///
  /// In en, this message translates to:
  /// **'Operating System'**
  String get operatingSystemText;

  /// No description provided for @sshText.
  ///
  /// In en, this message translates to:
  /// **'SSH'**
  String get sshText;

  /// No description provided for @cloudEnvironmentTier.
  ///
  /// In en, this message translates to:
  /// **'Cloud Environment'**
  String get cloudEnvironmentTier;

  /// No description provided for @cloudEnvironmentTierProd.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get cloudEnvironmentTierProd;

  /// No description provided for @cloudEnvironmentTierTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get cloudEnvironmentTierTest;

  /// No description provided for @cloudEnvironmentFooter.
  ///
  /// In en, this message translates to:
  /// **'Choose which cloud service environment this device connects to. Use Production for normal operation. Use Test only when working with a test cloud. This applies to every app on the device.'**
  String get cloudEnvironmentFooter;

  /// No description provided for @volumeText.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volumeText;

  /// No description provided for @myNetworks.
  ///
  /// In en, this message translates to:
  /// **'My Networks'**
  String get myNetworks;

  /// No description provided for @otherNetworks.
  ///
  /// In en, this message translates to:
  /// **'Other Networks'**
  String get otherNetworks;

  /// No description provided for @wifiHiddenNetwork.
  ///
  /// In en, this message translates to:
  /// **'Hidden Network'**
  String get wifiHiddenNetwork;

  /// No description provided for @wifiConnectHidden.
  ///
  /// In en, this message translates to:
  /// **'Connect to Hidden Network'**
  String get wifiConnectHidden;

  /// No description provided for @wifiNoNetworks.
  ///
  /// In en, this message translates to:
  /// **'No networks found'**
  String get wifiNoNetworks;

  /// No description provided for @wifiForgetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Forget this network and disconnect?'**
  String get wifiForgetConfirm;

  /// No description provided for @wifiDetails.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi Details'**
  String get wifiDetails;

  /// No description provided for @wifiAddDns.
  ///
  /// In en, this message translates to:
  /// **'Add DNS Server'**
  String get wifiAddDns;

  /// No description provided for @naturalScrolling.
  ///
  /// In en, this message translates to:
  /// **'Natural Scrolling'**
  String get naturalScrolling;

  /// No description provided for @trackingSpeed.
  ///
  /// In en, this message translates to:
  /// **'Tracking Speed'**
  String get trackingSpeed;

  /// No description provided for @pointerSize.
  ///
  /// In en, this message translates to:
  /// **'Pointer Size'**
  String get pointerSize;

  /// No description provided for @primaryButton.
  ///
  /// In en, this message translates to:
  /// **'Primary Button'**
  String get primaryButton;

  /// No description provided for @leftLabel.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get leftLabel;

  /// No description provided for @rightLabel.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get rightLabel;

  /// Power Mode option — full clocks / motion
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performanceLabel;

  /// Power Mode option — capped clocks / less decorative motion
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get balancedLabel;

  /// No description provided for @metricLabel.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metricLabel;

  /// No description provided for @imperialLabel.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get imperialLabel;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @secretsSealText.
  ///
  /// In en, this message translates to:
  /// **'Secrets Seal'**
  String get secretsSealText;

  /// No description provided for @uiScaleText.
  ///
  /// In en, this message translates to:
  /// **'UI Scale'**
  String get uiScaleText;

  /// No description provided for @uiScaleLabel.
  ///
  /// In en, this message translates to:
  /// **'UI Scale ({percent}%)'**
  String uiScaleLabel(Object percent);

  /// No description provided for @uiScaleHelp.
  ///
  /// In en, this message translates to:
  /// **'UI Scale at 100% matches the panel’s natural size. Raise or lower the scale if on-screen content looks too small or too large.'**
  String get uiScaleHelp;

  /// No description provided for @volumeOnlyHelp.
  ///
  /// In en, this message translates to:
  /// **'Controls the volume for media and system sounds on this device.'**
  String get volumeOnlyHelp;

  /// No description provided for @osPlatformSection.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get osPlatformSection;

  /// No description provided for @osSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get osSecuritySection;

  /// No description provided for @osRuntimeSection.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get osRuntimeSection;

  /// No description provided for @osConnectivitySection.
  ///
  /// In en, this message translates to:
  /// **'Connectivity'**
  String get osConnectivitySection;

  /// No description provided for @operatingSystemLabel.
  ///
  /// In en, this message translates to:
  /// **'Operating System'**
  String get operatingSystemLabel;

  /// No description provided for @linuxKernelLabel.
  ///
  /// In en, this message translates to:
  /// **'Linux Kernel'**
  String get linuxKernelLabel;

  /// No description provided for @selinuxLabel.
  ///
  /// In en, this message translates to:
  /// **'SELinux'**
  String get selinuxLabel;

  /// No description provided for @busyboxLabel.
  ///
  /// In en, this message translates to:
  /// **'BusyBox'**
  String get busyboxLabel;

  /// No description provided for @glibcLabel.
  ///
  /// In en, this message translates to:
  /// **'Glibc'**
  String get glibcLabel;

  /// No description provided for @wpaSupplicantLabel.
  ///
  /// In en, this message translates to:
  /// **'WPA Supplicant'**
  String get wpaSupplicantLabel;

  /// No description provided for @bluezLabel.
  ///
  /// In en, this message translates to:
  /// **'BlueZ'**
  String get bluezLabel;

  /// No description provided for @opensslLabel.
  ///
  /// In en, this message translates to:
  /// **'OpenSSL'**
  String get opensslLabel;

  /// No description provided for @opensshLabel.
  ///
  /// In en, this message translates to:
  /// **'OpenSSH'**
  String get opensshLabel;

  /// No description provided for @gstreamerLabel.
  ///
  /// In en, this message translates to:
  /// **'GStreamer'**
  String get gstreamerLabel;

  /// No description provided for @flutterLabel.
  ///
  /// In en, this message translates to:
  /// **'Flutter'**
  String get flutterLabel;

  /// No description provided for @buildrootLabel.
  ///
  /// In en, this message translates to:
  /// **'Buildroot'**
  String get buildrootLabel;

  /// No description provided for @ethLinkConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get ethLinkConnected;

  /// No description provided for @ethLinkDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get ethLinkDisconnected;

  /// No description provided for @ethLinkNoCarrier.
  ///
  /// In en, this message translates to:
  /// **'Cable Unplugged'**
  String get ethLinkNoCarrier;

  /// No description provided for @ethLinkConfiguring.
  ///
  /// In en, this message translates to:
  /// **'Obtaining IP…'**
  String get ethLinkConfiguring;

  /// No description provided for @ethLinkError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get ethLinkError;

  /// No description provided for @languageSettingHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used in menus and messages on this device.'**
  String get languageSettingHelp;

  /// No description provided for @regionSettingHelp.
  ///
  /// In en, this message translates to:
  /// **'Sets the Wi‑Fi regulatory region and the default time zone and network time server. Language is set separately.'**
  String get regionSettingHelp;

  /// No description provided for @unitSettingHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose Metric (°C, mm) or Imperial (°F, in) for values shown on this device.'**
  String get unitSettingHelp;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewLabel;

  /// No description provided for @wlanLabel.
  ///
  /// In en, this message translates to:
  /// **'WLAN'**
  String get wlanLabel;

  /// No description provided for @connectingLabel.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectingLabel;

  /// No description provided for @secretsSealHelp.
  ///
  /// In en, this message translates to:
  /// **'Secrets Seal shows how this device protects saved secrets such as Wi‑Fi passwords and cloud keys. software means software encryption; op-tee means the secure hardware chip.'**
  String get secretsSealHelp;

  /// No description provided for @selinuxHelp.
  ///
  /// In en, this message translates to:
  /// **'SELinux is the Linux security policy layer. Disabled means it is off. Permissive means policy violations are logged but not blocked. Enforcing means the policy is enforced.'**
  String get selinuxHelp;

  /// No description provided for @wallpaperSectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper is used for the desktop background and in apps. Changing it briefly restarts Settings so the new image can load.'**
  String get wallpaperSectionHelp;

  /// No description provided for @keyboardApplyConfirmOsBody.
  ///
  /// In en, this message translates to:
  /// **'The keyboard layout will be saved, and Settings will restart so a matching physical keyboard works correctly.'**
  String get keyboardApplyConfirmOsBody;

  /// No description provided for @keyboardLayoutHelpOs.
  ///
  /// In en, this message translates to:
  /// **'The preview shows the on-screen keyboard layout. Tap Apply to save; Settings will restart so a matching physical keyboard works correctly.'**
  String get keyboardLayoutHelpOs;

  /// No description provided for @mousePointerHelp.
  ///
  /// In en, this message translates to:
  /// **'Changing the pointer size briefly restarts the app you are using.'**
  String get mousePointerHelp;

  /// No description provided for @wifiConfigureDns.
  ///
  /// In en, this message translates to:
  /// **'Configure DNS'**
  String get wifiConfigureDns;

  /// No description provided for @wifiIpv4AddressSection.
  ///
  /// In en, this message translates to:
  /// **'IPv4 Address'**
  String get wifiIpv4AddressSection;

  /// No description provided for @wifiGateway.
  ///
  /// In en, this message translates to:
  /// **'Gateway'**
  String get wifiGateway;

  /// No description provided for @wifiDnsLimit.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 3 DNS servers'**
  String get wifiDnsLimit;

  /// No description provided for @wifiOthersSection.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get wifiOthersSection;

  /// No description provided for @wifiMacAddress.
  ///
  /// In en, this message translates to:
  /// **'MAC Address'**
  String get wifiMacAddress;

  /// No description provided for @wifiLinkSpeed.
  ///
  /// In en, this message translates to:
  /// **'Link Speed'**
  String get wifiLinkSpeed;

  /// No description provided for @ethernetCableLink.
  ///
  /// In en, this message translates to:
  /// **'Cable'**
  String get ethernetCableLink;

  /// No description provided for @ethernetSpeedMbps.
  ///
  /// In en, this message translates to:
  /// **'{speed} Mbps'**
  String ethernetSpeedMbps(int speed);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
