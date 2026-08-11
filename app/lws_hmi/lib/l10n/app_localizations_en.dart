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
  String get advancedSettingAutoZeroOffsetMessage =>
      'Aim the welding gun at a safe area and hold the trigger, then tap Auto. Auto temporarily enables laser output; the trigger fires the laser. Wait for the progress bar to finish automatic zero-offset correction.';

  @override
  String get advancedSettingAutoZeroOffsetTitle => 'Auto Zero Offset';

  @override
  String get advancedSettingCollimatingLensTempAlarmThreshold =>
      'Collimating Lens Temperature Alarm Threshold';

  @override
  String get advancedSettingDriverTempAlarmThreshold =>
      'Driver Temperature Alarm Threshold';

  @override
  String get advancedSettingEnterCollimatingLensTempAlarmThreshold =>
      'Enter collimating lens temperature alarm threshold';

  @override
  String get advancedSettingEnterDriverTempAlarmThreshold =>
      'Enter driver temperature alarm threshold';

  @override
  String get advancedSettingEnterInletGasPressure =>
      'Enter inlet gas pressure threshold';

  @override
  String get advancedSettingEnterLaserEndPower => 'Enter laser end power';

  @override
  String get advancedSettingEnterLaserStartPower => 'Enter laser start power';

  @override
  String get advancedSettingEnterMinGasPressure =>
      'Enter minimum gas pressure threshold';

  @override
  String get advancedSettingEnterMotorTempAlarmThreshold =>
      'Enter motor temperature alarm threshold';

  @override
  String get advancedSettingEnterProtectiveLensTempAlarmThreshold =>
      'Enter protective lens temperature alarm threshold';

  @override
  String get advancedSettingEnterScanWidthCorrection =>
      'Enter scan width correction';

  @override
  String get advancedSettingEnterTempAlarmRecoveryHysteresis =>
      'Enter temperature alarm recovery hysteresis';

  @override
  String get advancedSettingEnterZeroOffset => 'Enter zero offset';

  @override
  String get advancedSettingInletGasPressure => 'Inlet Gas Pressure Threshold';

  @override
  String get advancedSettingKeepLaserOnWhileAlarmed =>
      'Keep Laser On During Alarms';

  @override
  String get advancedSettingKeepLaserOnWhileAlarmedHint =>
      'When enabled, coded alarms won’t automatically turn off the laser while you’re already welding. Warning dialogs still appear. Use only when the risk is acceptable.';

  @override
  String get advancedSettingLaserEndPower => 'Laser End Power';

  @override
  String get advancedSettingLaserStartPower => 'Laser Start Power';

  @override
  String get advancedSettingLensContaminationDetection =>
      'Lens Contamination Detection';

  @override
  String get advancedSettingLensContaminationDetectionHint =>
      'Uses the camera and AI to watch the protective lens during work and warn when contamination is detected. Turn off only if detection is inaccurate or unavailable.';

  @override
  String get advancedSettingMinGasPressure => 'Min. Gas Pressure';

  @override
  String get advancedSettingMotorTempAlarmThreshold =>
      'Motor Temperature Alarm Threshold';

  @override
  String get advancedSettingProtectiveLensTempAlarmThreshold =>
      'Protective Lens Temperature Alarm Threshold';

  @override
  String get advancedSettingScale0Celsius => '0℃';

  @override
  String get advancedSettingScale20Celsius => '20℃';

  @override
  String get advancedSettingScale80Celsius => '80℃';

  @override
  String get advancedSettingScale85Celsius => '85℃';

  @override
  String get advancedSettingScanWidthCorrection => 'Scan Width Correction';

  @override
  String get advancedSettingShowBootSelfCheck => 'Show Startup Self-Check';

  @override
  String get advancedSettingTempAlarmRecoveryHysteresis =>
      'Temperature Alarm Recovery Hysteresis';

  @override
  String get advancedSettingText => 'Advanced';

  @override
  String get advancedSettingValueRequired => 'Value Is Required';

  @override
  String get advancedSettingZeroOffset => 'Zero Offset';

  @override
  String get advancedSettingZeroOffsetAuto => 'Auto';

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
  String get aiVisionComingSoon => 'AI Vision — Coming Soon';

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
  String get alarmLogsClearedMessage => 'Done';

  @override
  String get alarmLogsClearedTitle => 'Cleared';

  @override
  String get alarmLogsTitle => 'Alarm Log';

  @override
  String get alarmRebootThenSupportContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get alarmTitle => 'Alarms';

  @override
  String get anyMaterialLabel => 'Any Material';

  @override
  String get applyToDevice => 'Apply To Device';

  @override
  String get autoCheckOtaUpdate => 'Auto-Check for Updates';

  @override
  String autoOtaUpdateDialogMessage(String version) {
    return 'Version $version is available. Go to Settings to review and install the update.';
  }

  @override
  String get autoOtaUpdateDialogTitle => 'Update Available';

  @override
  String autoControlBoardUpdateDialogMessage(String version) {
    return 'Control board firmware $version is available. Go to Settings to review and install the update.';
  }

  @override
  String get autoControlBoardUpdateDialogTitle =>
      'Control Board Firmware Available';

  @override
  String autoCameraProgramUpdateDialogMessage(String version) {
    return 'Camera firmware $version is available. Go to Settings to review and install the update.';
  }

  @override
  String get autoCameraProgramUpdateDialogTitle => 'Camera Firmware Available';

  @override
  String get goToSettings => 'Go to Settings';

  @override
  String get autoWireFeed => 'Auto Wire Feed';

  @override
  String get blowOnLabel => 'Gas Flow';

  @override
  String get blowText => 'Gas Flow';

  @override
  String get blowingAirPressureText => 'Shielding Gas Pressure';

  @override
  String get bluetoothAsSpeaker => 'As A Speaker';

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
  String get builtInLabel => 'Built-In';

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
  String get cameraChangeOverlay => 'Change Overlay';

  @override
  String get cameraCommStatusText => 'Camera Comm';

  @override
  String get cameraCommunicationAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get cameraCommunicationAlarmTitle => 'Camera Communication Alarm';

  @override
  String get cameraOverlayApplyFailed => 'Couldn’t apply overlay';

  @override
  String get cameraOverlayEnable => 'Enable Overlay';

  @override
  String get cameraOverlayPositionX => 'Position X';

  @override
  String get cameraOverlayPositionY => 'Position Y';

  @override
  String get cameraStatus => 'Status';

  @override
  String get cameraStatusEstablishing => 'Establishing…';

  @override
  String get cameraStatusFailed => 'Failed';

  @override
  String get cameraType => 'Camera Type';

  @override
  String get cameraTypeBlueLight => 'Blue Light';

  @override
  String get cameraTypeRedLight => 'Red Light';

  @override
  String get cameraVersion => 'Camera Version';

  @override
  String cameraProgramAlreadyUpToDate(String version) {
    return 'Camera firmware $version is up to date.';
  }

  @override
  String get cameraProgramCheckFailed =>
      'Could not check camera firmware. Verify camera network connection.';

  @override
  String get cameraProgramCheckUnavailable =>
      'Camera firmware check is not available right now.';

  @override
  String cameraProgramDialogMessage(String currentVersion, String newVersion) {
    return 'A newer camera firmware is available ($currentVersion → $newVersion).\nKeep power connected and don’t operate the device during the upgrade.';
  }

  @override
  String get cameraProgramFailedMessage =>
      'Camera firmware update failed. Try again later.';

  @override
  String get cameraProgramFailedTitle => 'Camera Update Failed';

  @override
  String cameraProgramNewVersionHeadline(String version) {
    return 'New camera firmware $version';
  }

  @override
  String get cameraProgramRebootTitle => 'Rebooting Camera';

  @override
  String get cameraProgramSuccessMessage => 'Camera firmware has been updated.';

  @override
  String get cameraProgramSuccessTitle => 'Camera Updated';

  @override
  String get cameraProgramTransferTitle => 'Transferring Camera Firmware';

  @override
  String get cameraProgramUpgradeIdleHint =>
      'Check for newer camera firmware bundled with this App.';

  @override
  String get cameraProgramUpgradeTitle => 'Camera Upgrade';

  @override
  String get cameraProgramUpgradingMessage =>
      'Keep power connected and don’t operate the device during the upgrade.';

  @override
  String get cameraProgramWaitOnlineTitle => 'Waiting for Camera';

  @override
  String get cancelText => 'Cancel';

  @override
  String get cellularNetworkText => 'Cellular';

  @override
  String get celsiusUnit => '°C';

  @override
  String controlBoardAlreadyUpToDate(String version) {
    return 'Control board firmware $version is up to date.';
  }

  @override
  String get controlBoardCheckFailed =>
      'Could not check control board firmware. Verify Modbus connection.';

  @override
  String get controlBoardCheckUnavailable =>
      'Control board firmware check is not available right now.';

  @override
  String controlBoardNewVersionHeadline(String version) {
    return 'New firmware $version';
  }

  @override
  String get controlBoardUpgradeIdleHint =>
      'Check for newer control board firmware bundled with this App.';

  @override
  String get controlBoardUpgradeTitle => 'Control Board Upgrade';

  @override
  String get checkUpdate => 'Check for Updates';

  @override
  String get checkingStatus => 'Checking…';

  @override
  String get clearAlarmLogs => 'Clear';

  @override
  String get closeText => 'Close';

  @override
  String get cloudEnvironmentTier => 'Cloud Environment';

  @override
  String get cloudEnvironmentTierDev => 'Dev';

  @override
  String get cloudEnvironmentTierProd => 'Prod';

  @override
  String get cloudEnvironmentTierTest => 'Test';

  @override
  String get cloudServicesFooter =>
      'When enabled, this device can use LaserCyber cloud services for remote management and data sync whenever a network is available.';

  @override
  String get cloudServicesSummaryBoth => 'Cloud + LAN';

  @override
  String get cloudServicesSummaryCloud => 'Cloud';

  @override
  String get cloudServicesSummaryLan => 'LAN';

  @override
  String get cloudServicesText => 'Cloud Services';

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
  String get completeSelectionToPreview =>
      'Complete the selection to preview parameters.';

  @override
  String get confirmText => 'Confirm';

  @override
  String get connectSafetyClampBeforeLaser =>
      'Connect the safety clamp before enabling the laser.';

  @override
  String get connectedText => 'Connected';

  @override
  String get controllerTabletCommAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get controllerTabletCommAlarmTitle =>
      'Control Board Communication Error';

  @override
  String get copyAsUserProcess => 'Copy As User Process';

  @override
  String get currentAlarmText => 'Current Alarm';

  @override
  String get currentProcessName => 'Current Process Name';

  @override
  String get customHomePage => 'Custom Home';

  @override
  String get customHomeReplacementSelected => 'Selected';

  @override
  String get customHomeSelectFourCards => 'Please Select 4 Cards';

  @override
  String get customHomeSelectReplaceCard => 'Please Select A Card To Replace';

  @override
  String get customMaterialName => 'Custom Material Name';

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
  String get dateTimeModeAuto => 'Auto';

  @override
  String get dateTimeModeManual => 'Manual';

  @override
  String get dateTimeNtpAliyun => 'Aliyun';

  @override
  String get dateTimeNtpApple => 'Apple';

  @override
  String get dateTimeNtpCloudflare => 'Cloudflare';

  @override
  String get dateTimeNtpCnPool => 'China NTP Pool';

  @override
  String get dateTimeNtpGoogle => 'Google';

  @override
  String get dateTimeNtpPool => 'NTP Pool';

  @override
  String get dateTimeNtpServer => 'Time Server';

  @override
  String get dateTimeNtpTencent => 'Tencent';

  @override
  String get dateTimeNtpWindows => 'Windows';

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
  String get dateTimeSetTimeZone => 'Time Zone';

  @override
  String get dateTimeSettings => 'Date & Time';

  @override
  String get dateTimeTimezoneApplyFailed => 'Couldn’t update time zone';

  @override
  String get dateTimeTimezoneGeoFailed =>
      'Couldn’t set time zone from network location';

  @override
  String get dateTimeUse24HourFormat => 'Use 24-Hour Format';

  @override
  String get defaultLabel => 'Default';

  @override
  String get deleteText => 'Delete';

  @override
  String get details => 'Details';

  @override
  String get deviceBindBody =>
      'Scan the QR code with the LaserCyber app to bind this device.';

  @override
  String get deviceBindTitle => 'Bind This Device';

  @override
  String get deviceControlAutoWireFeedOff => 'Wire Feed Turned Off';

  @override
  String get deviceControlAutoWireFeedOn => 'Auto Wire Feed Enabled';

  @override
  String get deviceControlCameraUnavailable => 'Camera Unavailable';

  @override
  String get deviceControlContinuousFeedLabel => 'Continuous Feed';

  @override
  String get deviceControlEmergencyStopError => 'Device is in E-stop';

  @override
  String get deviceControlEndOfWorkFailed =>
      'End of work failed — check controller link';

  @override
  String get deviceControlEndOfWorkFirst => 'End Of Work First';

  @override
  String get deviceControlFeedHoldHint => 'Hold 3s to keep on';

  @override
  String get deviceControlFeedOngoing => 'Feeding…';

  @override
  String get deviceControlFeedPulseSuccess => 'Feed+ Started';

  @override
  String get deviceControlFeedStopped => 'Feed Stopped';

  @override
  String get deviceControlKeySwitchOffError => 'Key switch is off';

  @override
  String get deviceControlManualGasOff => 'Manual Gas Turned Off';

  @override
  String get deviceControlManualGasOn => 'Manual Gas On';

  @override
  String get deviceControlOperationFailed => 'Operation Failed';

  @override
  String get deviceControlRetractPulseSuccess => 'Feed Started';

  @override
  String get deviceControlStopFeed => 'Stop Feed+';

  @override
  String get deviceControlWireUnavailableInMode =>
      'Wire Feed Unavailable In This Mode';

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
  String get deviceRegisterBody =>
      'This device is unrecognized, please scan the QR code with LaserCyber app to register it.';

  @override
  String get deviceRegisterReconnect => 'Reconnect';

  @override
  String get deviceRegisterTitle => 'Register This Device';

  @override
  String get deviceRemoteLockBody =>
      'This device has been locked remotely. Contact your administrator to unlock.';

  @override
  String get deviceRemoteLockTitle => 'Device Locked';

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
  String get doneText => 'Done';

  @override
  String get dontShowAgain => 'Don’t show again';

  @override
  String get dontShowAgainThisSession => 'Don’t show again this session';

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
  String get eStopLabel => 'E-Stop';

  @override
  String get editProcess => 'Edit Process';

  @override
  String get editText => 'Edit';

  @override
  String get emptyText => '';

  @override
  String get endOfWork => 'End Work';

  @override
  String get engineerModeEntryBody =>
      'Engineer mode unlocks advanced parameter customization for experienced users. We recommend learning how the machine works before making fine adjustments.';

  @override
  String get engineerModeEntryConfirm => 'Confirm & Enter';

  @override
  String get engineerModeEntryTitle => 'Engineer Mode Notice';

  @override
  String get engineerNumericValueInvalid => 'Invalid value';

  @override
  String engineerNumericValueOutOfRange(String min, String max) {
    return 'Value must be between $min and $max';
  }

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
  String get ethernetLink => 'Link';

  @override
  String get ethernetManualIp => 'Manual IP';

  @override
  String get ethernetPrefix => 'Prefix';

  @override
  String get ethernetText => 'Ethernet';

  @override
  String get fahrenheitUnit => '°F';

  @override
  String get failStatus => 'Fault';

  @override
  String get favoriteMaterial => 'Common consumables';

  @override
  String get feed => 'Feed';

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
  String get focusScaleReference => 'Focus Scale Reference';

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
  String get gasFlowLabel => 'Gas Flow';

  @override
  String get gasPressureLabel => 'Gas Pressure';

  @override
  String get gearLabel => 'Gear';

  @override
  String get gotItText => 'OK';

  @override
  String get groundClampLabel => 'Safety Clamp';

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
  String get gunMotorTempText => 'Motor Temperature';

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
  String get holdToEnableLaser => 'Hold To Enable Laser';

  @override
  String get hmiUpgradeTitle => 'HMI Upgrade';

  @override
  String get hmiVersion => 'HMI Version';

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
  String get ipCameraCameraNotConnected => 'Camera Not Connected';

  @override
  String get ipCameraDemoRecordHint =>
      'Demo only — not listed in Monitor → Videos';

  @override
  String get ipCameraEstablishingVideo => 'Establishing Video…';

  @override
  String get ipCameraPreviewFailed => 'Preview Failed';

  @override
  String ipCameraRecordError(String error) {
    return 'Record Error: $error';
  }

  @override
  String ipCameraRecordingSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String ipCameraStopError(String error) {
    return 'Stop Error: $error';
  }

  @override
  String get ipCameraText => 'Camera';

  @override
  String get jobRuntime => 'Last Op-Time';

  @override
  String get kernelVersion => 'Kernel Version';

  @override
  String get keySwitchLabel => 'Key Switch';

  @override
  String get keyboardApplyConfirmBody =>
      'Saves the selected layout and restarts HMI so soft CyberIME and physical keyboard both take effect. This page will reopen after relaunch.';

  @override
  String get keyboardApplyConfirmTitle => 'Apply Keyboard Layout?';

  @override
  String get keyboardLayoutHelp =>
      'Attach a physical keyboard that matches the selected specification. A mismatch may make some keys produce unexpected characters.';

  @override
  String get keyboardSoftLayoutPreview => 'Software Keyboard Layout Preview';

  @override
  String get keyboardLongPressAccentHint =>
      'Long-Press For Accented Characters';

  @override
  String get keyboardNotDetected => 'Not Detected';

  @override
  String get keyboardPhysicalSection => 'Physical Keyboard';

  @override
  String get keyboardText => 'Keyboard';

  @override
  String get lanEnhancementFooter =>
      'When enabled, phones and computers on the same local network can find and manage this device.';

  @override
  String get lanEnhancementText => 'LAN Enhancement';

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
      'Language Preference Unavailable.';

  @override
  String get languageSettingText => 'Language';

  @override
  String get countrySettingText => 'Country/Region';

  @override
  String get countryAppliesFooter =>
      'Sets Wi‑Fi regulatory domain and default time zone / NTP server. Language stays separate.';

  @override
  String get countryPreferenceUnavailable =>
      'Country/Region settings are temporarily unavailable.';

  @override
  String get countrySearchHint => 'Search by name or country/region code';

  @override
  String get countryNoMatches => 'No countries/regions found';

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
  String get laserEnable => 'Enable Laser';

  @override
  String get laserEnableBlockAlarmBlocked => 'Alarm Blocks Laser Enable';

  @override
  String get laserEnableBlockBusy => 'Control Busy';

  @override
  String get laserEnableBlockEmergencyStop => 'Release E-stop First';

  @override
  String get laserEnableBlockKeySwitchOff => 'Turn Key Switch On';

  @override
  String get laserEnableBlockManualGasOn => 'Turn Off Manual Gas First';

  @override
  String get laserEnableBlockStatusUnavailable => 'Check Equipment Status';

  @override
  String get laserEnableBlockWriteFailed => 'Laser Enable Did Not Take Effect';

  @override
  String get laserEnableReminderConfirm =>
      'Yes — I\'ve Completed The Safety Checks Above';

  @override
  String get laserEnableReminderFocus =>
      'Set the welding gun focus scale to the indicated value.';

  @override
  String get laserEnableReminderNozzleClean =>
      'Confirm the laser tube and copper nozzle have been removed.';

  @override
  String get laserEnableReminderNozzleCut =>
      'Confirm the cutting copper nozzle is installed.';

  @override
  String get laserEnableReminderNozzleWeld =>
      'Confirm the welding copper nozzle is installed.';

  @override
  String get laserEnableReminderPpe =>
      'Confirm you\'re wearing laser protective equipment.';

  @override
  String get laserEnableReminderTitle => 'Important';

  @override
  String get laserOff => 'Laser Off';

  @override
  String get liveMachineStatusTitle => 'Live Machine Status';

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
  String get laserTimeVsLastWeek => 'vs. last week';

  @override
  String get laserVersion => 'Laser Version';

  @override
  String get ledColorGreen => 'Green';

  @override
  String get ledColorRed => 'Red';

  @override
  String get ledColorYellow => 'Yellow';

  @override
  String get ledModeBlink => 'Blink';

  @override
  String get ledModeSteady => 'Steady';

  @override
  String get lensHeavyContaminationAlarmContent =>
      'Protective lens is heavily contaminated. Clean or replace it.';

  @override
  String get lensHeavyContaminationAlarmTitle => 'Lens Contamination Alarm';

  @override
  String get liveVideoFailed => 'Live video unavailable';

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
  String get manualGas => 'Manual Gas';

  @override
  String get materialAluminumAlloy => 'Aluminum Alloy';

  @override
  String get materialBrass => 'Brass';

  @override
  String get materialCarbonSteel => 'Carbon Steel';

  @override
  String get materialCustom => 'Custom';

  @override
  String get materialGalvanizedSheet => 'Galvanized Sheet';

  @override
  String get materialLabel => 'Material';

  @override
  String get materialStainlessSteel => 'Stainless Steel';

  @override
  String get materialThickness => 'Material Thickness';

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
  String get modbusCommunicationFault => 'Modbus Communication Fault';

  @override
  String get monitorCleanTimeRatio => 'Cleaning Ratio';

  @override
  String get monitorCutTimeRatio => 'Cutting Ratio';

  @override
  String get monitorLaserOnTime => 'Total Laser-On Time';

  @override
  String get monitorLastJob => 'Last Op-Time';

  @override
  String get monitorNavLabel => 'Monitor';

  @override
  String get monitorWeldTimeRatio => 'Welding Ratio';

  @override
  String get monitorWeldingConsumables => 'Total Wire Used';

  @override
  String get moreFavorites => 'More Favorites';

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
  String get mouseButtonLeft => 'Left';

  @override
  String get mouseButtonRight => 'Right';

  @override
  String get mouseNaturalScrolling => 'Natural Scrolling';

  @override
  String get mousePointerSize => 'Pointer Size';

  @override
  String get mousePrimaryButton => 'Primary Button';

  @override
  String get mouseText => 'Mouse';

  @override
  String get mouseTrackingSpeed => 'Tracking Speed';

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
  String get newUserProcess => 'New User Process';

  @override
  String get noActiveAlarms => 'No Active Alarms';

  @override
  String get noEngineerProcesses => 'No Engineer Processes For This Type';

  @override
  String get noMatchingProcess => 'No Matching Process';

  @override
  String get noMoreFavorites => 'No More Favorites';

  @override
  String get noProcesses => 'No Processes';

  @override
  String get noSignedProcessLibrary => 'No Signed Process Library Installed';

  @override
  String get notConnected => 'Not Connected';

  @override
  String get notConnectingText => 'Not connected';

  @override
  String get notPersistedYet => 'Not Persisted Yet';

  @override
  String get offLabel => 'Off';

  @override
  String get okText => 'OK';

  @override
  String get onLabel => 'On';

  @override
  String get osSettingsBundleMissing =>
      'OS Settings is not installed on this device.';

  @override
  String get osSettingsSwitchFailed => 'Couldn’t open OS Settings.';

  @override
  String get osSettingsText => 'OS Settings';

  @override
  String get osVersion => 'OS Version';

  @override
  String get otaCheckUnavailable =>
      'Software update check is not available on this build.';

  @override
  String get otaCheckFailed =>
      'Could not check for updates. Verify network connectivity.';

  @override
  String get otaSessionActive => 'A system upgrade is already in progress.';

  @override
  String otaAlreadyUpToDate(String version) {
    return 'System version $version is up to date.';
  }

  @override
  String get otaUpdateAvailableTitle => 'Update Available';

  @override
  String otaUpdateAvailableMessage(String current, String available) {
    return 'Version $current → $available. Install now?';
  }

  @override
  String get otaUpdateNow => 'Update Now';

  @override
  String get otaUpdateLater => 'Later';

  @override
  String otaNewVersionHeadline(String version) {
    return 'New version upgrade $version';
  }

  @override
  String get otaUpgradeIdleHint =>
      'Check for a newer system package from the cloud.';

  @override
  String get systemUpgradeTitle => 'System Upgrade';

  @override
  String get otaUpgradeStatusVerifying => 'Verifying package…';

  @override
  String get otaUpgradeStatusExtracting => 'Extracting package…';

  @override
  String get otaUpgradeStatusWriting => 'Writing firmware…';

  @override
  String get otaUpgradeStatusWritingRootfs => 'Writing rootfs…';

  @override
  String get otaUpgradeStatusWritingKernel => 'Writing kernel…';

  @override
  String get otaUpgradeStatusWritingOem => 'Writing oem…';

  @override
  String get otaUpgradeStatusBackingUpBoot => 'Backing up boot…';

  @override
  String get otaUpgradeStatusArming => 'Arming reboot…';

  @override
  String get otaUpgradeStatusComplete => 'Upgrade complete';

  @override
  String get otaUpgradeStatusFailed => 'Upgrade failed';

  @override
  String get otaUpgradeRebootHint => 'Device will reboot to apply the update.';

  @override
  String get otaUpgradeStatusApk => 'Installing app…';

  @override
  String get otaUpgradeStatusRestarting => 'Restarting application…';

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
  String get overTempLabel => 'Over Temp';

  @override
  String get paramBackDrawLength => 'Retract Length';

  @override
  String get paramBackDrawLengthCatalog => 'Retract Length';

  @override
  String get paramBackDrawSpeed => 'Retract Speed';

  @override
  String get paramBackDrawSpeedCatalog => 'Retract Speed';

  @override
  String get paramBlowingDelay => 'Gas Pre-Flow';

  @override
  String get paramBlowingDelayCatalog => 'Gas Pre-Flow';

  @override
  String get paramGasOffDelay => 'Gas Post-Flow';

  @override
  String get paramGasOffDelayCatalog => 'Gas Post-Flow';

  @override
  String get paramGasPostFlow => 'Gas Post-Flow';

  @override
  String get paramGasPostFlowDesc =>
      'Delay before shutting off gas after the laser turns off. Range: 0–10000 ms.';

  @override
  String get paramGasPreFlow => 'Gas Pre-Flow';

  @override
  String get paramGasPreFlowDesc =>
      'Gas pre-flow time before laser emission. Range: 0–10000 ms.';

  @override
  String paramGenericRangeDesc(String min, String max, String unit) {
    return 'Range: $min–$max $unit.';
  }

  @override
  String get paramLaserDutyCycle => 'Laser Duty Cycle';

  @override
  String get paramLaserFrequency => 'Laser Frequency';

  @override
  String get paramLaserOffDelay => 'Laser-Off Delay';

  @override
  String get paramLaserOffDelayDesc =>
      'Delay between stopping wire feed and turning off the laser (for wire cutoff). Range: 0–1000 ms.';

  @override
  String get paramLaserPower => 'Laser Power';

  @override
  String get paramLaserPowerDesc =>
      'Laser output power. 100% equals the machine’s rated maximum (e.g. 1300 W). Range: 0–100%.';

  @override
  String get paramLightOffDelay => 'Laser-Off Delay';

  @override
  String get paramLightOffDelayCatalog => 'Light Off Delay';

  @override
  String get paramPiercingDuration => 'Piercing Duration';

  @override
  String get paramPiercingDutyCycle => 'Piercing Duty Cycle';

  @override
  String get paramPiercingFrequency => 'Piercing Frequency';

  @override
  String get paramPiercingPower => 'Piercing Power';

  @override
  String get paramPowerRampDown => 'Ramp-Down Time';

  @override
  String get paramPowerRampUp => 'Ramp-Up Time';

  @override
  String get paramRampDownTime => 'Ramp-Down Time';

  @override
  String get paramRampDownTimeDesc =>
      'Laser ramp-down time in pulse mode. Range: 0–1000 ms.';

  @override
  String get paramRampUpTime => 'Ramp-Up Time';

  @override
  String get paramRampUpTimeDesc =>
      'Laser ramp-up time in pulse mode. Range: 0–1000 ms.';

  @override
  String get paramRefeedDelay => 'Re-Feed Delay';

  @override
  String get paramRefeedDelayDesc =>
      'Delay between retract and re-feed; helps prevent re-sticking. Range: 0–1000 ms.';

  @override
  String get paramRefeedLength => 'Re-Feed Length';

  @override
  String paramRefeedLengthDesc(String min, String max, String unit) {
    return 'Re-feed length to reach the optimal tip position. Range: $min–$max $unit.';
  }

  @override
  String get paramRetractLength => 'Retract Length';

  @override
  String paramRetractLengthDesc(String min, String max, String unit) {
    return 'Wire retract length after welding. Range: $min–$max $unit.';
  }

  @override
  String get paramRetractSpeed => 'Retract Speed';

  @override
  String paramRetractSpeedDesc(String min, String max, String unit) {
    return 'Wire retract speed; helps prevent re-sticking. Range: $min–$max $unit.';
  }

  @override
  String get paramScanFrequency => 'Scan Frequency';

  @override
  String paramScanFrequencyDesc(String min, String max, String unit) {
    return 'Recommended scan frequency: $min–$max $unit.';
  }

  @override
  String get paramScanWidth => 'Scan Width';

  @override
  String paramScanWidthDesc(String min, String max, String unit) {
    return 'Laser scan width. Range: $min–$max $unit.';
  }

  @override
  String get paramSpotWeldDuration => 'Spot Weld Duration';

  @override
  String get paramSpotWeldDurationDesc =>
      'Laser-on duration for each spot weld. Range: 0–10000 ms.';

  @override
  String get paramSpotWeldInterval => 'Spot Weld Interval';

  @override
  String get paramSpotWeldIntervalDesc =>
      'Interval between spot welds in burst mode. Range: 0–10000 ms.';

  @override
  String get paramSpotWeldingDurationCatalog => 'Spot Welding Duration';

  @override
  String get paramSpotWeldingIntervalCatalog => 'Spot Welding Interval';

  @override
  String get paramSwingFrequency => 'Scan Frequency';

  @override
  String get paramSwingFrequencyCatalog => 'Scan Frequency';

  @override
  String get paramSwingWidth => 'Scan Width';

  @override
  String get paramWireFeedSpeed => 'Wire Feed Speed';

  @override
  String paramWireFeedSpeedDesc(String min, String max, String unit) {
    return 'Wire feed speed. Range: $min–$max $unit.';
  }

  @override
  String get paramWireFeedingDelay => 'Wire Feed Delay';

  @override
  String get paramWireFeedingSpeedCatalog => 'Wire Feed Speed';

  @override
  String get paramWireFillingDelay => 'Re-Feed Delay';

  @override
  String get paramWireFillingDelayCatalog => 'Re-Feed Delay';

  @override
  String get paramWireFillingLength => 'Re-Feed Length';

  @override
  String get paramWireFillingLengthCatalog => 'Re-Feed Length';

  @override
  String get passStatus => 'OK';

  @override
  String get pleaseTryAgain => 'Please Try Again';

  @override
  String get pleaseWait => 'Please wait…';

  @override
  String get positioningLightFaultAlarmContent =>
      'The red pointer (aiming beam) has a fault. Check whether the aiming beam is on; if not, contact LaserCyber support.';

  @override
  String get positioningLightFaultAlarmTitle => 'Red Pointer Fault';

  @override
  String get presetLabel => 'Preset';

  @override
  String get processAppliedVerified => 'Process Applied And Verified.';

  @override
  String processApplyFailedGeneric(String error) {
    return 'Apply Failed: $error';
  }

  @override
  String processApplyFailedNamed(String failure) {
    return 'Process Was Not Applied: $failure';
  }

  @override
  String get processApplyFailureBaselineReadFailed => 'Baseline Read Failed';

  @override
  String get processApplyFailureBusy => 'Apply Busy';

  @override
  String get processApplyFailureGeneric => 'Apply Failed';

  @override
  String get processApplyFailurePartialApply => 'Partial Apply';

  @override
  String get processApplyFailureProcessReadbackFailed => 'Readback Mismatch';

  @override
  String get processApplyFailureProcessTypeReadbackMismatch =>
      'Process Type Readback Mismatch';

  @override
  String get processApplyFailureProcessTypeWriteFailed =>
      'Process Type Write Failed';

  @override
  String get processApplyFailureProcessWriteFailed => 'Write Failed';

  @override
  String get processApplyFailureStatusUnavailable => 'Check Equipment Status';

  @override
  String get processApplyFailureUnsafeMachineState => 'Laser Work In Progress';

  @override
  String get processApplyFailureWireFeedingActive => 'Stop Wire Feed First';

  @override
  String get processLibVersion => 'Process Library Version';

  @override
  String get processLibraryNotInstalled =>
      'No compatible quick-mode process library is installed.';

  @override
  String get processLibraryUpdateFailed =>
      'Process library update failed. The last installed library is still in use.';

  @override
  String get processNameFieldLabel => 'Name';

  @override
  String get processNameLabel => 'Process Name';

  @override
  String get processNameMaxLength => 'Name Must Be 32 Characters Or Fewer';

  @override
  String get processParameterName => 'Process Name';

  @override
  String processSaveFailed(String error) {
    return 'Save Failed: $error';
  }

  @override
  String get processTabContinuous => 'Continuous';

  @override
  String get processTabCutting => 'Cutting';

  @override
  String get processTabSpot => 'Spot';

  @override
  String get processTabWeldSeam => 'Weld Seam';

  @override
  String get processTabWideArea => 'Wide-Area';

  @override
  String get processTypeCncCutting => 'CNC Cutting';

  @override
  String get processTypeContinuousWelding => 'Continuous Welding';

  @override
  String get processTypeHandCutting => 'Cutting';

  @override
  String get processTypeLabel => 'Process Type';

  @override
  String get processTypeSpotWelding => 'Spot Welding';

  @override
  String get processTypeWeldCleaning => 'Weld Seam Cleaning';

  @override
  String get processTypeWideCleaning => 'Wide-Area Cleaning';

  @override
  String get processVideoAlreadyUploaded => 'Uploaded';

  @override
  String get processVideoBackToVideos => 'Back to Videos';

  @override
  String get processVideoDeleteConfirmMessage =>
      'This removes the video file and its process parameters from this device.';

  @override
  String get processVideoDeleteConfirmTitle => 'Delete Recording?';

  @override
  String get processVideoDetailTitle => 'Video Details';

  @override
  String get processVideoDuration => 'Duration';

  @override
  String get processVideoEmptySubtitle =>
      'Record Work videos from Quick or Engineer mode will appear here.';

  @override
  String get processVideoEmptyTitle => 'No Recordings';

  @override
  String processVideoLoadedCount(int loaded, int total) {
    return '$loaded of $total';
  }

  @override
  String get processVideoMaterial => 'Material';

  @override
  String get processVideoOperations => 'Operations';

  @override
  String get processVideoParametersTitle => 'Parameter Recording';

  @override
  String get processVideoPlaybackFailed => 'Unable to play this recording';

  @override
  String get processVideoRecordingTime => 'Recording Time';

  @override
  String get processVideoRecordingTooShort => 'Recording Too Short — Not Saved';

  @override
  String get processVideoSaveFailed => 'Failed To Save Recording';

  @override
  String get processVideoUpload => 'Upload';

  @override
  String get processVideoUploadConfirmMessage =>
      'Upload this video and its process parameters to the cloud. Make sure the device is online.';

  @override
  String get processVideoUploadConfirmTitle => 'Upload Recording?';

  @override
  String get processVideoUploadDone => 'Upload complete';

  @override
  String get processVideoUploadFailed => 'Upload failed';

  @override
  String get processVideoUploadingCover => 'Uploading Cover…';

  @override
  String processVideoUploadingVideo(int percent) {
    return 'Uploading Video $percent%';
  }

  @override
  String get processVideoWorkMode => 'Process';

  @override
  String get processWheelCncCutting => 'CNC Cutting';

  @override
  String get processWheelContinuousWelding => 'Continuous Welding';

  @override
  String get processWheelHandCutting => 'Cutting';

  @override
  String get processWheelSpotWelding => 'Spot Welding';

  @override
  String get processWheelWeldCleaning => 'Weld Seam Cleaning';

  @override
  String get processWheelWideCleaning => 'Wide-Area Cleaning';

  @override
  String get productDisclaimerContent =>
      'Dear User: Thank you for choosing our handheld laser welding product. Before using this product, we strongly recommend that you read this disclaimer carefully and strictly adhere to all instructions and safety measures provided in the user manual.\n\n1. Safety Warning\nLaser equipment can cause severe damage to the eyes and skin. During operation, please always wear appropriate Personal Protective Equipment (PPE), including but not limited to laser safety goggles and gloves, to ensure your safety.\n\n2. Operating Instructions\nPlease ensure that you fully understand and are able to comply with all operating procedures and safety guidelines in the product manual. Improper use may result in equipment damage or personal injury.\n\n3. Improper Operation\nThe Company shall not be held liable for any injury or loss resulting from the user\'s failure to follow the instructions in the product manual or failure to take appropriate safety measures.\n\n4. Maintenance\nPlease inspect and maintain the product regularly to ensure it is in good working condition. The Company is not responsible for any accidents caused by improper maintenance of the product.\n\n5. Disclaimer of Liability\nWhile the Company provides comprehensive usage instructions and safety measures, it reserves the right to disclaim liability for any injury or damage caused by improper user operation or violations of the manual. We strongly advise users to understand and comply with all relevant safety regulations and operating standards before using this product.\n\n6. Governing Law\nThe interpretation, application, and dispute resolution of this Disclaimer shall be governed by the laws of the jurisdiction where the Company is headquartered.\n\n7. Entire Agreement\nThis Disclaimer constitutes the entire agreement between you and the Company and supersedes any prior oral or written understandings or agreements.';

  @override
  String get productDisclaimerInfo => 'I have read and agree to the above';

  @override
  String get productDisclaimerTitle => 'Product Disclaimer';

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
  String get recordWorkLabel => 'Record Work';

  @override
  String get redLightCurrentAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get redLightCurrentAlarmTitle => 'Red Pointer Current Alarm';

  @override
  String get redLightCurrentText => 'Red Pointer Current';

  @override
  String get redLightLabel => 'Red Pointer';

  @override
  String get redLightText => 'Red Pointer';

  @override
  String get requiredFieldText => 'Required';

  @override
  String get resetComplete => 'Reset Complete';

  @override
  String get resetToDefault => 'Reset To Default';

  @override
  String get engineerActionResetDefaults => 'Reset Defaults';

  @override
  String get retract => 'Retract';

  @override
  String get retryText => 'Retry';

  @override
  String get rgbLedFooter =>
      'Use these controls to test the status LED indicators on this device.';

  @override
  String get rgbLedText => 'LED';

  @override
  String get safetyGroundLockNotConnectedMessage =>
      'Connect the safety clamp before enabling the laser.';

  @override
  String get safetyGroundLockNotConnectedTitle => 'Safety Clamp Disconnected';

  @override
  String get safetyLockLabel => 'Safety Clamp';

  @override
  String get safetyLockText => 'Safety Clamp';

  @override
  String get safetyTipsAgree => 'Agree';

  @override
  String get safetyTipsContent =>
      '1. Keep bystanders, reflective objects, and flammable materials away during welding.\n\n2. Attach the safety clamp securely to the worktable — not to the welding gun holder, nozzle, or wire-feed assembly.\n\n3. Wear proper protective eyewear, a face mask, earplugs, and heat-resistant gloves.\n\n4. During installation and setup, always switch the laser off after use.\n\n5. Ensure the equipment is properly grounded. A break anywhere in the ground circuit can cause injury.\n\n6. Keep filters well ventilated and clear of debris or dirt.';

  @override
  String get safetyTipsInfo => 'I have read the above and the';

  @override
  String get safetyTipsInfoUse => 'Product Disclaimer.';

  @override
  String get safetyTipsTitle => 'Safety Tips';

  @override
  String get saveAsFavorite => 'Save As Favorite';

  @override
  String get engineerActionSaveFavorite => 'Save Favorite';

  @override
  String get selectValidProcessPresetFirst =>
      'Select A Valid Process Preset First';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get saveFailed => 'Save Failed';

  @override
  String get saveSucceeded => 'Saved';

  @override
  String get savedSuccessfully => 'Saved';

  @override
  String get screenBrightnessText => 'Brightness';

  @override
  String get screenDisplayText => 'Display';

  @override
  String get screenOffNever => 'Never';

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
  String get wallpaperSettingText => 'Wallpaper';

  @override
  String get wallpaperOptionDefault => 'Default';

  @override
  String get wallpaperApplyRestarts =>
      'Changing wallpaper restarts the application.';

  @override
  String get selectProcessPrompt => 'Select a process to view its parameters.';

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
  String get settingsMayRestartApp =>
      'Some of the settings may restart the application.';

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
  String get sshDebugFooter =>
      'When enabled, you can connect to this device over the network for remote troubleshooting. Turns off after reboot. USB debugging is set separately under USB OTG.';

  @override
  String get sshDebugText => 'SSH Debug';

  @override
  String get storageAvailableLegend => 'Available';

  @override
  String get storageMountSystem => 'System';

  @override
  String get storageMountUserData => 'User Data';

  @override
  String get storageTitle => 'Storage';

  @override
  String storageUsedOfTotal(String used, String total) {
    return '$used of $total used';
  }

  @override
  String get straightTrackTemperatureAlarmContent =>
      'Inspect the collimating lens. If the collimating lens has burn marks, replace it immediately.';

  @override
  String get swingWidthLabel => 'Scan Width';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get systemVersion => 'OS Version';

  @override
  String get tempBoardRefrigerationCommAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get tempBoardRefrigerationCommAlarmTitle =>
      'Temperature Board–Cooling Communication Fault';

  @override
  String get thicknessLabel => 'Thickness';

  @override
  String get thicknessMmLabel => 'Thickness (Mm)';

  @override
  String get timezoneSearchHint => 'Search by name or UTC offset';

  @override
  String get totalLaserOnTime => 'Total Laser-On Time';

  @override
  String get totalWireConsumption => 'Total Wire Used';

  @override
  String get turnOffCncFirst => 'Turn off CNC first.';

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
  String get unitOptionImperial => 'Imperial';

  @override
  String get unitOptionMetric => 'Metric';

  @override
  String get unitPersistedFooter =>
      'Choose Metric (°C, mm) or Imperial (°F, in) for values shown on this device.';

  @override
  String get unitPreferenceUnavailable =>
      'Unit settings are temporarily unavailable.';

  @override
  String get unitSettingText => 'Unit';

  @override
  String get textSizeOptionLarge => 'Large';

  @override
  String get textSizeOptionMedium => 'Medium';

  @override
  String get textSizeOptionSmall => 'Small';

  @override
  String get textSizePersistedFooter =>
      'Choose how large text appears on this device. Display numbers and charts use a milder scale.';

  @override
  String get textSizePreferenceUnavailable =>
      'Text size settings are temporarily unavailable.';

  @override
  String get textSizeSettingText => 'Text Size';

  @override
  String get uploadText => 'Upload';

  @override
  String get usbOtgModeDebug => 'Debug';

  @override
  String get usbOtgModeHost => 'Host';

  @override
  String get usbOtgModeMtp => 'Mtp';

  @override
  String get usbOtgText => 'USB OTG';

  @override
  String get userPresetLabel => 'User';

  @override
  String get videosTitle => 'Videos';

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
  String get watchdogResetEventContent =>
      'The controller restarted after a watchdog reset. If this happens often, contact LaserCyber support.';

  @override
  String get watchdogResetEventTitle => 'Watchdog Reset';

  @override
  String get waterTemperatureUpperLimitAlarmContent =>
      'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';

  @override
  String get waterTemperatureUpperLimitAlarmTitle => 'Water Temperature High';

  @override
  String get weldingProportionText => 'Welding Ratio';

  @override
  String get wifiAddDnsServer => 'Add DNS Server';

  @override
  String get wifiAdvancedSettings => 'IP Settings';

  @override
  String get wifiAdvancedSettingsHide => 'Hide IP Settings';

  @override
  String get wifiApply => 'Apply';

  @override
  String get wifiAssociatingPlaceholder => '(associating…)';

  @override
  String get wifiAutoJoin => 'Auto Join';

  @override
  String get wifiAutomatic => 'Automatic';

  @override
  String get wifiBssid => 'BSSID';

  @override
  String get wifiConfigureDns => 'Configure DNS';

  @override
  String get wifiConfigureIp => 'Configure IP';

  @override
  String get wifiConnectTipBody =>
      'This device is not connected to Wi‑Fi. Connect a network to use cloud features.';

  @override
  String get wifiConnectTipOpenSettings => 'Wi‑Fi Settings';

  @override
  String get wifiConnectTipTitle => 'Connect to Wi‑Fi';

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
  String get wifiDisconnect => 'Disconnect';

  @override
  String get wifiDns => 'DNS';

  @override
  String get wifiDns1 => 'DNS 1';

  @override
  String get wifiDns2 => 'DNS 2';

  @override
  String get wifiDnsServers => 'DNS Servers';

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
  String wifiForgetSsid(String ssid) {
    return 'Forget $ssid';
  }

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
  String get wifiIpv4 => 'IPv4';

  @override
  String get wifiIpv4AddressSection => 'IPv4 Address';

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
  String get wifiManual => 'Manual';

  @override
  String get wifiMaxDnsServers => 'You can add up to 3 DNS servers';

  @override
  String get wifiMyNetworks => 'My Networks';

  @override
  String get wifiNetworkText => 'Wi‑Fi';

  @override
  String get wifiNoNetworksScan => '(no networks — Scan)';

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
  String get wifiPhase => 'Phase';

  @override
  String get wifiRemoveDnsServer => 'Remove';

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
  String get wifiSignal => 'Signal';

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
  String get wireFeederVersion => 'Wire Feeder Version';

  @override
  String get wireFeedingLabel => 'Wire Feeder';

  @override
  String get wireFeedingMachineCommunicationText => 'Feeder Comm';

  @override
  String get wireFeedingText => 'Wire Feeder';

  @override
  String get wirelessNetworkText => 'Wi‑Fi';

  @override
  String get workInfoTitle => 'Work Info';

  @override
  String get workTitle => 'Work Info';

  @override
  String get zeroPointOffsetAlarmContent =>
      'Zero offset is off center. Open Advanced Settings and correct it before continuing precise work.';

  @override
  String get zeroPointOffsetAlarmTitle => 'Zero Offset Alarm';

  @override
  String get bluetoothDiscoverable => 'Discoverable';

  @override
  String get bluetoothMyDevices => 'My Devices';

  @override
  String get bluetoothNoDevicesFound => 'No Devices Found';

  @override
  String get bluetoothNoPairedDevices => 'No Paired Devices';

  @override
  String get bluetoothOtherDevices => 'Other Devices';

  @override
  String get bluetoothPaired => 'Paired';

  @override
  String get bluetoothScan => 'Scan';

  @override
  String get bluetoothScanning => 'Scanning…';

  @override
  String get bluetoothStopScan => 'Stop';

  @override
  String get bluetoothThisDevice => 'This Device';

  @override
  String get cncConnectionGuideNote =>
      'Note: After connecting, further adjustments are made on the CNC.';

  @override
  String get cncConnectionGuideStep1 => '1. Verify the RS485 connection.';

  @override
  String get cncConnectionGuideStep2 =>
      '2. Verify the cutting nozzle sensor cable.';

  @override
  String get cncConnectionGuideStep3 =>
      '3. Confirm that the welding gun and fixture are securely connected.';

  @override
  String get cncConnectionGuideTitle => 'Connection Guide';

  @override
  String get cncModeActiveMessage =>
      'CNC Mode Active\nOperate on the CNC equipment';

  @override
  String get deviceControlUnavailable => 'Device Control Unavailable';

  @override
  String dimensionWithUnit(String label, String unit) {
    return '$label ($unit)';
  }

  @override
  String get exitCncModeConfirmTitle => 'Exit CNC Mode?';

  @override
  String get exitCncModeLabel => 'Exit CNC Mode';

  @override
  String get ipCameraRecordAction => 'Record';

  @override
  String get ipCameraRecordingFailed => 'Recording Failed';

  @override
  String get ipCameraRecordingFinalizing => 'Finalizing…';

  @override
  String get ipCameraRecordingInProgress => 'Recording…';

  @override
  String get ipCameraWaitingForRtsp => 'Waiting For RTSP Stream…';

  @override
  String get materialTypeLabel => 'Material Type';

  @override
  String get moreParametersLabel => 'More Parameters';

  @override
  String get moreStatusLabel => 'More Status';

  @override
  String get noTimeZonesFound => 'No Time Zones Found';

  @override
  String get rampChartLabel => 'Ramp Chart';

  @override
  String get stopText => 'Stop';

  @override
  String get usbOtgDebugOnlyLockedHelp =>
      'This product only supports Debug over USB. The mode cannot be changed.';

  @override
  String get usbOtgModeDebugDescription =>
      'Connect this machine to a computer with a USB cable for remote support and software updates. Keep this mode when a technician needs to work on the device from a PC.';

  @override
  String get usbOtgModeHostDescription =>
      'Plug in a USB keyboard, mouse, or other accessories with a USB adapter. Use this when you need extra input devices on the machine itself.';

  @override
  String get usbOtgModeMtpDescription =>
      'Connect this machine to a computer to copy photos and files back and forth. On the computer it appears as a device named “LWS Storage”.';

  @override
  String get valueNotSet => 'Not Set';
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');
}
