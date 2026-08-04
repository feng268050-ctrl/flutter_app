// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get activeAlarmsTitle => 'Active Alarms';

  @override
  String get adFeedbackCommunicationAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get adFeedbackCommunicationAlarmTitle =>
      'AD Feedback Communication Alarm';

  @override
  String adbRemoteDebugEnabled(int port) {
    return 'ADB remote debugging enabled (port $port). Use adb connect to attach.';
  }

  @override
  String get adbRemoteDebugFailed => 'Failed to enable ADB remote debugging';

  @override
  String get advancedSettingAllowWorkAfterCameraAlarm =>
      'Allow Work After Camera Alarm';

  @override
  String get advancedSettingAllowWorkAfterCameraAlarmHint =>
      'If camera communication fails, AI auto-detection will be unavailable.';

  @override
  String get advancedSettingAllowWorkAfterFeederAlarm =>
      'Allow Work After Feeder Alarm';

  @override
  String get advancedSettingAllowWorkAfterFeederAlarmHint =>
      'Continuous welding won’t work properly if the wire feeder is abnormal, but other modes can continue.';

  @override
  String get advancedSettingAllowWorkAfterGasAlarm =>
      'Allow Work After Gas Alarm';

  @override
  String get advancedSettingAllowWorkAfterGasAlarmHint =>
      'Allowing laser output with abnormal shielding gas may damage the device. Enable only when you’re sure it’s safe.';

  @override
  String get advancedSettingAllowWorkAfterLensContamination =>
      'Allow Work After Lens Contamination';

  @override
  String get advancedSettingAllowWorkAfterLensContaminationHint =>
      'Allowing laser output with a contaminated protective lens may damage the device. Enable only if AI detection is inaccurate.';

  @override
  String get advancedSettingKeepLaserOnWhileAlarmed =>
      'Keep Laser On During Alarms';

  @override
  String get advancedSettingKeepLaserOnWhileAlarmedHint =>
      'When enabled, coded alarms won’t automatically turn off the laser while you’re already welding. Warning dialogs still appear. Use only when the risk is acceptable.';

  @override
  String get advancedSettingLensContaminationDetection =>
      'Lens Contamination Detection';

  @override
  String get advancedSettingLensContaminationDetectionHint =>
      'Uses the camera and AI to watch the protective lens during work and warn when contamination is detected. Turn off only if detection is inaccurate or unavailable.';

  @override
  String get advancedSettingZeroOffset => 'Zero Offset';

  @override
  String get advancedSettingZeroOffsetAuto => 'Auto';

  @override
  String get advancedSettingAutoZeroOffsetTitle => 'Auto Zero Offset';

  @override
  String get advancedSettingAutoZeroOffsetMessage =>
      'Aim the welding gun at a safe area and hold the trigger, then tap Auto. Auto temporarily enables laser output; the trigger fires the laser. Wait for the progress bar to finish automatic zero-offset correction.';

  @override
  String get advancedSettingEnterZeroOffset => 'Enter zero offset';

  @override
  String get advancedSettingScanWidthCorrection => 'Scan Width Correction';

  @override
  String get advancedSettingEnterScanWidthCorrection =>
      'Enter scan width correction';

  @override
  String get advancedSettingLaserStartPower => 'Laser Start Power';

  @override
  String get advancedSettingEnterLaserStartPower => 'Enter laser start power';

  @override
  String get advancedSettingLaserEndPower => 'Laser End Power';

  @override
  String get advancedSettingEnterLaserEndPower => 'Enter laser end power';

  @override
  String get advancedSettingMinGasPressure => 'Min. Gas Pressure';

  @override
  String get advancedSettingEnterMinGasPressure =>
      'Enter minimum gas pressure threshold';

  @override
  String get advancedSettingInletGasPressure => 'Inlet Gas Pressure Threshold';

  @override
  String get advancedSettingEnterInletGasPressure =>
      'Enter inlet gas pressure threshold';

  @override
  String get advancedSettingMotorTempAlarmThreshold =>
      'Motor Temperature Alarm Threshold';

  @override
  String get advancedSettingEnterMotorTempAlarmThreshold =>
      'Enter motor temperature alarm threshold';

  @override
  String get advancedSettingDriverTempAlarmThreshold =>
      'Driver Temperature Alarm Threshold';

  @override
  String get advancedSettingEnterDriverTempAlarmThreshold =>
      'Enter driver temperature alarm threshold';

  @override
  String get advancedSettingProtectiveLensTempAlarmThreshold =>
      'Protective Lens Temperature Alarm Threshold';

  @override
  String get advancedSettingEnterProtectiveLensTempAlarmThreshold =>
      'Enter protective lens temperature alarm threshold';

  @override
  String get advancedSettingCollimatingLensTempAlarmThreshold =>
      'Collimating Lens Temperature Alarm Threshold';

  @override
  String get advancedSettingEnterCollimatingLensTempAlarmThreshold =>
      'Enter collimating lens temperature alarm threshold';

  @override
  String get advancedSettingTempAlarmRecoveryHysteresis =>
      'Temperature Alarm Recovery Hysteresis';

  @override
  String get advancedSettingEnterTempAlarmRecoveryHysteresis =>
      'Enter temperature alarm recovery hysteresis';

  @override
  String get advancedSettingValueRequired => 'Value is required';

  @override
  String get advancedSettingScale0Celsius => '0℃';

  @override
  String get advancedSettingScale20Celsius => '20℃';

  @override
  String get advancedSettingScale80Celsius => '80℃';

  @override
  String get advancedSettingScale85Celsius => '85℃';

  @override
  String get advancedSettingShowBootSelfCheck => 'Show Startup Self-Check';

  @override
  String get advancedSettingText => 'Advanced';

  @override
  String get advancedSettingZeroPointOffsetDetection => 'Zero Offset Detection';

  @override
  String get advancedSettingZeroPointOffsetDetectionHint =>
      'Uses AI to check whether the laser spot is centered. You’ll be prompted to correct zero offset when it drifts. Turn off only if you don’t need this alert.';

  @override
  String get advancedSettings => 'Advanced';

  @override
  String get advancedSettingsGroupAiAssistance => 'AI Assistance';

  @override
  String get advancedSettingsGroupDangerousOperations => 'Override Safeguards';

  @override
  String get advancedSettingsGroupOffsetCorrection => 'Offset & Correction';

  @override
  String get advancedSettingsGroupPowerThresholds => 'Power Thresholds';

  @override
  String get advancedSettingsGroupTemperatureThresholds =>
      'Temperature Thresholds';

  @override
  String get aiDetectionLabel => 'Detection';

  @override
  String get aiOverlayClsDisabled => 'Class: disabled';

  @override
  String get aiOverlayClsMetal => 'Metal';

  @override
  String get aiOverlayClsOther => 'Other';

  @override
  String aiOverlayClsPrefix(String className, double score) {
    return 'Class: $className ($score)';
  }

  @override
  String get aiOverlayClsWaiting => 'Class: waiting…';

  @override
  String aiOverlayHudStatePrefix(String state) {
    return 'STATE: $state';
  }

  @override
  String get aiOverlayHudStatusIdle => 'IDLE';

  @override
  String aiOverlayHudStatusPrefix(String status) {
    return 'AI: $status';
  }

  @override
  String aiOverlayResultPrefix(String result) {
    return 'Latest result: $result';
  }

  @override
  String get aiOverlayResultWaiting => 'Latest result: waiting…';

  @override
  String get aiOverlayStateIdle => 'Idle';

  @override
  String get aiOverlayStateLocked => 'Locked';

  @override
  String get aiOverlayStateMonitoring => 'Monitoring';

  @override
  String get aiOverlayStateStainDetect => 'Contamination detection';

  @override
  String get aiVisionAiEngineNotReady => 'AI engine isn’t ready';

  @override
  String get aiVisionChooseBtn => 'Select Video';

  @override
  String get aiVisionComingSoon => 'AI Vision — coming soon';

  @override
  String get aiVisionDetectBtn => 'Detect';

  @override
  String get aiVisionInferenceVideoNotReady => 'Result video isn’t ready yet';

  @override
  String get aiVisionMaterialTypeText => 'Material Type';

  @override
  String get aiVisionNavLabel => 'AI Vision';

  @override
  String get aiVisionOfflineInferenceNotAvailable =>
      'Offline analysis isn’t available in the current AI library';

  @override
  String get aiVisionProcessTypeText => 'Process Type';

  @override
  String get aiVisionReinferBtn => 'Re-detect';

  @override
  String get aiVisionReplaceBtn => 'Replace';

  @override
  String get aiVisionSelectBtn => 'Select';

  @override
  String get aiVisionSelectVideoFirst => 'Select a video to analyze';

  @override
  String aiVisionStreamFailureFirstFrameTimeout(int timeoutMs) {
    return 'Timed out waiting for first frame ($timeoutMs ms)';
  }

  @override
  String get aiVisionStreamFailurePlayerTimeout =>
      'Player connection or stream timed out';

  @override
  String aiVisionStreamFailureRtspEvent(String message) {
    return 'RTSP error: $message';
  }

  @override
  String aiVisionStreamFailureStartCode(int code) {
    return 'Player start failed (code $code)';
  }

  @override
  String get aiVisionStreamFailureSurfaceUnavailable =>
      'Video surface isn’t ready';

  @override
  String get aiVisionStreamFailureUnknown => 'Unknown reason';

  @override
  String get aiVisionStreamFailureUnsupportedVideo =>
      'Unsupported video codec or decoder failed to start';

  @override
  String get aiVisionTitle => 'AI Vision';

  @override
  String get aiVisionUploadBtn => 'Upload';

  @override
  String get aiVisionVideoAnalyzing => 'Analyzing…';

  @override
  String aiVisionVideoExportFailed(String error) {
    return 'Failed to export result video: $error';
  }

  @override
  String get aiVisionVideoExporting => 'Generating result video…';

  @override
  String aiVisionVideoInferenceFailed(String error) {
    return 'Video analysis failed: $error';
  }

  @override
  String aiVisionVideoInferenceProgress(int percent) {
    return 'Analyzing video… $percent%';
  }

  @override
  String get aiVisionVideoInferring => 'Analyzing…';

  @override
  String get aiVisionVideoPause => 'Pause';

  @override
  String get aiVisionVideoPlay => 'Play';

  @override
  String get aiVisionVideoReplay => 'Replay';

  @override
  String get aiVisionWorkInfoUnavailable => '-';

  @override
  String get liveVideoFailed => 'Live video unavailable';

  @override
  String get aiVisualizedLabel => 'Visualized';

  @override
  String get alarmFaultClearedContent =>
      'This fault has cleared. You can resume work. If it happens often, contact LaserCyber support.';

  @override
  String get alarmInfoLaserDevice => 'Laser';

  @override
  String get alarmInfoWeldingGun => 'Welding Gun';

  @override
  String get alarmInfoWireFeeder => 'Wire Feeder';

  @override
  String get alarmLogsTitle => 'Alarm Logs';

  @override
  String get alarmRebootThenSupportContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get alarmTitle => 'Alarms';

  @override
  String autoOtaUpdateDialogMessage(String version) {
    return 'Version $version is available. Download and install it in Settings.';
  }

  @override
  String get autoOtaUpdateDialogTitle => 'Update Available';

  @override
  String get blowOnLabel => 'Blow';

  @override
  String get blowText => 'Gas Flow';

  @override
  String get blowingAirPressureText => 'Shielding Gas Pressure';

  @override
  String get bluetoothCloseFailedText => 'Couldn’t turn off Bluetooth';

  @override
  String get bluetoothClosedText => 'Bluetooth off';

  @override
  String get bluetoothNotSupportedText => 'Bluetooth not supported';

  @override
  String get bluetoothOpenFailedText => 'Couldn’t turn on Bluetooth';

  @override
  String get bluetoothOpenedText => 'Bluetooth on';

  @override
  String get bluetoothSettings => 'Bluetooth';

  @override
  String get bluetoothText => 'Bluetooth';

  @override
  String get bluetoothAsSpeaker => 'As a Speaker';

  @override
  String get bootSelfCheckClose => 'Close';

  @override
  String get bootSelfCheckControllerComm => 'Controller Comm';

  @override
  String get bootSelfCheckDialogTitle => 'Startup Self-Check';

  @override
  String get bootSelfCheckDontShowAgain => 'Don’t show again';

  @override
  String get bootSelfCheckStatusChecking => 'Checking…';

  @override
  String get bootSelfCheckStatusFail => 'Fault';

  @override
  String get bootSelfCheckStatusPass => 'OK';

  @override
  String get bootSelfCheckStatusSkipped => 'Skipped';

  @override
  String bundledFirmwareDialogMessage(
      String currentVersion, String newVersion) {
    return 'A newer control board firmware is available ($currentVersion → $newVersion).\nKeep power connected and don’t operate the device during the upgrade.';
  }

  @override
  String get bundledFirmwareDialogTitle => 'Control Board Firmware Update';

  @override
  String get bundledFirmwareFailedMessage =>
      'Control board firmware update failed. Try again later.';

  @override
  String get bundledFirmwareFailedTitle => 'Firmware Update Failed';

  @override
  String bundledFirmwareProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get bundledFirmwareSuccessMessage =>
      'Control board firmware has been updated.';

  @override
  String get bundledFirmwareSuccessTitle => 'Firmware Updated';

  @override
  String get bundledFirmwareUpgradingMessage =>
      'Keep power connected and don’t operate the device during the upgrade.';

  @override
  String get bundledFirmwareUpgradingTitle => 'Updating Control Board Firmware';

  @override
  String get callBackHomeTitle => 'Home';

  @override
  String get cameraCommStatusText => 'Camera Comm';

  @override
  String get cameraCommunicationAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get cameraCommunicationAlarmTitle => 'Camera Communication Alarm';

  @override
  String get cancelText => 'Cancel';

  @override
  String get cellularNetworkText => 'Cellular';

  @override
  String get celsiusUnit => '°C';

  @override
  String get checkUpdate => 'Check for Updates';

  @override
  String get checkingStatus => 'Checking…';

  @override
  String get clearAlarmLogs => 'Clear';

  @override
  String get alarmLogsClearedTitle => 'Cleared';

  @override
  String get alarmLogsClearedMessage => 'Done';

  @override
  String get closeText => 'Close';

  @override
  String get coldWaterInterlockAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get coldWaterInterlockAlarmTitle => 'Coolant Interlock Alarm';

  @override
  String get collimatingLensOvertemperatureAlarmTitle =>
      'Collimating Lens Overtemperature';

  @override
  String get collimatorTempLabel => 'Collimator';

  @override
  String get collimatorTemperatureText => 'Collimating Lens Temperature';

  @override
  String get commonSettings => 'General';

  @override
  String get commonSettingsGroupDateTime => 'Date & Time';

  @override
  String get commonSettingsGroupDisplaySound => 'Display & Sound';

  @override
  String get commonSettingsGroupMisc => 'Other';

  @override
  String get commonSettingsGroupNetwork => 'Network';

  @override
  String get commonSettingsShowSafetyGroundLockAlarm =>
      'Show Safety Clamp Alarm';

  @override
  String get confirmText => 'Confirm';

  @override
  String get connectedText => 'Connected';

  @override
  String get controllerTabletCommAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get controllerTabletCommAlarmTitle =>
      'Control Board Communication Error';

  @override
  String get currentAlarmText => 'Current Alarm';

  @override
  String get customHomePage => 'Custom Home';

  @override
  String get customHomeSelectFourCards => 'Please select 4 cards';

  @override
  String get customHomeReplacementSelected => 'Selected';

  @override
  String get customHomeSelectReplaceCard => 'Please select a card to replace';

  @override
  String get cuttingProportionText => 'Cutting Ratio';

  @override
  String get dateTimeApplyFailed => 'Couldn’t update date/time';

  @override
  String get dateTimeAutoDateTime => 'Automatic Date & Time';

  @override
  String get dateTimeAutoSyncFailed => 'Network time unavailable';

  @override
  String get dateTimeAutoSyncOff => 'Automatic sync is off';

  @override
  String get dateTimeAutoSyncOffline => 'No network — waiting to sync';

  @override
  String get dateTimeAutoSyncOk => 'Network time synchronized';

  @override
  String get dateTimeAutoSyncing => 'Syncing with network time…';

  @override
  String get dateTimeAutoTimeZone => 'Automatic Time Zone';

  @override
  String get dateTimeAutomatic => 'Automatic';

  @override
  String get dateTimeNtpServer => 'Time Server';

  @override
  String get dateTimeNtpPool => 'NTP Pool';

  @override
  String get dateTimeNtpCloudflare => 'Cloudflare';

  @override
  String get dateTimeNtpGoogle => 'Google';

  @override
  String get dateTimeNtpAliyun => 'Aliyun';

  @override
  String get dateTimeNtpWindows => 'Windows';

  @override
  String get dateTimeNtpApple => 'Apple';

  @override
  String get dateTimeNtpTencent => 'Tencent';

  @override
  String get dateTimeNtpCnPool => 'China NTP Pool';

  @override
  String get dateTimeTimezoneGeoFailed =>
      'Couldn’t set time zone from network location';

  @override
  String get dateTimeModeAuto => 'Auto';

  @override
  String get dateTimeModeManual => 'Manual';

  @override
  String get dateTimePermissionDenied =>
      'Missing system permission to change date/time';

  @override
  String get dateTimeSearchTimezoneHint =>
      'Search time zone (e.g. Asia/Shanghai)';

  @override
  String get dateTimeSelectDate => 'Select Date';

  @override
  String get dateTimeSelectTime => 'Select Time';

  @override
  String get dateTimeSelectTimeZone => 'Select Time Zone';

  @override
  String get dateTimeSetDate => 'Date';

  @override
  String get dateTimeSetFailed => 'Couldn’t update date or time';

  @override
  String get dateTimeSetTime => 'Time';

  @override
  String get dateTimeUse24HourFormat => 'Use 24-Hour Format';

  @override
  String get dateTimeSetTimeZone => 'Time Zone';

  @override
  String get dateTimeSettings => 'Date & Time';

  @override
  String get timezoneSearchHint => 'Search by name or UTC offset';

  @override
  String get dateTimeTimezoneApplyFailed => 'Couldn’t update time zone';

  @override
  String get defaultLabel => 'Default';

  @override
  String get deleteText => 'Delete';

  @override
  String get deviceInformation => 'Device Info';

  @override
  String get deviceInformationText => 'Device Info';

  @override
  String get deviceModel => 'Model';

  @override
  String get deviceMonitorHomeTitle => 'Monitor';

  @override
  String get deviceMonitorMachineStatusTitle => 'Machine Status';

  @override
  String get deviceMonitorTitle => 'Device Monitor';

  @override
  String get deviceMonitorWarnInfoTitle => 'Alarms';

  @override
  String get deviceMonitorWorkInfoTitle => 'Work Info';

  @override
  String get deviceSettingText => 'Device Settings';

  @override
  String get deviceSn => 'Device SN';

  @override
  String get diodeShortCircuitAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get diodeShortCircuitAlarmTitle => 'Diode Short Circuit';

  @override
  String get diodeShortCircuitErrorClearedTitle =>
      'Diode Short Circuit Cleared';

  @override
  String get dontShowAgain => 'Don’t show again';

  @override
  String get driveOvertemperatureAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get driveOvertemperatureAlarmTitle => 'Driver Overtemperature';

  @override
  String get driverBoardOvervoltageTitle => 'Driver Board Overvoltage';

  @override
  String get driverModuleOvertemperatureAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get driverModuleOvertemperatureAlarmTitle =>
      'Driver Module Overtemperature';

  @override
  String get emptyText => '';

  @override
  String get environmentTemperatureAlarmContent =>
      'Ambient temperature is out of the allowed range. Improve workshop cooling/heating. If the reading looks wrong, contact LaserCyber support.';

  @override
  String get environmentTemperatureAlarmTitle => 'Ambient Temperature Alarm';

  @override
  String get environmentTemperatureText => 'Ambient Temperature';

  @override
  String get equipmentStatusBack => 'Back';

  @override
  String get equipmentStatusHome => 'Home';

  @override
  String get fahrenheitUnit => '°F';

  @override
  String get failStatus => 'Fault';

  @override
  String get fiberDisconnectionAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get fiberDisconnectionAlarmTitle => 'Fiber Disconnected';

  @override
  String get fiberTemperatureUpperLimitAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get fiberTemperatureUpperLimitAlarmTitle => 'Fiber Temperature High';

  @override
  String get fiberTemperatureUpperLimitClearedTitle =>
      'Fiber Temperature High Cleared';

  @override
  String get firmwareVersion => 'Control Board Version';

  @override
  String get flashErrorAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get flashErrorAlarmTitle => 'FLASH Error';

  @override
  String get flashUnencryptedAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get flashUnencryptedAlarmTitle => 'FLASH Unencrypted';

  @override
  String get frontLightPdVoltageText => 'Forward PD Voltage';

  @override
  String get galvanometerMotorOvercurrentAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get galvanometerMotorOvercurrentAlarmTitle =>
      'Galvo Motor Overcurrent';

  @override
  String get galvanometerMotorStallAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get galvanometerMotorStallAlarmTitle => 'Galvo Motor Stall';

  @override
  String get galvanometerMotorTrajectoryErrorTitle =>
      'Galvo Motor Trajectory Error';

  @override
  String get gasPressureLabel => 'Gas Pressure';

  @override
  String get gunHeadCommunicationAlarmContent =>
      'Communication between the host and the welding gun failed. Check the gun cable and connectors. If the alarm continues after reconnecting, contact LaserCyber support.';

  @override
  String get gunHeadCommunicationAlarmTitle =>
      'Welding Gun Communication Alarm';

  @override
  String get gunHeadCommunicationText => 'Gun Comm';

  @override
  String get gunHeadMotorOvertemperatureAlarmContent =>
      'The welding gun motor is overheating. Pause work and let it cool. If the alarm returns, contact LaserCyber support.';

  @override
  String get gunHeadMotorOvertemperatureAlarmTitle =>
      'Welding Gun Motor Overtemperature';

  @override
  String get gunHeadSwitchText => 'Gun Switch';

  @override
  String get gunSn => 'Welding Gun SN';

  @override
  String get gunSwitchLabel => 'Gun Switch';

  @override
  String get hardwareBusErrorAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get hardwareBusErrorAlarmTitle => 'Hardware Bus Error';

  @override
  String get homeAiVisionLabel => 'AI Vision';

  @override
  String get homeEngineerModeLabel => 'Engineer Mode';

  @override
  String get homeMonitorLabel => 'Monitor';

  @override
  String get homeQuickModeLabel => 'Quick Mode';

  @override
  String get homeSettingsLabel => 'Settings';

  @override
  String get httpProxyAuthBasic => 'Basic';

  @override
  String get httpProxyAuthNone => 'None';

  @override
  String get httpProxyAuthType => 'Authentication';

  @override
  String get httpProxyEnable => 'Enable Proxy';

  @override
  String get httpProxyHost => 'Host';

  @override
  String get httpProxyHostHint => 'proxy.example.com';

  @override
  String get httpProxyPassword => 'Password';

  @override
  String get httpProxyPort => 'Port';

  @override
  String get httpProxyPortHint => '8080';

  @override
  String get httpProxySave => 'Save';

  @override
  String get httpProxySaveSuccess => 'Proxy settings saved';

  @override
  String get httpProxySettingsTitle => 'Proxy';

  @override
  String get httpProxyStatusIncomplete => 'On (incomplete)';

  @override
  String get httpProxyStatusOff => 'Off';

  @override
  String get httpProxyTestConnection => 'Test Connection';

  @override
  String get httpProxyTestFailed => 'Connection failed';

  @override
  String get httpProxyTestNoOrigin => 'No API origin available to test';

  @override
  String get httpProxyTestSuccess => 'Connection successful';

  @override
  String get httpProxyTitle => 'Proxy';

  @override
  String get httpProxyUsername => 'Username';

  @override
  String get httpProxyValidationHostRequired => 'Enter a host address';

  @override
  String get httpProxyValidationPortInvalid => 'Port must be 1–65535';

  @override
  String get httpProxyValidationUsernameRequired =>
      'Username is required for Basic auth';

  @override
  String get illegalInstructionAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get illegalInstructionAlarmTitle => 'Illegal Instruction';

  @override
  String get inUnit => 'in';

  @override
  String inputDialogTitleWithUnit(String title, String unit) {
    return '$title ($unit)';
  }

  @override
  String get internalHumidityExceedsTheUpperLimitAlarmTitle =>
      'Internal Humidity High';

  @override
  String get internalHumidityUpperLimitAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get ipCameraText => 'Camera';

  @override
  String get cameraType => 'Camera Type';

  @override
  String get cameraVersion => 'Camera Version';

  @override
  String get cameraTypeBlueLight => 'Blue Light';

  @override
  String get cameraTypeRedLight => 'Red Light';

  @override
  String get cameraStatus => 'Status';

  @override
  String get cameraStatusEstablishing => 'Establishing…';

  @override
  String get cameraStatusFailed => 'Failed';

  @override
  String get cameraChangeOverlay => 'Change Overlay';

  @override
  String get cameraOverlayEnable => 'Enable Overlay';

  @override
  String get cameraOverlayPositionX => 'Position X';

  @override
  String get cameraOverlayPositionY => 'Position Y';

  @override
  String get cameraOverlayApplyFailed => 'Couldn’t apply overlay';

  @override
  String get systemVersion => 'System Version';

  @override
  String get processLibVersion => 'Process Library Version';

  @override
  String get focusScaleReference => 'Focus Scale Reference';

  @override
  String get kernelVersion => 'Kernel Version';

  @override
  String get autoCheckOtaUpdate => 'Automatically check for updates';

  @override
  String get otaCheckUnavailable =>
      'Software update check is not available on this build.';

  @override
  String get cloudEnvironmentTier => 'Cloud Environment';

  @override
  String get cloudEnvironmentTierDev => 'Dev';

  @override
  String get cloudEnvironmentTierTest => 'Test';

  @override
  String get cloudEnvironmentTierProd => 'Prod';

  @override
  String get deviceRegisterTitle => 'Register This Device';

  @override
  String get deviceRegisterBody =>
      'This device is unrecognized, please scan the QR code with LaserCyber app to register it.';

  @override
  String get deviceRegisterReconnect => 'Reconnect';

  @override
  String get deviceBindTitle => 'Bind This Device';

  @override
  String get deviceBindBody =>
      'Scan the QR code with the LaserCyber app to bind this device.';

  @override
  String get wifiConnectTipTitle => 'Connect to Wi‑Fi';

  @override
  String get wifiConnectTipBody =>
      'This device is not connected to Wi‑Fi. Connect a network to use cloud features.';

  @override
  String get wifiConnectTipOpenSettings => 'Wi‑Fi Settings';

  @override
  String get deviceRemoteLockTitle => 'Device Locked';

  @override
  String get deviceRemoteLockBody =>
      'This device has been locked remotely. Contact your administrator to unlock.';

  @override
  String get screenOffNever => 'Never';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get keyboardText => 'Keyboard';

  @override
  String get languageAppliesToUi =>
      'Applies to the product UI language and soft keyboard.';

  @override
  String get languageOptionChinese => '简体中文';

  @override
  String get languageOptionEnglish => 'English';

  @override
  String get languageOptionTraditionalChinese => '繁體中文';

  @override
  String get languagePreferenceUnavailable =>
      'Language preference unavailable.';

  @override
  String get languageSettingText => 'Language';

  @override
  String get laserCommunicationAlarmContent =>
      'Confirm that the Reset button has been pressed. If it still doesn’t recover, power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get laserCommunicationAlarmTitle => 'Laser Communication Alarm';

  @override
  String get laserCurrentAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get laserCurrentAlarmTitle => 'Laser Current Alarm';

  @override
  String get laserCurrentLabel => 'Laser Current';

  @override
  String get laserDriverCommunicationAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get laserDriverCommunicationAlarmTitle =>
      'Laser Driver Communication Alarm';

  @override
  String get laserEmergencyStopAlarmContent =>
      'Laser E-stop is active. Release the emergency stop and reset the machine before continuing.';

  @override
  String get laserEmergencyStopAlarmTitle => 'Laser E-Stop Alarm';

  @override
  String get laserOnLabel => 'Laser';

  @override
  String get laserOutputEnergyLowerLimitAlarmContent =>
      'Laser output energy is below the limit. Check the protective lens and process power setting. If it continues, contact LaserCyber support.';

  @override
  String get laserOutputEnergyLowerLimitAlarmTitle => 'Laser Output Energy Low';

  @override
  String get laserOutputEnergyLowerLimitClearedTitle =>
      'Output Energy Low Cleared';

  @override
  String get laserReflectedEnergyUpperLimitAlarmContent =>
      'Reflected laser energy is too high. Stop emission and check workpiece angle, joint fit-up, and process parameters. If it continues, contact LaserCyber support.';

  @override
  String get laserReflectedEnergyUpperLimitAlarmTitle =>
      'Reflected Laser Energy High';

  @override
  String get laserReflectedEnergyUpperLimitClearedTitle =>
      'Reflected Energy High Cleared';

  @override
  String get laserText => 'Laser';

  @override
  String get laserVersion => 'Laser Version';

  @override
  String get lensHeavyContaminationAlarmContent =>
      'Protective lens is heavily contaminated. Clean or replace it.';

  @override
  String get lensHeavyContaminationAlarmTitle => 'Lens Contamination Alarm';

  @override
  String get loadingText => 'Loading…';

  @override
  String get machineBlowContent => 'Pressure';

  @override
  String get machineBlowTitle => 'Gas';

  @override
  String get machineLaserCurrentContent => 'Current';

  @override
  String get machineLaserCurrentTitle => 'Laser';

  @override
  String get machinePumpContent => 'Current';

  @override
  String get machinePumpTitle => 'Pump';

  @override
  String get machineTitle => 'Machine Status';

  @override
  String get mainControllerTempBoardCommAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get mainControllerTempBoardCommAlarmTitle =>
      'Main Controller–Temperature Board Communication Fault';

  @override
  String get memoryAccessErrorTitle => 'Memory Access Error';

  @override
  String get memoryManagementErrorTitle => 'Memory Management Error';

  @override
  String get mmUnit => 'mm';

  @override
  String get mmiOscillatorMalfunctionAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get mmiOscillatorMalfunctionAlarmTitle => 'MMI Oscillator Fault';

  @override
  String get modbusCommunicationFault => 'Modbus communication fault';

  @override
  String get monitorNavLabel => 'Monitor';

  @override
  String get motorCableOpenAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get motorCableOpenAlarmTitle => 'Motor Cable Open';

  @override
  String get motorDriverTempLabel => 'Motor Driver';

  @override
  String get motorDriverTemperatureText => 'Motor Driver Temperature';

  @override
  String get motorTempLabel => 'Motor';

  @override
  String get mouseText => 'Mouse';

  @override
  String get narrowPulseProtectionAlarmContent =>
      'Narrow-pulse protection was triggered. Adjust process parameters and try again. If it keeps happening, contact LaserCyber support.';

  @override
  String get narrowPulseProtectionAlarmTitle => 'Narrow Pulse Protection';

  @override
  String get networkSettingText => 'Network';

  @override
  String get networkSettings => 'Network';

  @override
  String get noActiveAlarms => 'No active alarms';

  @override
  String get noSignedProcessLibrary => 'No signed process library installed';

  @override
  String get notConnected => 'Not Connected';

  @override
  String get notConnectingText => 'Not connected';

  @override
  String get notPersistedYet => 'Not persisted yet';

  @override
  String get offLabel => 'Off';

  @override
  String get okText => 'OK';

  @override
  String get onLabel => 'On';

  @override
  String get otaUpgradeStatusApk => 'Installing app…';

  @override
  String get otaUpgradeStatusDownloading => 'Downloading update…';

  @override
  String otaUpgradeStatusFirmware(int percent) {
    return 'Updating control board firmware ($percent%)';
  }

  @override
  String get otaUpgradeStatusPreparing => 'Preparing upgrade…';

  @override
  String get otaUpgradeStatusSystem => 'Updating system…';

  @override
  String get overTempLabel => 'OVER TEMP';

  @override
  String get passStatus => 'OK';

  @override
  String get pleaseWait => 'Please wait…';

  @override
  String get productDisclaimerContent =>
      'Dear User: Thank you for choosing our handheld laser welding product. Before using this product, we strongly recommend that you read this disclaimer carefully and strictly adhere to all instructions and safety measures provided in the user manual.\n\n1. Safety Warning\nLaser equipment can cause severe damage to the eyes and skin. During operation, please always wear appropriate Personal Protective Equipment (PPE), including but not limited to laser safety goggles and gloves, to ensure your safety.\n\n2. Operating Instructions\nPlease ensure that you fully understand and are able to comply with all operating procedures and safety guidelines in the product manual. Improper use may result in equipment damage or personal injury.\n\n3. Improper Operation\nThe Company shall not be held liable for any injury or loss resulting from the user\'s failure to follow the instructions in the product manual or failure to take appropriate safety measures.\n\n4. Maintenance\nPlease inspect and maintain the product regularly to ensure it is in good working condition. The Company is not responsible for any accidents caused by improper maintenance of the product.\n\n5. Disclaimer of Liability\nWhile the Company provides comprehensive usage instructions and safety measures, it reserves the right to disclaim liability for any injury or damage caused by improper user operation or violations of the manual. We strongly advise users to understand and comply with all relevant safety regulations and operating standards before using this product.\n\n6. Governing Law\nThe interpretation, application, and dispute resolution of this Disclaimer shall be governed by the laws of the jurisdiction where the Company is headquartered.\n\n7. Entire Agreement\nThis Disclaimer constitutes the entire agreement between you and the Company and supersedes any prior oral or written understandings or agreements.';

  @override
  String get productDisclaimerInfo =>
      'I have read and agree to the above content';

  @override
  String get productDisclaimerTitle => 'Product Disclaimer';

  @override
  String get positioningLightFaultAlarmContent =>
      'The red pointer (aiming beam) has a fault. Check whether the aiming beam is on; if not, contact LaserCyber support.';

  @override
  String get positioningLightFaultAlarmTitle => 'Red Pointer Fault';

  @override
  String get protectiveLensOvertemperatureAlarmContent =>
      'If the protective lens shows burn marks, replace it immediately.';

  @override
  String get protectiveLensOvertemperatureAlarmTitle =>
      'Protective Lens Overtemperature';

  @override
  String get protectiveMirrorTempLabel => 'Protective Mirror';

  @override
  String get protectiveMirrorTemperatureText => 'Protective Lens Temperature';

  @override
  String get pumpBoardTemperatureText => 'Pump Board Temperature';

  @override
  String get pumpCurrentText => 'Pump Current';

  @override
  String get pumpModuleOvertemperatureAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get pumpModuleOvertemperatureAlarmTitle =>
      'Pump Module Overtemperature';

  @override
  String get pumpModuleOvertemperatureClearedTitle =>
      'Pump Module Overtemperature Cleared';

  @override
  String get pumpSourceTemperatureAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get pumpSourceTemperatureAlarmTitle => 'Pump Temperature Alarm';

  @override
  String get pumpSourceVoltageAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get pumpSourceVoltageAlarmTitle => 'Pump Voltage Alarm';

  @override
  String get pumpStatusText => 'Pump Comm';

  @override
  String get pumpTemperatureText => 'Pump Temperature';

  @override
  String get quiescentCurrentAbnormalAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get quiescentCurrentAbnormalAlarmTitle => 'Abnormal Quiescent Current';

  @override
  String get redLightCurrentAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get redLightCurrentAlarmTitle => 'Red Pointer Current Alarm';

  @override
  String get redLightCurrentText => 'Red Pointer Current';

  @override
  String get redLightLabel => 'Red Light';

  @override
  String get redLightText => 'Red Pointer';

  @override
  String get rgbLedText => 'LED';

  @override
  String get rgbLedFooter =>
      'Use these controls to test the status LED indicators on this device.';

  @override
  String get safetyLockLabel => 'Safety Lock';

  @override
  String get safetyGroundLockNotConnectedMessage =>
      'Connect the safety clamp before enabling the laser.';

  @override
  String get safetyGroundLockNotConnectedTitle => 'Safety Clamp Disconnected';

  @override
  String get safetyLockText => 'Safety Clamp';

  @override
  String get safetyTipsAgree => 'AGREE';

  @override
  String get safetyTipsContent =>
      '1. Ensure there are no other personnel, reflective objects, or flammable materials nearby during welding.\n\n2. Ensure the safety clamp is securely fastened to the welding table; do not clamp the safety lock onto the welding torch holder, nozzle, wire feed assembly, etc.\n\n3. Ensure you wear professional protective eyewear, a mask, earplugs, and high-temperature resistant gloves.\n\n4. When installing and debugging the equipment, always switch the laser to the off position after laser operation.\n\n5. Ensure the equipment is properly grounded; interruption at any point in the grounding circuit may result in personal injury.\n\n6. Ensure the filter is well-ventilated; promptly remove any foreign objects or dirt.';

  @override
  String get safetyTipsInfo => 'I have read the above content and the';

  @override
  String get safetyTipsInfoUse => 'Product Use Disclaimer.';

  @override
  String get safetyTipsTitle => 'Safety Operation Tips';

  @override
  String get screenBrightnessText => 'Brightness';

  @override
  String get screenDisplayText => 'Display';

  @override
  String get screenOffOption10Min => '10 min';

  @override
  String get screenOffOption30Min => '30 min';

  @override
  String get screenOffOption60Min => '60 min';

  @override
  String get screenOffTimeText => 'Auto Screen Off';

  @override
  String get screenSettings => 'Display';

  @override
  String get sensorAbnormalAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get sensorAbnormalAlarmTitle => 'Sensor Fault';

  @override
  String get sensorChannelDeviationAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get sensorChannelDeviationAlarmTitle => 'Sensor Channel Deviation';

  @override
  String get settingsNavLabel => 'Settings';

  @override
  String get settingsTabAdvanced => 'Advanced';

  @override
  String get settingsTabCommon => 'General';

  @override
  String get settingsTabCustomHome => 'Custom Home';

  @override
  String get settingsTabDeviceInfo => 'Device Info';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get shieldingGasAlarmCauseBlowPressure =>
      'Shielding gas pressure too low';

  @override
  String get shieldingGasAlarmCauseDeviceService =>
      'Equipment fault, please contact after-sales service';

  @override
  String get shieldingGasAlarmCauseInletPressure =>
      'Inlet gas pressure too low';

  @override
  String get shieldingGasAlarmCausePressureCheck =>
      'Gas pressure check abnormal';

  @override
  String get shieldingGasAlarmContent =>
      'Please check if the shielding gas is on and if the gas cylinder is low. If the machine still alarms after confirming these are correct, please contact after-sales service.';

  @override
  String shieldingGasAlarmEngineerCheckMessage(String reason) {
    return 'Shielding gas fault: $reason';
  }

  @override
  String shieldingGasAlarmLogMessage(String reason) {
    return 'A001 shielding gas alarm, reason: $reason';
  }

  @override
  String shieldingGasAlarmReasonBullet(String reason) {
    return '· $reason';
  }

  @override
  String get shieldingGasAlarmReasonHeader => 'Reason:';

  @override
  String get shieldingGasAlarmTitle => 'Shielding Gas Alarm';

  @override
  String shieldingGasAlarmWarnLogContent(String summary) {
    return '$summary. If the machine still alarms after confirming these are correct, please contact after-sales service.';
  }

  @override
  String get showStartupSelfCheck => 'Show Startup Self-Check';

  @override
  String get showSystemStatusOverlay => 'Show System Status Overlay';

  @override
  String get soundEffectCheck => 'Sound Effect';

  @override
  String get soundEffectOption1 => 'Sound 1';

  @override
  String get soundEffectOption2 => 'Sound 2';

  @override
  String get soundEffectOption3 => 'Sound 3';

  @override
  String get soundSettings => 'Sound';

  @override
  String get sshDebugText => 'SSH Debug';

  @override
  String get sshDebugFooter =>
      'When enabled, you can connect to this device over the network for remote troubleshooting. Turns off after reboot. USB debugging is set separately under USB OTG.';

  @override
  String get settingsMayRestartApp =>
      'Some of the settings may restart the application.';

  @override
  String get straightTrackTemperatureAlarmContent =>
      'Inspect the collimating lens. If the collimating lens has burn marks, replace it immediately.';

  @override
  String get tempBoardRefrigerationCommAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get tempBoardRefrigerationCommAlarmTitle =>
      'Temperature Board–Cooling Communication Fault';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get undervoltage24vAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get undervoltage24vAlarmTitle => '24 V Undervoltage';

  @override
  String get unitImperial => 'Imperial';

  @override
  String get unitMetric => 'Metric';

  @override
  String get unitOptionImperial => 'IN';

  @override
  String get unitOptionMetric => 'MM';

  @override
  String get unitPersistedFooter =>
      'Choose Metric (°C, mm) or Imperial (°F, in) for values shown on this device.';

  @override
  String get unitPreferenceUnavailable =>
      'Unit settings are temporarily unavailable.';

  @override
  String get unitSettingText => 'Unit';

  @override
  String get usbOtgModeDebug => 'Debug';

  @override
  String get usbOtgModeHost => 'Host';

  @override
  String get usbOtgModeMtp => 'MTP';

  @override
  String get usbOtgText => 'USB OTG';

  @override
  String get videosTitle => 'Videos';

  @override
  String get processVideoRecordingTime => 'Recording Time';

  @override
  String get processVideoWorkMode => 'Work Mode';

  @override
  String get processVideoMaterial => 'Material';

  @override
  String get processVideoDuration => 'Duration';

  @override
  String get processVideoOperations => 'Operations';

  @override
  String get processVideoEmptyTitle => 'No recordings';

  @override
  String get processVideoEmptySubtitle =>
      'Record Work videos from Quick or Engineer mode will appear here.';

  @override
  String get processVideoDeleteConfirmTitle => 'Delete recording?';

  @override
  String get processVideoDeleteConfirmMessage =>
      'This removes the video file and its process parameters from this device.';

  @override
  String get processVideoUploadConfirmTitle => 'Upload recording?';

  @override
  String get processVideoUploadConfirmMessage =>
      'Upload this video and its process parameters to the cloud. Make sure the device is online.';

  @override
  String get uploadText => 'Upload';

  @override
  String get processVideoDetailTitle => 'Video Details';

  @override
  String get processVideoBackToVideos => 'Back to Videos';

  @override
  String get processVideoParametersTitle => 'Parameter recording';

  @override
  String get processVideoPlaybackFailed => 'Unable to play this recording';

  @override
  String processVideoLoadedCount(int loaded, int total) {
    return '$loaded / $total';
  }

  @override
  String get recordWorkLabel => 'Record Work';

  @override
  String get processVideoRecordingTooShort => 'Recording too short — not saved';

  @override
  String get processVideoSaveFailed => 'Failed to save recording';

  @override
  String get processVideoUpload => 'Upload';

  @override
  String get processVideoUploadingCover => 'Uploading cover…';

  @override
  String processVideoUploadingVideo(int percent) {
    return 'Uploading video $percent%';
  }

  @override
  String get processVideoUploadFailed => 'Upload failed';

  @override
  String get processVideoUploadDone => 'Upload complete';

  @override
  String get processVideoAlreadyUploaded => 'Already uploaded';

  @override
  String get ipCameraDemoRecordHint =>
      'Demo only — not listed in Monitor → Videos';

  @override
  String get volumeSetFailed => 'Couldn’t set volume';

  @override
  String get volumeSettingText => 'Volume';

  @override
  String get warnInfoLastWork => 'Last Op-Time';

  @override
  String get warnInfoLightTime => 'Total Laser-On Time';

  @override
  String get warnInfoLightTimeInfo => 'vs. last week';

  @override
  String get warnInfoWeldingConsumables => 'Total Wire Used';

  @override
  String get warnInfoWeldingConsumablesInfo => 'Common consumables';

  @override
  String get washProportionText => 'Cleaning Ratio';

  @override
  String get waterTemperatureUpperLimitAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get waterTemperatureUpperLimitAlarmTitle => 'Water Temperature High';

  @override
  String get weldingProportionText => 'Welding Ratio';

  @override
  String get wifiAdvancedSettings => 'IP Settings';

  @override
  String get wifiAdvancedSettingsHide => 'Hide IP Settings';

  @override
  String get wifiApply => 'Apply';

  @override
  String get wifiDetailsTitle => 'Wi‑Fi Details';

  @override
  String get wifiDialogConnect => 'Connect';

  @override
  String get wifiDialogHidePassword => 'Hide password';

  @override
  String get wifiDialogPasswordLabel => 'Password';

  @override
  String get wifiDialogShowPassword => 'Show password';

  @override
  String get wifiDialogSsidLabel => 'Network Name';

  @override
  String get wifiDns => 'DNS';

  @override
  String get wifiDns1 => 'DNS 1';

  @override
  String get wifiDns2 => 'DNS 2';

  @override
  String get wifiEditIpConfig => 'Edit IP Configuration';

  @override
  String get wifiEditIpSuccess => 'IP configuration saved';

  @override
  String get wifiErrorAddNotAllowed =>
      'Request denied. Allow Wi‑Fi suggestions for this app.';

  @override
  String get wifiErrorDuplicateProfile => 'This Wi‑Fi profile already exists';

  @override
  String get wifiErrorInternal => 'System error while saving the Wi‑Fi profile';

  @override
  String get wifiErrorRemoveInvalid => 'Invalid saved Wi‑Fi profile';

  @override
  String wifiErrorSaveFailedFormat(int code) {
    return 'Failed to save Wi‑Fi profile (code $code)';
  }

  @override
  String get wifiErrorTooManyProfiles =>
      'Too many saved Wi‑Fi profiles for this app';

  @override
  String get wifiForgetConfirmMessage => 'Forget this network and disconnect?';

  @override
  String get wifiForgetNetwork => 'Forget Network';

  @override
  String get wifiForgetPartialFailed => 'Couldn’t fully forget this network';

  @override
  String get wifiForgetSuccess => 'Network forgotten';

  @override
  String get wifiFrequency => 'Frequency';

  @override
  String get wifiGateway => 'Gateway';

  @override
  String get wifiHiddenNetworkConnect => 'Connect to Hidden Network';

  @override
  String get wifiHiddenNetworkTitle => 'Connect to Hidden Network';

  @override
  String get wifiIpAddress => 'IP Address';

  @override
  String wifiIpFieldEnterHint(String field) {
    return 'Enter $field';
  }

  @override
  String get wifiIpMode => 'IP Mode';

  @override
  String get wifiIpModeDhcp => 'DHCP';

  @override
  String get wifiIpModeStatic => 'Static';

  @override
  String get wifiIpSettings => 'IP Settings';

  @override
  String get wifiIpSettingsHide => 'Hide IP Settings';

  @override
  String wifiJoinSsidFormat(String ssid) {
    return 'Join “$ssid”';
  }

  @override
  String get wifiLinkSpeed => 'Link Speed';

  @override
  String wifiListStandardFormat(String band) {
    return 'Wi‑Fi $band';
  }

  @override
  String get wifiMacAddress => 'MAC Address';

  @override
  String get wifiMyNetworks => 'My Networks';

  @override
  String get wifiNetworkText => 'Wi‑Fi';

  @override
  String get wifiNoOtherNetworks => 'No networks found';

  @override
  String get wifiNoSavedNetworks => 'No saved networks';

  @override
  String get wifiNotAvailable => 'Unavailable';

  @override
  String get wifiOpenSystemSettingsHint =>
      'This network is managed by system Wi‑Fi. Open system settings to forget it completely.';

  @override
  String get wifiOtherNetworks => 'Other Networks';

  @override
  String get wifiOthersSection => 'Others';

  @override
  String get wifiRouter => 'Router';

  @override
  String get wifiScanning => 'Scanning…';

  @override
  String get wifiSecurity => 'Security';

  @override
  String get wifiSecurityOpen => 'Open';

  @override
  String get wifiSecurityWpa2 => 'WPA2';

  @override
  String get wifiSecurityWpa3 => 'WPA3';

  @override
  String get wifiSignalStrength => 'Signal Strength';

  @override
  String get wifiStaticIpConflict =>
      'IP address conflicts with another interface';

  @override
  String get wifiStaticIpGatewaySubnet => 'Gateway must be on the same subnet';

  @override
  String get wifiStaticIpIncomplete =>
      'Please fill in all required static IP fields';

  @override
  String get wifiStaticIpInvalid => 'Invalid static IP configuration';

  @override
  String get wifiStatusConnected => 'Connected';

  @override
  String get wifiStatusConnecting => 'Connecting…';

  @override
  String get wifiStatusNotConnected => 'Not connected';

  @override
  String get wifiSubnetMask => 'Subnet Mask';

  @override
  String get wifiAutoJoin => 'Auto Join';

  @override
  String get wifiAutomatic => 'Automatic';

  @override
  String get wifiConfigureDns => 'Configure DNS';

  @override
  String get wifiConfigureIp => 'Configure IP';

  @override
  String get wifiDnsServers => 'DNS Servers';

  @override
  String get wifiIpv4AddressSection => 'IPv4 Address';

  @override
  String get wifiManual => 'Manual';

  @override
  String get wifiAddDnsServer => 'Add DNS Server';

  @override
  String get wifiRemoveDnsServer => 'Remove';

  @override
  String get wifiMaxDnsServers => 'You can add up to 3 DNS servers';

  @override
  String get wifiToastAddCanceledBySystem =>
      'Adding Wi‑Fi was canceled by the system';

  @override
  String get wifiToastAddedConnecting => 'Network added. Connecting…';

  @override
  String get wifiToastConnectedSuccess => 'Connected';

  @override
  String get wifiToastConnectionFailed => 'Connection failed';

  @override
  String get wifiToastDetailsOnlyWhenConnected =>
      'Details are only available for the connected network';

  @override
  String get wifiToastInvalidBssid => 'Invalid BSSID format';

  @override
  String get wifiToastNoConnectionDetails => 'No connected Wi‑Fi details';

  @override
  String get wifiToastPasswordRequired => 'Password is required';

  @override
  String get wifiToastProfileExistsConnecting =>
      'This network is already saved. Connecting…';

  @override
  String get wifiToastProfileSavedUseSystem =>
      'Profile saved. Connect from the system Wi‑Fi list.';

  @override
  String get wifiToastRequiresSystemPrivilege =>
      'System Wi‑Fi permission required. Install this app as a privileged system app.';

  @override
  String get wifiToastSsidRequired => 'Network name is required';

  @override
  String get wifiToastWifiDisabled => 'Wi‑Fi is off';

  @override
  String get wifiWlanLabel => 'Wi‑Fi';

  @override
  String get watchdogResetEventContent =>
      'The controller restarted after a watchdog reset. If this happens often, contact LaserCyber support.';

  @override
  String get watchdogResetEventTitle => 'Watchdog Reset';

  @override
  String get wireFeederCommunicationAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get wireFeederCommunicationAlarmTitle =>
      'Wire Feeder Communication Alarm';

  @override
  String get wireFeederCurrentAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get wireFeederCurrentAlarmTitle => 'Wire Feeder Current Alarm';

  @override
  String get wireFeedingLabel => 'Wire Feeding';

  @override
  String get wireFeedingMachineCommunicationText => 'Feeder Comm';

  @override
  String get wireFeedingText => 'Wire Feeder';

  @override
  String get wireFeederVersion => 'Wire Feeder Version';

  @override
  String get wirelessNetworkText => 'Wireless Network';

  @override
  String get workInfoTitle => 'Work Info';

  @override
  String get workTitle => 'Work Info';

  @override
  String get zeroPointOffsetAlarmContent =>
      'Zero offset is off center. Open Advanced Settings and correct it before continuing precise work.';

  @override
  String get zeroPointOffsetAlarmTitle => 'Zero Offset Alarm';
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');
}
