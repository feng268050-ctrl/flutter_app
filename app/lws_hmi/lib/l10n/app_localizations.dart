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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'US'),
    Locale('zh'),
    Locale('zh', 'CN'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @activeAlarmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Alarms'**
  String get activeAlarmsTitle;

  /// No description provided for @adFeedbackCommunicationAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get adFeedbackCommunicationAlarmContent;

  /// No description provided for @adFeedbackCommunicationAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'AD Feedback Communication Alarm'**
  String get adFeedbackCommunicationAlarmTitle;

  /// No description provided for @adbRemoteDebugEnabled.
  ///
  /// In en, this message translates to:
  /// **'ADB remote debugging enabled (port {port}). Use adb connect to attach.'**
  String adbRemoteDebugEnabled(int port);

  /// No description provided for @adbRemoteDebugFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to enable ADB remote debugging'**
  String get adbRemoteDebugFailed;

  /// No description provided for @advancedSettingAllowWorkAfterCameraAlarm.
  ///
  /// In en, this message translates to:
  /// **'Allow Work After Camera Alarm'**
  String get advancedSettingAllowWorkAfterCameraAlarm;

  /// No description provided for @advancedSettingAllowWorkAfterCameraAlarmHint.
  ///
  /// In en, this message translates to:
  /// **'If camera communication fails, AI auto-detection will be unavailable.'**
  String get advancedSettingAllowWorkAfterCameraAlarmHint;

  /// No description provided for @advancedSettingAllowWorkAfterFeederAlarm.
  ///
  /// In en, this message translates to:
  /// **'Allow Work After Feeder Alarm'**
  String get advancedSettingAllowWorkAfterFeederAlarm;

  /// No description provided for @advancedSettingAllowWorkAfterFeederAlarmHint.
  ///
  /// In en, this message translates to:
  /// **'Continuous welding won’t work properly if the wire feeder is abnormal, but other modes can continue.'**
  String get advancedSettingAllowWorkAfterFeederAlarmHint;

  /// No description provided for @advancedSettingAllowWorkAfterGasAlarm.
  ///
  /// In en, this message translates to:
  /// **'Allow Work After Gas Alarm'**
  String get advancedSettingAllowWorkAfterGasAlarm;

  /// No description provided for @advancedSettingAllowWorkAfterGasAlarmHint.
  ///
  /// In en, this message translates to:
  /// **'Allowing laser output with abnormal shielding gas may damage the device. Enable only when you’re sure it’s safe.'**
  String get advancedSettingAllowWorkAfterGasAlarmHint;

  /// No description provided for @advancedSettingAllowWorkAfterLensContamination.
  ///
  /// In en, this message translates to:
  /// **'Allow Work After Lens Contamination'**
  String get advancedSettingAllowWorkAfterLensContamination;

  /// No description provided for @advancedSettingAllowWorkAfterLensContaminationHint.
  ///
  /// In en, this message translates to:
  /// **'Allowing laser output with a contaminated protective lens may damage the device. Enable only if AI detection is inaccurate.'**
  String get advancedSettingAllowWorkAfterLensContaminationHint;

  /// No description provided for @advancedSettingKeepLaserOnWhileAlarmed.
  ///
  /// In en, this message translates to:
  /// **'Keep Laser On During Alarms'**
  String get advancedSettingKeepLaserOnWhileAlarmed;

  /// No description provided for @advancedSettingKeepLaserOnWhileAlarmedHint.
  ///
  /// In en, this message translates to:
  /// **'When enabled, coded alarms won’t automatically turn off the laser while you’re already welding. Warning dialogs still appear. Use only when the risk is acceptable.'**
  String get advancedSettingKeepLaserOnWhileAlarmedHint;

  /// No description provided for @advancedSettingLensContaminationDetection.
  ///
  /// In en, this message translates to:
  /// **'Lens Contamination Detection'**
  String get advancedSettingLensContaminationDetection;

  /// No description provided for @advancedSettingLensContaminationDetectionHint.
  ///
  /// In en, this message translates to:
  /// **'Uses the camera and AI to watch the protective lens during work and warn when contamination is detected. Turn off only if detection is inaccurate or unavailable.'**
  String get advancedSettingLensContaminationDetectionHint;

  /// No description provided for @advancedSettingZeroOffset.
  ///
  /// In en, this message translates to:
  /// **'Zero Offset'**
  String get advancedSettingZeroOffset;

  /// No description provided for @advancedSettingZeroOffsetAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get advancedSettingZeroOffsetAuto;

  /// No description provided for @advancedSettingEnterZeroOffset.
  ///
  /// In en, this message translates to:
  /// **'Enter zero offset'**
  String get advancedSettingEnterZeroOffset;

  /// No description provided for @advancedSettingScanWidthCorrection.
  ///
  /// In en, this message translates to:
  /// **'Scan Width Correction'**
  String get advancedSettingScanWidthCorrection;

  /// No description provided for @advancedSettingEnterScanWidthCorrection.
  ///
  /// In en, this message translates to:
  /// **'Enter scan width correction'**
  String get advancedSettingEnterScanWidthCorrection;

  /// No description provided for @advancedSettingLaserStartPower.
  ///
  /// In en, this message translates to:
  /// **'Laser Start Power'**
  String get advancedSettingLaserStartPower;

  /// No description provided for @advancedSettingEnterLaserStartPower.
  ///
  /// In en, this message translates to:
  /// **'Enter laser start power'**
  String get advancedSettingEnterLaserStartPower;

  /// No description provided for @advancedSettingLaserEndPower.
  ///
  /// In en, this message translates to:
  /// **'Laser End Power'**
  String get advancedSettingLaserEndPower;

  /// No description provided for @advancedSettingEnterLaserEndPower.
  ///
  /// In en, this message translates to:
  /// **'Enter laser end power'**
  String get advancedSettingEnterLaserEndPower;

  /// No description provided for @advancedSettingMinGasPressure.
  ///
  /// In en, this message translates to:
  /// **'Min. Gas Pressure'**
  String get advancedSettingMinGasPressure;

  /// No description provided for @advancedSettingEnterMinGasPressure.
  ///
  /// In en, this message translates to:
  /// **'Enter minimum gas pressure threshold'**
  String get advancedSettingEnterMinGasPressure;

  /// No description provided for @advancedSettingInletGasPressure.
  ///
  /// In en, this message translates to:
  /// **'Inlet Gas Pressure Threshold'**
  String get advancedSettingInletGasPressure;

  /// No description provided for @advancedSettingEnterInletGasPressure.
  ///
  /// In en, this message translates to:
  /// **'Enter inlet gas pressure threshold'**
  String get advancedSettingEnterInletGasPressure;

  /// No description provided for @advancedSettingMotorTempAlarmThreshold.
  ///
  /// In en, this message translates to:
  /// **'Motor Temperature Alarm Threshold'**
  String get advancedSettingMotorTempAlarmThreshold;

  /// No description provided for @advancedSettingEnterMotorTempAlarmThreshold.
  ///
  /// In en, this message translates to:
  /// **'Enter motor temperature alarm threshold'**
  String get advancedSettingEnterMotorTempAlarmThreshold;

  /// No description provided for @advancedSettingDriverTempAlarmThreshold.
  ///
  /// In en, this message translates to:
  /// **'Driver Temperature Alarm Threshold'**
  String get advancedSettingDriverTempAlarmThreshold;

  /// No description provided for @advancedSettingEnterDriverTempAlarmThreshold.
  ///
  /// In en, this message translates to:
  /// **'Enter driver temperature alarm threshold'**
  String get advancedSettingEnterDriverTempAlarmThreshold;

  /// No description provided for @advancedSettingProtectiveLensTempAlarmThreshold.
  ///
  /// In en, this message translates to:
  /// **'Protective Lens Temperature Alarm Threshold'**
  String get advancedSettingProtectiveLensTempAlarmThreshold;

  /// No description provided for @advancedSettingEnterProtectiveLensTempAlarmThreshold.
  ///
  /// In en, this message translates to:
  /// **'Enter protective lens temperature alarm threshold'**
  String get advancedSettingEnterProtectiveLensTempAlarmThreshold;

  /// No description provided for @advancedSettingCollimatingLensTempAlarmThreshold.
  ///
  /// In en, this message translates to:
  /// **'Collimating Lens Temperature Alarm Threshold'**
  String get advancedSettingCollimatingLensTempAlarmThreshold;

  /// No description provided for @advancedSettingEnterCollimatingLensTempAlarmThreshold.
  ///
  /// In en, this message translates to:
  /// **'Enter collimating lens temperature alarm threshold'**
  String get advancedSettingEnterCollimatingLensTempAlarmThreshold;

  /// No description provided for @advancedSettingTempAlarmRecoveryHysteresis.
  ///
  /// In en, this message translates to:
  /// **'Temperature Alarm Recovery Hysteresis'**
  String get advancedSettingTempAlarmRecoveryHysteresis;

  /// No description provided for @advancedSettingEnterTempAlarmRecoveryHysteresis.
  ///
  /// In en, this message translates to:
  /// **'Enter temperature alarm recovery hysteresis'**
  String get advancedSettingEnterTempAlarmRecoveryHysteresis;

  /// No description provided for @advancedSettingValueRequired.
  ///
  /// In en, this message translates to:
  /// **'Value is required'**
  String get advancedSettingValueRequired;

  /// No description provided for @advancedSettingScale0Celsius.
  ///
  /// In en, this message translates to:
  /// **'0℃'**
  String get advancedSettingScale0Celsius;

  /// No description provided for @advancedSettingScale20Celsius.
  ///
  /// In en, this message translates to:
  /// **'20℃'**
  String get advancedSettingScale20Celsius;

  /// No description provided for @advancedSettingScale80Celsius.
  ///
  /// In en, this message translates to:
  /// **'80℃'**
  String get advancedSettingScale80Celsius;

  /// No description provided for @advancedSettingScale85Celsius.
  ///
  /// In en, this message translates to:
  /// **'85℃'**
  String get advancedSettingScale85Celsius;

  /// No description provided for @advancedSettingShowBootSelfCheck.
  ///
  /// In en, this message translates to:
  /// **'Show Startup Self-Check'**
  String get advancedSettingShowBootSelfCheck;

  /// No description provided for @advancedSettingText.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSettingText;

  /// No description provided for @advancedSettingZeroPointOffsetDetection.
  ///
  /// In en, this message translates to:
  /// **'Zero Offset Detection'**
  String get advancedSettingZeroPointOffsetDetection;

  /// No description provided for @advancedSettingZeroPointOffsetDetectionHint.
  ///
  /// In en, this message translates to:
  /// **'Uses AI to check whether the laser spot is centered. You’ll be prompted to correct zero offset when it drifts. Turn off only if you don’t need this alert.'**
  String get advancedSettingZeroPointOffsetDetectionHint;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSettings;

  /// No description provided for @advancedSettingsGroupAiAssistance.
  ///
  /// In en, this message translates to:
  /// **'AI Assistance'**
  String get advancedSettingsGroupAiAssistance;

  /// No description provided for @advancedSettingsGroupDangerousOperations.
  ///
  /// In en, this message translates to:
  /// **'Override Safeguards'**
  String get advancedSettingsGroupDangerousOperations;

  /// No description provided for @advancedSettingsGroupOffsetCorrection.
  ///
  /// In en, this message translates to:
  /// **'Offset & Correction'**
  String get advancedSettingsGroupOffsetCorrection;

  /// No description provided for @advancedSettingsGroupPowerThresholds.
  ///
  /// In en, this message translates to:
  /// **'Power Thresholds'**
  String get advancedSettingsGroupPowerThresholds;

  /// No description provided for @advancedSettingsGroupTemperatureThresholds.
  ///
  /// In en, this message translates to:
  /// **'Temperature Thresholds'**
  String get advancedSettingsGroupTemperatureThresholds;

  /// No description provided for @aiDetectionLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Detection'**
  String get aiDetectionLabel;

  /// No description provided for @aiOverlayClsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Class: disabled'**
  String get aiOverlayClsDisabled;

  /// No description provided for @aiOverlayClsMetal.
  ///
  /// In en, this message translates to:
  /// **'Metal'**
  String get aiOverlayClsMetal;

  /// No description provided for @aiOverlayClsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get aiOverlayClsOther;

  /// No description provided for @aiOverlayClsPrefix.
  ///
  /// In en, this message translates to:
  /// **'Class: {className} ({score})'**
  String aiOverlayClsPrefix(String className, double score);

  /// No description provided for @aiOverlayClsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Class: waiting…'**
  String get aiOverlayClsWaiting;

  /// No description provided for @aiOverlayHudStatePrefix.
  ///
  /// In en, this message translates to:
  /// **'STATE: {state}'**
  String aiOverlayHudStatePrefix(String state);

  /// No description provided for @aiOverlayHudStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'IDLE'**
  String get aiOverlayHudStatusIdle;

  /// No description provided for @aiOverlayHudStatusPrefix.
  ///
  /// In en, this message translates to:
  /// **'AI: {status}'**
  String aiOverlayHudStatusPrefix(String status);

  /// No description provided for @aiOverlayResultPrefix.
  ///
  /// In en, this message translates to:
  /// **'Latest result: {result}'**
  String aiOverlayResultPrefix(String result);

  /// No description provided for @aiOverlayResultWaiting.
  ///
  /// In en, this message translates to:
  /// **'Latest result: waiting…'**
  String get aiOverlayResultWaiting;

  /// No description provided for @aiOverlayStateIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get aiOverlayStateIdle;

  /// No description provided for @aiOverlayStateLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get aiOverlayStateLocked;

  /// No description provided for @aiOverlayStateMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get aiOverlayStateMonitoring;

  /// No description provided for @aiOverlayStateStainDetect.
  ///
  /// In en, this message translates to:
  /// **'Contamination detection'**
  String get aiOverlayStateStainDetect;

  /// No description provided for @aiVisionAiEngineNotReady.
  ///
  /// In en, this message translates to:
  /// **'AI engine isn’t ready'**
  String get aiVisionAiEngineNotReady;

  /// No description provided for @aiVisionChooseBtn.
  ///
  /// In en, this message translates to:
  /// **'Select Video'**
  String get aiVisionChooseBtn;

  /// No description provided for @aiVisionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'AI Vision — coming soon'**
  String get aiVisionComingSoon;

  /// No description provided for @aiVisionDetectBtn.
  ///
  /// In en, this message translates to:
  /// **'Detect'**
  String get aiVisionDetectBtn;

  /// No description provided for @aiVisionInferenceVideoNotReady.
  ///
  /// In en, this message translates to:
  /// **'Result video isn’t ready yet'**
  String get aiVisionInferenceVideoNotReady;

  /// No description provided for @aiVisionMaterialTypeText.
  ///
  /// In en, this message translates to:
  /// **'Material Type'**
  String get aiVisionMaterialTypeText;

  /// No description provided for @aiVisionNavLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Vision'**
  String get aiVisionNavLabel;

  /// No description provided for @aiVisionOfflineInferenceNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Offline analysis isn’t available in the current AI library'**
  String get aiVisionOfflineInferenceNotAvailable;

  /// No description provided for @aiVisionProcessTypeText.
  ///
  /// In en, this message translates to:
  /// **'Process Type'**
  String get aiVisionProcessTypeText;

  /// No description provided for @aiVisionReinferBtn.
  ///
  /// In en, this message translates to:
  /// **'Re-detect'**
  String get aiVisionReinferBtn;

  /// No description provided for @aiVisionSelectBtn.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get aiVisionSelectBtn;

  /// No description provided for @aiVisionSelectVideoFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a video to analyze'**
  String get aiVisionSelectVideoFirst;

  /// No description provided for @aiVisionStreamFailureFirstFrameTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timed out waiting for first frame ({timeoutMs} ms)'**
  String aiVisionStreamFailureFirstFrameTimeout(int timeoutMs);

  /// No description provided for @aiVisionStreamFailurePlayerTimeout.
  ///
  /// In en, this message translates to:
  /// **'Player connection or stream timed out'**
  String get aiVisionStreamFailurePlayerTimeout;

  /// No description provided for @aiVisionStreamFailureRtspEvent.
  ///
  /// In en, this message translates to:
  /// **'RTSP error: {message}'**
  String aiVisionStreamFailureRtspEvent(String message);

  /// No description provided for @aiVisionStreamFailureStartCode.
  ///
  /// In en, this message translates to:
  /// **'Player start failed (code {code})'**
  String aiVisionStreamFailureStartCode(int code);

  /// No description provided for @aiVisionStreamFailureSurfaceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video surface isn’t ready'**
  String get aiVisionStreamFailureSurfaceUnavailable;

  /// No description provided for @aiVisionStreamFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown reason'**
  String get aiVisionStreamFailureUnknown;

  /// No description provided for @aiVisionStreamFailureUnsupportedVideo.
  ///
  /// In en, this message translates to:
  /// **'Unsupported video codec or decoder failed to start'**
  String get aiVisionStreamFailureUnsupportedVideo;

  /// No description provided for @aiVisionTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Vision'**
  String get aiVisionTitle;

  /// No description provided for @aiVisionUploadBtn.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get aiVisionUploadBtn;

  /// No description provided for @aiVisionVideoAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get aiVisionVideoAnalyzing;

  /// No description provided for @aiVisionVideoExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export result video: {error}'**
  String aiVisionVideoExportFailed(String error);

  /// No description provided for @aiVisionVideoExporting.
  ///
  /// In en, this message translates to:
  /// **'Generating result video…'**
  String get aiVisionVideoExporting;

  /// No description provided for @aiVisionVideoInferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Video analysis failed: {error}'**
  String aiVisionVideoInferenceFailed(String error);

  /// No description provided for @aiVisionVideoInferenceProgress.
  ///
  /// In en, this message translates to:
  /// **'Analyzing video… {percent}%'**
  String aiVisionVideoInferenceProgress(int percent);

  /// No description provided for @aiVisionVideoInferring.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get aiVisionVideoInferring;

  /// No description provided for @aiVisionVideoPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get aiVisionVideoPause;

  /// No description provided for @aiVisionVideoPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get aiVisionVideoPlay;

  /// No description provided for @aiVisionVideoReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get aiVisionVideoReplay;

  /// No description provided for @aiVisionWorkInfoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'-'**
  String get aiVisionWorkInfoUnavailable;

  /// No description provided for @aiVisualizedLabel.
  ///
  /// In en, this message translates to:
  /// **'Visualized'**
  String get aiVisualizedLabel;

  /// No description provided for @alarmFaultClearedContent.
  ///
  /// In en, this message translates to:
  /// **'This fault has cleared. You can resume work. If it happens often, contact LaserCyber support.'**
  String get alarmFaultClearedContent;

  /// No description provided for @alarmInfoLaserDevice.
  ///
  /// In en, this message translates to:
  /// **'Laser'**
  String get alarmInfoLaserDevice;

  /// No description provided for @alarmInfoWeldingGun.
  ///
  /// In en, this message translates to:
  /// **'Welding Gun'**
  String get alarmInfoWeldingGun;

  /// No description provided for @alarmInfoWireFeeder.
  ///
  /// In en, this message translates to:
  /// **'Wire Feeder'**
  String get alarmInfoWireFeeder;

  /// No description provided for @alarmLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarm Logs'**
  String get alarmLogsTitle;

  /// No description provided for @alarmRebootThenSupportContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get alarmRebootThenSupportContent;

  /// No description provided for @alarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get alarmTitle;

  /// No description provided for @autoOtaUpdateDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available. Download and install it in Settings.'**
  String autoOtaUpdateDialogMessage(String version);

  /// No description provided for @autoOtaUpdateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get autoOtaUpdateDialogTitle;

  /// No description provided for @blowOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Blow'**
  String get blowOnLabel;

  /// No description provided for @blowText.
  ///
  /// In en, this message translates to:
  /// **'Gas Flow'**
  String get blowText;

  /// No description provided for @blowingAirPressureText.
  ///
  /// In en, this message translates to:
  /// **'Shielding Gas Pressure'**
  String get blowingAirPressureText;

  /// No description provided for @bluetoothCloseFailedText.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t turn off Bluetooth'**
  String get bluetoothCloseFailedText;

  /// No description provided for @bluetoothClosedText.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth off'**
  String get bluetoothClosedText;

  /// No description provided for @bluetoothNotSupportedText.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth not supported'**
  String get bluetoothNotSupportedText;

  /// No description provided for @bluetoothOpenFailedText.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t turn on Bluetooth'**
  String get bluetoothOpenFailedText;

  /// No description provided for @bluetoothOpenedText.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth on'**
  String get bluetoothOpenedText;

  /// No description provided for @bluetoothSettings.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetoothSettings;

  /// No description provided for @bluetoothText.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetoothText;

  /// No description provided for @bluetoothAsSpeaker.
  ///
  /// In en, this message translates to:
  /// **'As a Speaker'**
  String get bluetoothAsSpeaker;

  /// No description provided for @bootSelfCheckClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get bootSelfCheckClose;

  /// No description provided for @bootSelfCheckControllerComm.
  ///
  /// In en, this message translates to:
  /// **'Controller Comm'**
  String get bootSelfCheckControllerComm;

  /// No description provided for @bootSelfCheckDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Startup Self-Check'**
  String get bootSelfCheckDialogTitle;

  /// No description provided for @bootSelfCheckDontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don’t show again'**
  String get bootSelfCheckDontShowAgain;

  /// No description provided for @bootSelfCheckStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get bootSelfCheckStatusChecking;

  /// No description provided for @bootSelfCheckStatusFail.
  ///
  /// In en, this message translates to:
  /// **'Fault'**
  String get bootSelfCheckStatusFail;

  /// No description provided for @bootSelfCheckStatusPass.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get bootSelfCheckStatusPass;

  /// No description provided for @bootSelfCheckStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get bootSelfCheckStatusSkipped;

  /// No description provided for @bundledFirmwareDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'A newer control board firmware is available ({currentVersion} → {newVersion}).\nKeep power connected and don’t operate the device during the upgrade.'**
  String bundledFirmwareDialogMessage(String currentVersion, String newVersion);

  /// No description provided for @bundledFirmwareDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Control Board Firmware Update'**
  String get bundledFirmwareDialogTitle;

  /// No description provided for @bundledFirmwareFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Control board firmware update failed. Try again later.'**
  String get bundledFirmwareFailedMessage;

  /// No description provided for @bundledFirmwareFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Firmware Update Failed'**
  String get bundledFirmwareFailedTitle;

  /// No description provided for @bundledFirmwareProgressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String bundledFirmwareProgressPercent(int percent);

  /// No description provided for @bundledFirmwareSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Control board firmware has been updated.'**
  String get bundledFirmwareSuccessMessage;

  /// No description provided for @bundledFirmwareSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Firmware Updated'**
  String get bundledFirmwareSuccessTitle;

  /// No description provided for @bundledFirmwareUpgradingMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep power connected and don’t operate the device during the upgrade.'**
  String get bundledFirmwareUpgradingMessage;

  /// No description provided for @bundledFirmwareUpgradingTitle.
  ///
  /// In en, this message translates to:
  /// **'Updating Control Board Firmware'**
  String get bundledFirmwareUpgradingTitle;

  /// No description provided for @callBackHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get callBackHomeTitle;

  /// No description provided for @cameraCommStatusText.
  ///
  /// In en, this message translates to:
  /// **'Camera Comm'**
  String get cameraCommStatusText;

  /// No description provided for @cameraCommunicationAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get cameraCommunicationAlarmContent;

  /// No description provided for @cameraCommunicationAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Communication Alarm'**
  String get cameraCommunicationAlarmTitle;

  /// No description provided for @cancelText.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelText;

  /// No description provided for @cellularNetworkText.
  ///
  /// In en, this message translates to:
  /// **'Cellular'**
  String get cellularNetworkText;

  /// No description provided for @celsiusUnit.
  ///
  /// In en, this message translates to:
  /// **'°C'**
  String get celsiusUnit;

  /// No description provided for @checkUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkUpdate;

  /// No description provided for @checkingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checkingStatus;

  /// No description provided for @clearAlarmLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAlarmLogs;

  /// No description provided for @closeText.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeText;

  /// No description provided for @coldWaterInterlockAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get coldWaterInterlockAlarmContent;

  /// No description provided for @coldWaterInterlockAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Coolant Interlock Alarm'**
  String get coldWaterInterlockAlarmTitle;

  /// No description provided for @collimatingLensOvertemperatureAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Collimating Lens Overtemperature'**
  String get collimatingLensOvertemperatureAlarmTitle;

  /// No description provided for @collimatorTempLabel.
  ///
  /// In en, this message translates to:
  /// **'Collimator'**
  String get collimatorTempLabel;

  /// No description provided for @collimatorTemperatureText.
  ///
  /// In en, this message translates to:
  /// **'Collimating Lens Temperature'**
  String get collimatorTemperatureText;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get commonSettings;

  /// No description provided for @commonSettingsGroupDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get commonSettingsGroupDateTime;

  /// No description provided for @commonSettingsGroupDisplaySound.
  ///
  /// In en, this message translates to:
  /// **'Display & Sound'**
  String get commonSettingsGroupDisplaySound;

  /// No description provided for @commonSettingsGroupMisc.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get commonSettingsGroupMisc;

  /// No description provided for @commonSettingsGroupNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get commonSettingsGroupNetwork;

  /// No description provided for @commonSettingsShowSafetyGroundLockAlarm.
  ///
  /// In en, this message translates to:
  /// **'Show Safety Clamp Alarm'**
  String get commonSettingsShowSafetyGroundLockAlarm;

  /// No description provided for @confirmText.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmText;

  /// No description provided for @connectedText.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectedText;

  /// No description provided for @controllerTabletCommAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get controllerTabletCommAlarmContent;

  /// No description provided for @controllerTabletCommAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Control Board Communication Error'**
  String get controllerTabletCommAlarmTitle;

  /// No description provided for @currentAlarmText.
  ///
  /// In en, this message translates to:
  /// **'Current Alarm'**
  String get currentAlarmText;

  /// No description provided for @customHomePage.
  ///
  /// In en, this message translates to:
  /// **'Custom Home'**
  String get customHomePage;

  /// No description provided for @cuttingProportionText.
  ///
  /// In en, this message translates to:
  /// **'Cutting Ratio'**
  String get cuttingProportionText;

  /// No description provided for @dateTimeApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update date/time'**
  String get dateTimeApplyFailed;

  /// No description provided for @dateTimeAutoDateTime.
  ///
  /// In en, this message translates to:
  /// **'Automatic Date & Time'**
  String get dateTimeAutoDateTime;

  /// No description provided for @dateTimeAutoSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Network time unavailable'**
  String get dateTimeAutoSyncFailed;

  /// No description provided for @dateTimeAutoSyncOff.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync is off'**
  String get dateTimeAutoSyncOff;

  /// No description provided for @dateTimeAutoSyncOffline.
  ///
  /// In en, this message translates to:
  /// **'No network — waiting to sync'**
  String get dateTimeAutoSyncOffline;

  /// No description provided for @dateTimeAutoSyncOk.
  ///
  /// In en, this message translates to:
  /// **'Network time synchronized'**
  String get dateTimeAutoSyncOk;

  /// No description provided for @dateTimeAutoSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing with network time…'**
  String get dateTimeAutoSyncing;

  /// No description provided for @dateTimeAutoTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Automatic Time Zone'**
  String get dateTimeAutoTimeZone;

  /// No description provided for @dateTimeAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get dateTimeAutomatic;

  /// No description provided for @dateTimeModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get dateTimeModeAuto;

  /// No description provided for @dateTimeModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get dateTimeModeManual;

  /// No description provided for @dateTimePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Missing system permission to change date/time'**
  String get dateTimePermissionDenied;

  /// No description provided for @dateTimeSearchTimezoneHint.
  ///
  /// In en, this message translates to:
  /// **'Search time zone (e.g. Asia/Shanghai)'**
  String get dateTimeSearchTimezoneHint;

  /// No description provided for @dateTimeSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get dateTimeSelectDate;

  /// No description provided for @dateTimeSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get dateTimeSelectTime;

  /// No description provided for @dateTimeSelectTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Select Time Zone'**
  String get dateTimeSelectTimeZone;

  /// No description provided for @dateTimeSetDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateTimeSetDate;

  /// No description provided for @dateTimeSetFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update date or time'**
  String get dateTimeSetFailed;

  /// No description provided for @dateTimeSetTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get dateTimeSetTime;

  /// No description provided for @dateTimeSetTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Time Zone'**
  String get dateTimeSetTimeZone;

  /// No description provided for @dateTimeSettings.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateTimeSettings;

  /// No description provided for @timezoneSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or UTC offset'**
  String get timezoneSearchHint;

  /// No description provided for @dateTimeTimezoneApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update time zone'**
  String get dateTimeTimezoneApplyFailed;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @deleteText.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteText;

  /// No description provided for @deviceInformation.
  ///
  /// In en, this message translates to:
  /// **'Device Info'**
  String get deviceInformation;

  /// No description provided for @deviceInformationText.
  ///
  /// In en, this message translates to:
  /// **'Device Info'**
  String get deviceInformationText;

  /// No description provided for @deviceModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get deviceModel;

  /// No description provided for @deviceMonitorHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get deviceMonitorHomeTitle;

  /// No description provided for @deviceMonitorMachineStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Machine Status'**
  String get deviceMonitorMachineStatusTitle;

  /// No description provided for @deviceMonitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Monitor'**
  String get deviceMonitorTitle;

  /// No description provided for @deviceMonitorWarnInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get deviceMonitorWarnInfoTitle;

  /// No description provided for @deviceMonitorWorkInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Work Info'**
  String get deviceMonitorWorkInfoTitle;

  /// No description provided for @deviceSettingText.
  ///
  /// In en, this message translates to:
  /// **'Device Settings'**
  String get deviceSettingText;

  /// No description provided for @deviceSn.
  ///
  /// In en, this message translates to:
  /// **'Device SN'**
  String get deviceSn;

  /// No description provided for @diodeShortCircuitAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get diodeShortCircuitAlarmContent;

  /// No description provided for @diodeShortCircuitAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Diode Short Circuit'**
  String get diodeShortCircuitAlarmTitle;

  /// No description provided for @diodeShortCircuitErrorClearedTitle.
  ///
  /// In en, this message translates to:
  /// **'Diode Short Circuit Cleared'**
  String get diodeShortCircuitErrorClearedTitle;

  /// No description provided for @dontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don’t show again'**
  String get dontShowAgain;

  /// No description provided for @driveOvertemperatureAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get driveOvertemperatureAlarmContent;

  /// No description provided for @driveOvertemperatureAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Overtemperature'**
  String get driveOvertemperatureAlarmTitle;

  /// No description provided for @driverBoardOvervoltageTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Board Overvoltage'**
  String get driverBoardOvervoltageTitle;

  /// No description provided for @driverModuleOvertemperatureAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get driverModuleOvertemperatureAlarmContent;

  /// No description provided for @driverModuleOvertemperatureAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Module Overtemperature'**
  String get driverModuleOvertemperatureAlarmTitle;

  /// No description provided for @emptyText.
  ///
  /// In en, this message translates to:
  /// **''**
  String get emptyText;

  /// No description provided for @environmentTemperatureAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Ambient temperature is out of the allowed range. Improve workshop cooling/heating. If the reading looks wrong, contact LaserCyber support.'**
  String get environmentTemperatureAlarmContent;

  /// No description provided for @environmentTemperatureAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Ambient Temperature Alarm'**
  String get environmentTemperatureAlarmTitle;

  /// No description provided for @environmentTemperatureText.
  ///
  /// In en, this message translates to:
  /// **'Ambient Temperature'**
  String get environmentTemperatureText;

  /// No description provided for @equipmentStatusBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get equipmentStatusBack;

  /// No description provided for @fahrenheitUnit.
  ///
  /// In en, this message translates to:
  /// **'°F'**
  String get fahrenheitUnit;

  /// No description provided for @failStatus.
  ///
  /// In en, this message translates to:
  /// **'Fault'**
  String get failStatus;

  /// No description provided for @fiberDisconnectionAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get fiberDisconnectionAlarmContent;

  /// No description provided for @fiberDisconnectionAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Fiber Disconnected'**
  String get fiberDisconnectionAlarmTitle;

  /// No description provided for @fiberTemperatureUpperLimitAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get fiberTemperatureUpperLimitAlarmContent;

  /// No description provided for @fiberTemperatureUpperLimitAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Fiber Temperature High'**
  String get fiberTemperatureUpperLimitAlarmTitle;

  /// No description provided for @fiberTemperatureUpperLimitClearedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fiber Temperature High Cleared'**
  String get fiberTemperatureUpperLimitClearedTitle;

  /// No description provided for @firmwareVersion.
  ///
  /// In en, this message translates to:
  /// **'Control Board Version'**
  String get firmwareVersion;

  /// No description provided for @flashErrorAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get flashErrorAlarmContent;

  /// No description provided for @flashErrorAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'FLASH Error'**
  String get flashErrorAlarmTitle;

  /// No description provided for @flashUnencryptedAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get flashUnencryptedAlarmContent;

  /// No description provided for @flashUnencryptedAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'FLASH Unencrypted'**
  String get flashUnencryptedAlarmTitle;

  /// No description provided for @frontLightPdVoltageText.
  ///
  /// In en, this message translates to:
  /// **'Forward PD Voltage'**
  String get frontLightPdVoltageText;

  /// No description provided for @galvanometerMotorOvercurrentAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get galvanometerMotorOvercurrentAlarmContent;

  /// No description provided for @galvanometerMotorOvercurrentAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Galvo Motor Overcurrent'**
  String get galvanometerMotorOvercurrentAlarmTitle;

  /// No description provided for @galvanometerMotorStallAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get galvanometerMotorStallAlarmContent;

  /// No description provided for @galvanometerMotorStallAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Galvo Motor Stall'**
  String get galvanometerMotorStallAlarmTitle;

  /// No description provided for @galvanometerMotorTrajectoryErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Galvo Motor Trajectory Error'**
  String get galvanometerMotorTrajectoryErrorTitle;

  /// No description provided for @gasPressureLabel.
  ///
  /// In en, this message translates to:
  /// **'Gas Pressure'**
  String get gasPressureLabel;

  /// No description provided for @gunHeadCommunicationAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Communication between the host and the welding gun failed. Check the gun cable and connectors. If the alarm continues after reconnecting, contact LaserCyber support.'**
  String get gunHeadCommunicationAlarmContent;

  /// No description provided for @gunHeadCommunicationAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Welding Gun Communication Alarm'**
  String get gunHeadCommunicationAlarmTitle;

  /// No description provided for @gunHeadCommunicationText.
  ///
  /// In en, this message translates to:
  /// **'Gun Comm'**
  String get gunHeadCommunicationText;

  /// No description provided for @gunHeadMotorOvertemperatureAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'The welding gun motor is overheating. Pause work and let it cool. If the alarm returns, contact LaserCyber support.'**
  String get gunHeadMotorOvertemperatureAlarmContent;

  /// No description provided for @gunHeadMotorOvertemperatureAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Welding Gun Motor Overtemperature'**
  String get gunHeadMotorOvertemperatureAlarmTitle;

  /// No description provided for @gunHeadSwitchText.
  ///
  /// In en, this message translates to:
  /// **'Gun Switch'**
  String get gunHeadSwitchText;

  /// No description provided for @gunSn.
  ///
  /// In en, this message translates to:
  /// **'Welding Gun SN'**
  String get gunSn;

  /// No description provided for @gunSwitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Gun Switch'**
  String get gunSwitchLabel;

  /// No description provided for @hardwareBusErrorAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get hardwareBusErrorAlarmContent;

  /// No description provided for @hardwareBusErrorAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Hardware Bus Error'**
  String get hardwareBusErrorAlarmTitle;

  /// No description provided for @homeAiVisionLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Vision'**
  String get homeAiVisionLabel;

  /// No description provided for @homeEngineerModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Engineer Mode'**
  String get homeEngineerModeLabel;

  /// No description provided for @homeMonitorLabel.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get homeMonitorLabel;

  /// No description provided for @homeQuickModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick Mode'**
  String get homeQuickModeLabel;

  /// No description provided for @homeSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettingsLabel;

  /// No description provided for @httpProxyAuthBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get httpProxyAuthBasic;

  /// No description provided for @httpProxyAuthNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get httpProxyAuthNone;

  /// No description provided for @httpProxyAuthType.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get httpProxyAuthType;

  /// No description provided for @httpProxyEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Proxy'**
  String get httpProxyEnable;

  /// No description provided for @httpProxyHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get httpProxyHost;

  /// No description provided for @httpProxyHostHint.
  ///
  /// In en, this message translates to:
  /// **'proxy.example.com'**
  String get httpProxyHostHint;

  /// No description provided for @httpProxyPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get httpProxyPassword;

  /// No description provided for @httpProxyPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get httpProxyPort;

  /// No description provided for @httpProxyPortHint.
  ///
  /// In en, this message translates to:
  /// **'8080'**
  String get httpProxyPortHint;

  /// No description provided for @httpProxySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get httpProxySave;

  /// No description provided for @httpProxySaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Proxy settings saved'**
  String get httpProxySaveSuccess;

  /// No description provided for @httpProxySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get httpProxySettingsTitle;

  /// No description provided for @httpProxyStatusIncomplete.
  ///
  /// In en, this message translates to:
  /// **'On (incomplete)'**
  String get httpProxyStatusIncomplete;

  /// No description provided for @httpProxyStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get httpProxyStatusOff;

  /// No description provided for @httpProxyTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get httpProxyTestConnection;

  /// No description provided for @httpProxyTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get httpProxyTestFailed;

  /// No description provided for @httpProxyTestNoOrigin.
  ///
  /// In en, this message translates to:
  /// **'No API origin available to test'**
  String get httpProxyTestNoOrigin;

  /// No description provided for @httpProxyTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get httpProxyTestSuccess;

  /// No description provided for @httpProxyTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get httpProxyTitle;

  /// No description provided for @httpProxyUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get httpProxyUsername;

  /// No description provided for @httpProxyValidationHostRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a host address'**
  String get httpProxyValidationHostRequired;

  /// No description provided for @httpProxyValidationPortInvalid.
  ///
  /// In en, this message translates to:
  /// **'Port must be 1–65535'**
  String get httpProxyValidationPortInvalid;

  /// No description provided for @httpProxyValidationUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required for Basic auth'**
  String get httpProxyValidationUsernameRequired;

  /// No description provided for @illegalInstructionAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get illegalInstructionAlarmContent;

  /// No description provided for @illegalInstructionAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Illegal Instruction'**
  String get illegalInstructionAlarmTitle;

  /// No description provided for @inUnit.
  ///
  /// In en, this message translates to:
  /// **'in'**
  String get inUnit;

  /// No description provided for @inputDialogTitleWithUnit.
  ///
  /// In en, this message translates to:
  /// **'{title} ({unit})'**
  String inputDialogTitleWithUnit(String title, String unit);

  /// No description provided for @internalHumidityExceedsTheUpperLimitAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Internal Humidity High'**
  String get internalHumidityExceedsTheUpperLimitAlarmTitle;

  /// No description provided for @internalHumidityUpperLimitAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get internalHumidityUpperLimitAlarmContent;

  /// No description provided for @ipCameraText.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get ipCameraText;

  /// No description provided for @cameraType.
  ///
  /// In en, this message translates to:
  /// **'Camera Type'**
  String get cameraType;

  /// No description provided for @cameraVersion.
  ///
  /// In en, this message translates to:
  /// **'Camera Version'**
  String get cameraVersion;

  /// No description provided for @cameraTypeBlueLight.
  ///
  /// In en, this message translates to:
  /// **'Blue Light'**
  String get cameraTypeBlueLight;

  /// No description provided for @cameraTypeRedLight.
  ///
  /// In en, this message translates to:
  /// **'Red Light'**
  String get cameraTypeRedLight;

  /// No description provided for @cameraStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get cameraStatus;

  /// No description provided for @cameraStatusEstablishing.
  ///
  /// In en, this message translates to:
  /// **'Establishing…'**
  String get cameraStatusEstablishing;

  /// No description provided for @cameraStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get cameraStatusFailed;

  /// No description provided for @systemVersion.
  ///
  /// In en, this message translates to:
  /// **'System Version'**
  String get systemVersion;

  /// No description provided for @processLibVersion.
  ///
  /// In en, this message translates to:
  /// **'Process Library Version'**
  String get processLibVersion;

  /// No description provided for @updateProcessLibrary.
  ///
  /// In en, this message translates to:
  /// **'Update Process Library'**
  String get updateProcessLibrary;

  /// No description provided for @processLibraryImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Process Library'**
  String get processLibraryImportTitle;

  /// No description provided for @processLibraryScanHint.
  ///
  /// In en, this message translates to:
  /// **'Place a package (manifest.json + library JSON) under /var/lib/hmi/incoming/process-library/, /userdata/ota/process-library/, or a USB volume, then scan.'**
  String get processLibraryScanHint;

  /// No description provided for @processLibraryNoPackages.
  ///
  /// In en, this message translates to:
  /// **'No process-library packages found.'**
  String get processLibraryNoPackages;

  /// No description provided for @processLibraryRescan.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get processLibraryRescan;

  /// No description provided for @processLibraryImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get processLibraryImportAction;

  /// No description provided for @processLibraryImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get processLibraryImporting;

  /// No description provided for @processLibraryModelMatch.
  ///
  /// In en, this message translates to:
  /// **'Matches this device'**
  String get processLibraryModelMatch;

  /// No description provided for @processLibraryModelMismatch.
  ///
  /// In en, this message translates to:
  /// **'Model not preferred'**
  String get processLibraryModelMismatch;

  /// No description provided for @processLibraryAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Import report'**
  String get processLibraryAuditTitle;

  /// No description provided for @processLibraryAuditImported.
  ///
  /// In en, this message translates to:
  /// **'Imported successfully'**
  String get processLibraryAuditImported;

  /// No description provided for @processLibraryAuditCurrent.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get processLibraryAuditCurrent;

  /// No description provided for @processLibraryAuditRejected.
  ///
  /// In en, this message translates to:
  /// **'Import rejected'**
  String get processLibraryAuditRejected;

  /// No description provided for @processLibraryAuditNoCompatible.
  ///
  /// In en, this message translates to:
  /// **'No compatible library for this model'**
  String get processLibraryAuditNoCompatible;

  /// No description provided for @processLibraryAuditFromTo.
  ///
  /// In en, this message translates to:
  /// **'Version: {from} → {to}'**
  String processLibraryAuditFromTo(String from, String to);

  /// No description provided for @processLibraryAuditRows.
  ///
  /// In en, this message translates to:
  /// **'Rows: {count}'**
  String processLibraryAuditRows(int count);

  /// No description provided for @processLibraryAuditUsersKept.
  ///
  /// In en, this message translates to:
  /// **'User presets kept: {count}'**
  String processLibraryAuditUsersKept(int count);

  /// No description provided for @processLibraryAuditPath.
  ///
  /// In en, this message translates to:
  /// **'Package: {path}'**
  String processLibraryAuditPath(String path);

  /// No description provided for @focusScaleReference.
  ///
  /// In en, this message translates to:
  /// **'Focus Scale Reference'**
  String get focusScaleReference;

  /// No description provided for @kernelVersion.
  ///
  /// In en, this message translates to:
  /// **'Kernel Version'**
  String get kernelVersion;

  /// No description provided for @autoCheckOtaUpdate.
  ///
  /// In en, this message translates to:
  /// **'Automatically check for updates'**
  String get autoCheckOtaUpdate;

  /// No description provided for @otaCheckUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Software update check is not available on this build.'**
  String get otaCheckUnavailable;

  /// No description provided for @cloudEnvironmentTier.
  ///
  /// In en, this message translates to:
  /// **'Cloud Environment'**
  String get cloudEnvironmentTier;

  /// No description provided for @cloudEnvironmentTierDev.
  ///
  /// In en, this message translates to:
  /// **'Dev'**
  String get cloudEnvironmentTierDev;

  /// No description provided for @cloudEnvironmentTierTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get cloudEnvironmentTierTest;

  /// No description provided for @cloudEnvironmentTierProd.
  ///
  /// In en, this message translates to:
  /// **'Prod'**
  String get cloudEnvironmentTierProd;

  /// No description provided for @deviceRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register This Device'**
  String get deviceRegisterTitle;

  /// No description provided for @deviceRegisterBody.
  ///
  /// In en, this message translates to:
  /// **'This device is unrecognized, please scan the QR code with LaserCyber app to register it.'**
  String get deviceRegisterBody;

  /// No description provided for @deviceRegisterReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get deviceRegisterReconnect;

  /// No description provided for @deviceBindTitle.
  ///
  /// In en, this message translates to:
  /// **'Bind This Device'**
  String get deviceBindTitle;

  /// No description provided for @deviceBindBody.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code with the LaserCyber app to bind this device.'**
  String get deviceBindBody;

  /// No description provided for @deviceRemoteLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Locked'**
  String get deviceRemoteLockTitle;

  /// No description provided for @deviceRemoteLockBody.
  ///
  /// In en, this message translates to:
  /// **'This device has been locked remotely. Contact your administrator to unlock.'**
  String get deviceRemoteLockBody;

  /// No description provided for @screenOffNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get screenOffNever;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @keyboardText.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get keyboardText;

  /// No description provided for @languageAppliesToUi.
  ///
  /// In en, this message translates to:
  /// **'Applies to the product UI language and soft keyboard.'**
  String get languageAppliesToUi;

  /// No description provided for @languageOptionChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageOptionChinese;

  /// No description provided for @languageOptionEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageOptionEnglish;

  /// No description provided for @languageOptionTraditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageOptionTraditionalChinese;

  /// No description provided for @languagePreferenceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Language preference unavailable.'**
  String get languagePreferenceUnavailable;

  /// No description provided for @languageSettingText.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettingText;

  /// No description provided for @laserCommunicationAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Confirm that the Reset button has been pressed. If it still doesn’t recover, power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get laserCommunicationAlarmContent;

  /// No description provided for @laserCommunicationAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Laser Communication Alarm'**
  String get laserCommunicationAlarmTitle;

  /// No description provided for @laserCurrentAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get laserCurrentAlarmContent;

  /// No description provided for @laserCurrentAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Laser Current Alarm'**
  String get laserCurrentAlarmTitle;

  /// No description provided for @laserCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Laser Current'**
  String get laserCurrentLabel;

  /// No description provided for @laserDriverCommunicationAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get laserDriverCommunicationAlarmContent;

  /// No description provided for @laserDriverCommunicationAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Laser Driver Communication Alarm'**
  String get laserDriverCommunicationAlarmTitle;

  /// No description provided for @laserEmergencyStopAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Laser E-stop is active. Release the emergency stop and reset the machine before continuing.'**
  String get laserEmergencyStopAlarmContent;

  /// No description provided for @laserEmergencyStopAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Laser E-Stop Alarm'**
  String get laserEmergencyStopAlarmTitle;

  /// No description provided for @laserOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Laser'**
  String get laserOnLabel;

  /// No description provided for @laserOutputEnergyLowerLimitAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Laser output energy is below the limit. Check the protective lens and process power setting. If it continues, contact LaserCyber support.'**
  String get laserOutputEnergyLowerLimitAlarmContent;

  /// No description provided for @laserOutputEnergyLowerLimitAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Laser Output Energy Low'**
  String get laserOutputEnergyLowerLimitAlarmTitle;

  /// No description provided for @laserOutputEnergyLowerLimitClearedTitle.
  ///
  /// In en, this message translates to:
  /// **'Output Energy Low Cleared'**
  String get laserOutputEnergyLowerLimitClearedTitle;

  /// No description provided for @laserReflectedEnergyUpperLimitAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Reflected laser energy is too high. Stop emission and check workpiece angle, joint fit-up, and process parameters. If it continues, contact LaserCyber support.'**
  String get laserReflectedEnergyUpperLimitAlarmContent;

  /// No description provided for @laserReflectedEnergyUpperLimitAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reflected Laser Energy High'**
  String get laserReflectedEnergyUpperLimitAlarmTitle;

  /// No description provided for @laserReflectedEnergyUpperLimitClearedTitle.
  ///
  /// In en, this message translates to:
  /// **'Reflected Energy High Cleared'**
  String get laserReflectedEnergyUpperLimitClearedTitle;

  /// No description provided for @laserText.
  ///
  /// In en, this message translates to:
  /// **'Laser'**
  String get laserText;

  /// No description provided for @laserVersion.
  ///
  /// In en, this message translates to:
  /// **'Laser Version'**
  String get laserVersion;

  /// No description provided for @lensHeavyContaminationAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Protective lens is heavily contaminated. Clean or replace it.'**
  String get lensHeavyContaminationAlarmContent;

  /// No description provided for @lensHeavyContaminationAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Lens Contamination Alarm'**
  String get lensHeavyContaminationAlarmTitle;

  /// No description provided for @loadingText.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingText;

  /// No description provided for @machineBlowContent.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get machineBlowContent;

  /// No description provided for @machineBlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Gas'**
  String get machineBlowTitle;

  /// No description provided for @machineLaserCurrentContent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get machineLaserCurrentContent;

  /// No description provided for @machineLaserCurrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Laser'**
  String get machineLaserCurrentTitle;

  /// No description provided for @machinePumpContent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get machinePumpContent;

  /// No description provided for @machinePumpTitle.
  ///
  /// In en, this message translates to:
  /// **'Pump'**
  String get machinePumpTitle;

  /// No description provided for @machineTitle.
  ///
  /// In en, this message translates to:
  /// **'Machine Status'**
  String get machineTitle;

  /// No description provided for @mainControllerTempBoardCommAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get mainControllerTempBoardCommAlarmContent;

  /// No description provided for @mainControllerTempBoardCommAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Main Controller–Temperature Board Communication Fault'**
  String get mainControllerTempBoardCommAlarmTitle;

  /// No description provided for @memoryAccessErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory Access Error'**
  String get memoryAccessErrorTitle;

  /// No description provided for @memoryManagementErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory Management Error'**
  String get memoryManagementErrorTitle;

  /// No description provided for @mmUnit.
  ///
  /// In en, this message translates to:
  /// **'mm'**
  String get mmUnit;

  /// No description provided for @mmiOscillatorMalfunctionAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get mmiOscillatorMalfunctionAlarmContent;

  /// No description provided for @mmiOscillatorMalfunctionAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'MMI Oscillator Fault'**
  String get mmiOscillatorMalfunctionAlarmTitle;

  /// No description provided for @modbusCommunicationFault.
  ///
  /// In en, this message translates to:
  /// **'Modbus communication fault'**
  String get modbusCommunicationFault;

  /// No description provided for @monitorNavLabel.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get monitorNavLabel;

  /// No description provided for @motorCableOpenAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get motorCableOpenAlarmContent;

  /// No description provided for @motorCableOpenAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Motor Cable Open'**
  String get motorCableOpenAlarmTitle;

  /// No description provided for @motorDriverTempLabel.
  ///
  /// In en, this message translates to:
  /// **'Motor Driver'**
  String get motorDriverTempLabel;

  /// No description provided for @motorDriverTemperatureText.
  ///
  /// In en, this message translates to:
  /// **'Motor Driver Temperature'**
  String get motorDriverTemperatureText;

  /// No description provided for @motorTempLabel.
  ///
  /// In en, this message translates to:
  /// **'Motor'**
  String get motorTempLabel;

  /// No description provided for @mouseText.
  ///
  /// In en, this message translates to:
  /// **'Mouse'**
  String get mouseText;

  /// No description provided for @narrowPulseProtectionAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Narrow-pulse protection was triggered. Adjust process parameters and try again. If it keeps happening, contact LaserCyber support.'**
  String get narrowPulseProtectionAlarmContent;

  /// No description provided for @narrowPulseProtectionAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Narrow Pulse Protection'**
  String get narrowPulseProtectionAlarmTitle;

  /// No description provided for @networkSettingText.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkSettingText;

  /// No description provided for @networkSettings.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkSettings;

  /// No description provided for @noActiveAlarms.
  ///
  /// In en, this message translates to:
  /// **'No active alarms'**
  String get noActiveAlarms;

  /// No description provided for @noSignedProcessLibrary.
  ///
  /// In en, this message translates to:
  /// **'No signed process library installed'**
  String get noSignedProcessLibrary;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get notConnected;

  /// No description provided for @notConnectingText.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnectingText;

  /// No description provided for @notPersistedYet.
  ///
  /// In en, this message translates to:
  /// **'Not persisted yet'**
  String get notPersistedYet;

  /// No description provided for @offLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get offLabel;

  /// No description provided for @okText.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okText;

  /// No description provided for @onLabel.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get onLabel;

  /// No description provided for @otaUpgradeStatusApk.
  ///
  /// In en, this message translates to:
  /// **'Installing app…'**
  String get otaUpgradeStatusApk;

  /// No description provided for @otaUpgradeStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get otaUpgradeStatusDownloading;

  /// No description provided for @otaUpgradeStatusFirmware.
  ///
  /// In en, this message translates to:
  /// **'Updating control board firmware ({percent}%)'**
  String otaUpgradeStatusFirmware(int percent);

  /// No description provided for @otaUpgradeStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing upgrade…'**
  String get otaUpgradeStatusPreparing;

  /// No description provided for @otaUpgradeStatusSystem.
  ///
  /// In en, this message translates to:
  /// **'Updating system…'**
  String get otaUpgradeStatusSystem;

  /// No description provided for @overTempLabel.
  ///
  /// In en, this message translates to:
  /// **'OVER TEMP'**
  String get overTempLabel;

  /// No description provided for @passStatus.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get passStatus;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get pleaseWait;

  /// No description provided for @positioningLightFaultAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'The red pointer (aiming beam) has a fault. Check whether the aiming beam is on; if not, contact LaserCyber support.'**
  String get positioningLightFaultAlarmContent;

  /// No description provided for @positioningLightFaultAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Red Pointer Fault'**
  String get positioningLightFaultAlarmTitle;

  /// No description provided for @protectiveLensOvertemperatureAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'If the protective lens shows burn marks, replace it immediately.'**
  String get protectiveLensOvertemperatureAlarmContent;

  /// No description provided for @protectiveLensOvertemperatureAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Protective Lens Overtemperature'**
  String get protectiveLensOvertemperatureAlarmTitle;

  /// No description provided for @protectiveMirrorTempLabel.
  ///
  /// In en, this message translates to:
  /// **'Protective Mirror'**
  String get protectiveMirrorTempLabel;

  /// No description provided for @protectiveMirrorTemperatureText.
  ///
  /// In en, this message translates to:
  /// **'Protective Lens Temperature'**
  String get protectiveMirrorTemperatureText;

  /// No description provided for @pumpBoardTemperatureText.
  ///
  /// In en, this message translates to:
  /// **'Pump Board Temperature'**
  String get pumpBoardTemperatureText;

  /// No description provided for @pumpCurrentText.
  ///
  /// In en, this message translates to:
  /// **'Pump Current'**
  String get pumpCurrentText;

  /// No description provided for @pumpModuleOvertemperatureAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get pumpModuleOvertemperatureAlarmContent;

  /// No description provided for @pumpModuleOvertemperatureAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Pump Module Overtemperature'**
  String get pumpModuleOvertemperatureAlarmTitle;

  /// No description provided for @pumpModuleOvertemperatureClearedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pump Module Overtemperature Cleared'**
  String get pumpModuleOvertemperatureClearedTitle;

  /// No description provided for @pumpSourceTemperatureAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get pumpSourceTemperatureAlarmContent;

  /// No description provided for @pumpSourceTemperatureAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Pump Temperature Alarm'**
  String get pumpSourceTemperatureAlarmTitle;

  /// No description provided for @pumpSourceVoltageAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get pumpSourceVoltageAlarmContent;

  /// No description provided for @pumpSourceVoltageAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Pump Voltage Alarm'**
  String get pumpSourceVoltageAlarmTitle;

  /// No description provided for @pumpStatusText.
  ///
  /// In en, this message translates to:
  /// **'Pump Comm'**
  String get pumpStatusText;

  /// No description provided for @pumpTemperatureText.
  ///
  /// In en, this message translates to:
  /// **'Pump Temperature'**
  String get pumpTemperatureText;

  /// No description provided for @quiescentCurrentAbnormalAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get quiescentCurrentAbnormalAlarmContent;

  /// No description provided for @quiescentCurrentAbnormalAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Abnormal Quiescent Current'**
  String get quiescentCurrentAbnormalAlarmTitle;

  /// No description provided for @redLightCurrentAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get redLightCurrentAlarmContent;

  /// No description provided for @redLightCurrentAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Red Pointer Current Alarm'**
  String get redLightCurrentAlarmTitle;

  /// No description provided for @redLightCurrentText.
  ///
  /// In en, this message translates to:
  /// **'Red Pointer Current'**
  String get redLightCurrentText;

  /// No description provided for @redLightLabel.
  ///
  /// In en, this message translates to:
  /// **'Red Light'**
  String get redLightLabel;

  /// No description provided for @redLightText.
  ///
  /// In en, this message translates to:
  /// **'Red Pointer'**
  String get redLightText;

  /// No description provided for @rgbLedText.
  ///
  /// In en, this message translates to:
  /// **'RGB LED'**
  String get rgbLedText;

  /// No description provided for @rgbLedFooter.
  ///
  /// In en, this message translates to:
  /// **'Use these controls to test the status LED indicators on this device.'**
  String get rgbLedFooter;

  /// No description provided for @safetyLockLabel.
  ///
  /// In en, this message translates to:
  /// **'Safety Lock'**
  String get safetyLockLabel;

  /// No description provided for @safetyGroundLockNotConnectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Connect the safety clamp before enabling the laser.'**
  String get safetyGroundLockNotConnectedMessage;

  /// No description provided for @safetyGroundLockNotConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety Clamp Disconnected'**
  String get safetyGroundLockNotConnectedTitle;

  /// No description provided for @safetyLockText.
  ///
  /// In en, this message translates to:
  /// **'Safety Clamp'**
  String get safetyLockText;

  /// No description provided for @screenBrightnessText.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get screenBrightnessText;

  /// No description provided for @screenDisplayText.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get screenDisplayText;

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

  /// No description provided for @screenOffTimeText.
  ///
  /// In en, this message translates to:
  /// **'Auto Screen Off'**
  String get screenOffTimeText;

  /// No description provided for @screenSettings.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get screenSettings;

  /// No description provided for @sensorAbnormalAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get sensorAbnormalAlarmContent;

  /// No description provided for @sensorAbnormalAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sensor Fault'**
  String get sensorAbnormalAlarmTitle;

  /// No description provided for @sensorChannelDeviationAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get sensorChannelDeviationAlarmContent;

  /// No description provided for @sensorChannelDeviationAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sensor Channel Deviation'**
  String get sensorChannelDeviationAlarmTitle;

  /// No description provided for @settingsNavLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsNavLabel;

  /// No description provided for @settingsTabAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsTabAdvanced;

  /// No description provided for @settingsTabCommon.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsTabCommon;

  /// No description provided for @settingsTabCustomHome.
  ///
  /// In en, this message translates to:
  /// **'Custom Home'**
  String get settingsTabCustomHome;

  /// No description provided for @settingsTabDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device Info'**
  String get settingsTabDeviceInfo;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @shieldingGasAlarmCauseBlowPressure.
  ///
  /// In en, this message translates to:
  /// **'Shielding gas pressure too low'**
  String get shieldingGasAlarmCauseBlowPressure;

  /// No description provided for @shieldingGasAlarmCauseDeviceService.
  ///
  /// In en, this message translates to:
  /// **'Equipment fault, please contact after-sales service'**
  String get shieldingGasAlarmCauseDeviceService;

  /// No description provided for @shieldingGasAlarmCauseInletPressure.
  ///
  /// In en, this message translates to:
  /// **'Inlet gas pressure too low'**
  String get shieldingGasAlarmCauseInletPressure;

  /// No description provided for @shieldingGasAlarmCausePressureCheck.
  ///
  /// In en, this message translates to:
  /// **'Gas pressure check abnormal'**
  String get shieldingGasAlarmCausePressureCheck;

  /// No description provided for @shieldingGasAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Please check if the shielding gas is on and if the gas cylinder is low. If the machine still alarms after confirming these are correct, please contact after-sales service.'**
  String get shieldingGasAlarmContent;

  /// No description provided for @shieldingGasAlarmEngineerCheckMessage.
  ///
  /// In en, this message translates to:
  /// **'Shielding gas fault: {reason}'**
  String shieldingGasAlarmEngineerCheckMessage(String reason);

  /// No description provided for @shieldingGasAlarmLogMessage.
  ///
  /// In en, this message translates to:
  /// **'A001 shielding gas alarm, reason: {reason}'**
  String shieldingGasAlarmLogMessage(String reason);

  /// No description provided for @shieldingGasAlarmReasonBullet.
  ///
  /// In en, this message translates to:
  /// **'· {reason}'**
  String shieldingGasAlarmReasonBullet(String reason);

  /// No description provided for @shieldingGasAlarmReasonHeader.
  ///
  /// In en, this message translates to:
  /// **'Reason:'**
  String get shieldingGasAlarmReasonHeader;

  /// No description provided for @shieldingGasAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Shielding Gas Alarm'**
  String get shieldingGasAlarmTitle;

  /// No description provided for @shieldingGasAlarmWarnLogContent.
  ///
  /// In en, this message translates to:
  /// **'{summary}. If the machine still alarms after confirming these are correct, please contact after-sales service.'**
  String shieldingGasAlarmWarnLogContent(String summary);

  /// No description provided for @showStartupSelfCheck.
  ///
  /// In en, this message translates to:
  /// **'Show Startup Self-Check'**
  String get showStartupSelfCheck;

  /// No description provided for @showSystemStatusOverlay.
  ///
  /// In en, this message translates to:
  /// **'Show System Status Overlay'**
  String get showSystemStatusOverlay;

  /// No description provided for @soundEffectCheck.
  ///
  /// In en, this message translates to:
  /// **'Sound Effect'**
  String get soundEffectCheck;

  /// No description provided for @soundEffectOption1.
  ///
  /// In en, this message translates to:
  /// **'Sound 1'**
  String get soundEffectOption1;

  /// No description provided for @soundEffectOption2.
  ///
  /// In en, this message translates to:
  /// **'Sound 2'**
  String get soundEffectOption2;

  /// No description provided for @soundEffectOption3.
  ///
  /// In en, this message translates to:
  /// **'Sound 3'**
  String get soundEffectOption3;

  /// No description provided for @soundSettings.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundSettings;

  /// No description provided for @sshDebugText.
  ///
  /// In en, this message translates to:
  /// **'SSH Debug'**
  String get sshDebugText;

  /// No description provided for @sshDebugFooter.
  ///
  /// In en, this message translates to:
  /// **'When enabled, you can connect to this device over the network for remote troubleshooting. Turns off after reboot. USB debugging is set separately under USB OTG.'**
  String get sshDebugFooter;

  /// No description provided for @settingsMayRestartApp.
  ///
  /// In en, this message translates to:
  /// **'Some of the settings may restart the application.'**
  String get settingsMayRestartApp;

  /// No description provided for @straightTrackTemperatureAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Inspect the collimating lens. If the collimating lens has burn marks, replace it immediately.'**
  String get straightTrackTemperatureAlarmContent;

  /// No description provided for @tempBoardRefrigerationCommAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get tempBoardRefrigerationCommAlarmContent;

  /// No description provided for @tempBoardRefrigerationCommAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Temperature Board–Cooling Communication Fault'**
  String get tempBoardRefrigerationCommAlarmTitle;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @undervoltage24vAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get undervoltage24vAlarmContent;

  /// No description provided for @undervoltage24vAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'24 V Undervoltage'**
  String get undervoltage24vAlarmTitle;

  /// No description provided for @unitImperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get unitImperial;

  /// No description provided for @unitMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get unitMetric;

  /// No description provided for @unitOptionImperial.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get unitOptionImperial;

  /// No description provided for @unitOptionMetric.
  ///
  /// In en, this message translates to:
  /// **'MM'**
  String get unitOptionMetric;

  /// No description provided for @unitPersistedFooter.
  ///
  /// In en, this message translates to:
  /// **'Choose Metric (°C, mm) or Imperial (°F, in) for values shown on this device.'**
  String get unitPersistedFooter;

  /// No description provided for @unitPreferenceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unit settings are temporarily unavailable.'**
  String get unitPreferenceUnavailable;

  /// No description provided for @unitSettingText.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitSettingText;

  /// No description provided for @usbOtgModeDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get usbOtgModeDebug;

  /// No description provided for @usbOtgModeHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get usbOtgModeHost;

  /// No description provided for @usbOtgModeMtp.
  ///
  /// In en, this message translates to:
  /// **'MTP'**
  String get usbOtgModeMtp;

  /// No description provided for @usbOtgText.
  ///
  /// In en, this message translates to:
  /// **'USB OTG'**
  String get usbOtgText;

  /// No description provided for @videosTitle.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videosTitle;

  /// No description provided for @processVideoRecordingTime.
  ///
  /// In en, this message translates to:
  /// **'Recording Time'**
  String get processVideoRecordingTime;

  /// No description provided for @processVideoWorkMode.
  ///
  /// In en, this message translates to:
  /// **'Work Mode'**
  String get processVideoWorkMode;

  /// No description provided for @processVideoMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get processVideoMaterial;

  /// No description provided for @processVideoDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get processVideoDuration;

  /// No description provided for @processVideoOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get processVideoOperations;

  /// No description provided for @processVideoEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recordings'**
  String get processVideoEmptyTitle;

  /// No description provided for @processVideoEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record Work videos from Quick or Engineer mode will appear here.'**
  String get processVideoEmptySubtitle;

  /// No description provided for @processVideoDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recording?'**
  String get processVideoDeleteConfirmTitle;

  /// No description provided for @processVideoDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the video file and its process parameters from this device.'**
  String get processVideoDeleteConfirmMessage;

  /// No description provided for @processVideoDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Details'**
  String get processVideoDetailTitle;

  /// No description provided for @processVideoParametersTitle.
  ///
  /// In en, this message translates to:
  /// **'Parameter recording'**
  String get processVideoParametersTitle;

  /// No description provided for @processVideoPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to play this recording'**
  String get processVideoPlaybackFailed;

  /// No description provided for @processVideoLoadedCount.
  ///
  /// In en, this message translates to:
  /// **'{loaded} / {total}'**
  String processVideoLoadedCount(int loaded, int total);

  /// No description provided for @recordWorkLabel.
  ///
  /// In en, this message translates to:
  /// **'Record Work'**
  String get recordWorkLabel;

  /// No description provided for @processVideoRecordingTooShort.
  ///
  /// In en, this message translates to:
  /// **'Recording too short — not saved'**
  String get processVideoRecordingTooShort;

  /// No description provided for @processVideoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save recording'**
  String get processVideoSaveFailed;

  /// No description provided for @ipCameraDemoRecordHint.
  ///
  /// In en, this message translates to:
  /// **'Demo only — not listed in Monitor → Videos'**
  String get ipCameraDemoRecordHint;

  /// No description provided for @volumeSetFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t set volume'**
  String get volumeSetFailed;

  /// No description provided for @volumeSettingText.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volumeSettingText;

  /// No description provided for @warnInfoLastWork.
  ///
  /// In en, this message translates to:
  /// **'Last Op-Time'**
  String get warnInfoLastWork;

  /// No description provided for @warnInfoLightTime.
  ///
  /// In en, this message translates to:
  /// **'Total Laser-On Time'**
  String get warnInfoLightTime;

  /// No description provided for @warnInfoLightTimeInfo.
  ///
  /// In en, this message translates to:
  /// **'vs. last week'**
  String get warnInfoLightTimeInfo;

  /// No description provided for @warnInfoWeldingConsumables.
  ///
  /// In en, this message translates to:
  /// **'Total Wire Used'**
  String get warnInfoWeldingConsumables;

  /// No description provided for @warnInfoWeldingConsumablesInfo.
  ///
  /// In en, this message translates to:
  /// **'Common consumables'**
  String get warnInfoWeldingConsumablesInfo;

  /// No description provided for @washProportionText.
  ///
  /// In en, this message translates to:
  /// **'Cleaning Ratio'**
  String get washProportionText;

  /// No description provided for @waterTemperatureUpperLimitAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get waterTemperatureUpperLimitAlarmContent;

  /// No description provided for @waterTemperatureUpperLimitAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Water Temperature High'**
  String get waterTemperatureUpperLimitAlarmTitle;

  /// No description provided for @weldingProportionText.
  ///
  /// In en, this message translates to:
  /// **'Welding Ratio'**
  String get weldingProportionText;

  /// No description provided for @wifiAdvancedSettings.
  ///
  /// In en, this message translates to:
  /// **'IP Settings'**
  String get wifiAdvancedSettings;

  /// No description provided for @wifiAdvancedSettingsHide.
  ///
  /// In en, this message translates to:
  /// **'Hide IP Settings'**
  String get wifiAdvancedSettingsHide;

  /// No description provided for @wifiApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get wifiApply;

  /// No description provided for @wifiDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi Details'**
  String get wifiDetailsTitle;

  /// No description provided for @wifiDialogConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get wifiDialogConnect;

  /// No description provided for @wifiDialogHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get wifiDialogHidePassword;

  /// No description provided for @wifiDialogPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get wifiDialogPasswordLabel;

  /// No description provided for @wifiDialogShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get wifiDialogShowPassword;

  /// No description provided for @wifiDialogSsidLabel.
  ///
  /// In en, this message translates to:
  /// **'Network Name'**
  String get wifiDialogSsidLabel;

  /// No description provided for @wifiDns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get wifiDns;

  /// No description provided for @wifiDns1.
  ///
  /// In en, this message translates to:
  /// **'DNS 1'**
  String get wifiDns1;

  /// No description provided for @wifiDns2.
  ///
  /// In en, this message translates to:
  /// **'DNS 2'**
  String get wifiDns2;

  /// No description provided for @wifiEditIpConfig.
  ///
  /// In en, this message translates to:
  /// **'Edit IP Configuration'**
  String get wifiEditIpConfig;

  /// No description provided for @wifiEditIpSuccess.
  ///
  /// In en, this message translates to:
  /// **'IP configuration saved'**
  String get wifiEditIpSuccess;

  /// No description provided for @wifiErrorAddNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Request denied. Allow Wi‑Fi suggestions for this app.'**
  String get wifiErrorAddNotAllowed;

  /// No description provided for @wifiErrorDuplicateProfile.
  ///
  /// In en, this message translates to:
  /// **'This Wi‑Fi profile already exists'**
  String get wifiErrorDuplicateProfile;

  /// No description provided for @wifiErrorInternal.
  ///
  /// In en, this message translates to:
  /// **'System error while saving the Wi‑Fi profile'**
  String get wifiErrorInternal;

  /// No description provided for @wifiErrorRemoveInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid saved Wi‑Fi profile'**
  String get wifiErrorRemoveInvalid;

  /// No description provided for @wifiErrorSaveFailedFormat.
  ///
  /// In en, this message translates to:
  /// **'Failed to save Wi‑Fi profile (code {code})'**
  String wifiErrorSaveFailedFormat(int code);

  /// No description provided for @wifiErrorTooManyProfiles.
  ///
  /// In en, this message translates to:
  /// **'Too many saved Wi‑Fi profiles for this app'**
  String get wifiErrorTooManyProfiles;

  /// No description provided for @wifiForgetConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Forget this network and disconnect?'**
  String get wifiForgetConfirmMessage;

  /// No description provided for @wifiForgetNetwork.
  ///
  /// In en, this message translates to:
  /// **'Forget Network'**
  String get wifiForgetNetwork;

  /// No description provided for @wifiForgetPartialFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t fully forget this network'**
  String get wifiForgetPartialFailed;

  /// No description provided for @wifiForgetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Network forgotten'**
  String get wifiForgetSuccess;

  /// No description provided for @wifiFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get wifiFrequency;

  /// No description provided for @wifiGateway.
  ///
  /// In en, this message translates to:
  /// **'Gateway'**
  String get wifiGateway;

  /// No description provided for @wifiHiddenNetworkConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect to Hidden Network'**
  String get wifiHiddenNetworkConnect;

  /// No description provided for @wifiHiddenNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to Hidden Network'**
  String get wifiHiddenNetworkTitle;

  /// No description provided for @wifiIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get wifiIpAddress;

  /// No description provided for @wifiIpFieldEnterHint.
  ///
  /// In en, this message translates to:
  /// **'Enter {field}'**
  String wifiIpFieldEnterHint(String field);

  /// No description provided for @wifiIpMode.
  ///
  /// In en, this message translates to:
  /// **'IP Mode'**
  String get wifiIpMode;

  /// No description provided for @wifiIpModeDhcp.
  ///
  /// In en, this message translates to:
  /// **'DHCP'**
  String get wifiIpModeDhcp;

  /// No description provided for @wifiIpModeStatic.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get wifiIpModeStatic;

  /// No description provided for @wifiIpSettings.
  ///
  /// In en, this message translates to:
  /// **'IP Settings'**
  String get wifiIpSettings;

  /// No description provided for @wifiIpSettingsHide.
  ///
  /// In en, this message translates to:
  /// **'Hide IP Settings'**
  String get wifiIpSettingsHide;

  /// No description provided for @wifiJoinSsidFormat.
  ///
  /// In en, this message translates to:
  /// **'Join “{ssid}”'**
  String wifiJoinSsidFormat(String ssid);

  /// No description provided for @wifiLinkSpeed.
  ///
  /// In en, this message translates to:
  /// **'Link Speed'**
  String get wifiLinkSpeed;

  /// No description provided for @wifiListStandardFormat.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi {band}'**
  String wifiListStandardFormat(String band);

  /// No description provided for @wifiMacAddress.
  ///
  /// In en, this message translates to:
  /// **'MAC Address'**
  String get wifiMacAddress;

  /// No description provided for @wifiNetworkText.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi'**
  String get wifiNetworkText;

  /// No description provided for @wifiNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get wifiNotAvailable;

  /// No description provided for @wifiOpenSystemSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'This network is managed by system Wi‑Fi. Open system settings to forget it completely.'**
  String get wifiOpenSystemSettingsHint;

  /// No description provided for @wifiRouter.
  ///
  /// In en, this message translates to:
  /// **'Router'**
  String get wifiRouter;

  /// No description provided for @wifiSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get wifiSecurity;

  /// No description provided for @wifiSecurityOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get wifiSecurityOpen;

  /// No description provided for @wifiSecurityWpa2.
  ///
  /// In en, this message translates to:
  /// **'WPA2'**
  String get wifiSecurityWpa2;

  /// No description provided for @wifiSecurityWpa3.
  ///
  /// In en, this message translates to:
  /// **'WPA3'**
  String get wifiSecurityWpa3;

  /// No description provided for @wifiSignalStrength.
  ///
  /// In en, this message translates to:
  /// **'Signal Strength'**
  String get wifiSignalStrength;

  /// No description provided for @wifiStaticIpConflict.
  ///
  /// In en, this message translates to:
  /// **'IP address conflicts with another interface'**
  String get wifiStaticIpConflict;

  /// No description provided for @wifiStaticIpGatewaySubnet.
  ///
  /// In en, this message translates to:
  /// **'Gateway must be on the same subnet'**
  String get wifiStaticIpGatewaySubnet;

  /// No description provided for @wifiStaticIpIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required static IP fields'**
  String get wifiStaticIpIncomplete;

  /// No description provided for @wifiStaticIpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid static IP configuration'**
  String get wifiStaticIpInvalid;

  /// No description provided for @wifiStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get wifiStatusConnected;

  /// No description provided for @wifiStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get wifiStatusConnecting;

  /// No description provided for @wifiStatusNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get wifiStatusNotConnected;

  /// No description provided for @wifiSubnetMask.
  ///
  /// In en, this message translates to:
  /// **'Subnet Mask'**
  String get wifiSubnetMask;

  /// No description provided for @wifiToastAddCanceledBySystem.
  ///
  /// In en, this message translates to:
  /// **'Adding Wi‑Fi was canceled by the system'**
  String get wifiToastAddCanceledBySystem;

  /// No description provided for @wifiToastAddedConnecting.
  ///
  /// In en, this message translates to:
  /// **'Network added. Connecting…'**
  String get wifiToastAddedConnecting;

  /// No description provided for @wifiToastConnectedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get wifiToastConnectedSuccess;

  /// No description provided for @wifiToastConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get wifiToastConnectionFailed;

  /// No description provided for @wifiToastDetailsOnlyWhenConnected.
  ///
  /// In en, this message translates to:
  /// **'Details are only available for the connected network'**
  String get wifiToastDetailsOnlyWhenConnected;

  /// No description provided for @wifiToastInvalidBssid.
  ///
  /// In en, this message translates to:
  /// **'Invalid BSSID format'**
  String get wifiToastInvalidBssid;

  /// No description provided for @wifiToastNoConnectionDetails.
  ///
  /// In en, this message translates to:
  /// **'No connected Wi‑Fi details'**
  String get wifiToastNoConnectionDetails;

  /// No description provided for @wifiToastPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get wifiToastPasswordRequired;

  /// No description provided for @wifiToastProfileExistsConnecting.
  ///
  /// In en, this message translates to:
  /// **'This network is already saved. Connecting…'**
  String get wifiToastProfileExistsConnecting;

  /// No description provided for @wifiToastProfileSavedUseSystem.
  ///
  /// In en, this message translates to:
  /// **'Profile saved. Connect from the system Wi‑Fi list.'**
  String get wifiToastProfileSavedUseSystem;

  /// No description provided for @wifiToastRequiresSystemPrivilege.
  ///
  /// In en, this message translates to:
  /// **'System Wi‑Fi permission required. Install this app as a privileged system app.'**
  String get wifiToastRequiresSystemPrivilege;

  /// No description provided for @wifiToastSsidRequired.
  ///
  /// In en, this message translates to:
  /// **'Network name is required'**
  String get wifiToastSsidRequired;

  /// No description provided for @wifiToastWifiDisabled.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi is off'**
  String get wifiToastWifiDisabled;

  /// No description provided for @wifiWlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi'**
  String get wifiWlanLabel;

  /// No description provided for @watchdogResetEventContent.
  ///
  /// In en, this message translates to:
  /// **'The controller restarted after a watchdog reset. If this happens often, contact LaserCyber support.'**
  String get watchdogResetEventContent;

  /// No description provided for @watchdogResetEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Watchdog Reset'**
  String get watchdogResetEventTitle;

  /// No description provided for @wireFeederCommunicationAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get wireFeederCommunicationAlarmContent;

  /// No description provided for @wireFeederCommunicationAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Wire Feeder Communication Alarm'**
  String get wireFeederCommunicationAlarmTitle;

  /// No description provided for @wireFeederCurrentAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.'**
  String get wireFeederCurrentAlarmContent;

  /// No description provided for @wireFeederCurrentAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Wire Feeder Current Alarm'**
  String get wireFeederCurrentAlarmTitle;

  /// No description provided for @wireFeedingLabel.
  ///
  /// In en, this message translates to:
  /// **'Wire Feeding'**
  String get wireFeedingLabel;

  /// No description provided for @wireFeedingMachineCommunicationText.
  ///
  /// In en, this message translates to:
  /// **'Feeder Comm'**
  String get wireFeedingMachineCommunicationText;

  /// No description provided for @wireFeedingText.
  ///
  /// In en, this message translates to:
  /// **'Wire Feeder'**
  String get wireFeedingText;

  /// No description provided for @wireFeederVersion.
  ///
  /// In en, this message translates to:
  /// **'Wire Feeder Version'**
  String get wireFeederVersion;

  /// No description provided for @wirelessNetworkText.
  ///
  /// In en, this message translates to:
  /// **'Wireless Network'**
  String get wirelessNetworkText;

  /// No description provided for @workInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Work Info'**
  String get workInfoTitle;

  /// No description provided for @workTitle.
  ///
  /// In en, this message translates to:
  /// **'Work Info'**
  String get workTitle;

  /// No description provided for @zeroPointOffsetAlarmContent.
  ///
  /// In en, this message translates to:
  /// **'Zero offset is off center. Open Advanced Settings and correct it before continuing precise work.'**
  String get zeroPointOffsetAlarmContent;

  /// No description provided for @zeroPointOffsetAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Zero Offset Alarm'**
  String get zeroPointOffsetAlarmTitle;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en': {
  switch (locale.countryCode) {
    case 'US': return AppLocalizationsEnUs();
   }
  break;
   }
    case 'zh': {
  switch (locale.countryCode) {
    case 'CN': return AppLocalizationsZhCn();
case 'TW': return AppLocalizationsZhTw();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
