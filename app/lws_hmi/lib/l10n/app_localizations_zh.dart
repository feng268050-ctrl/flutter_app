// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get activeAlarmsTitle => '当前告警';

  @override
  String get adFeedbackCommunicationAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get adFeedbackCommunicationAlarmTitle => 'AD 反馈通讯告警';

  @override
  String adbRemoteDebugEnabled(int port) {
    return '已开启 ADB 远程调试（端口 $port），可使用 adb connect 连接。';
  }

  @override
  String get adbRemoteDebugFailed => '开启 ADB 远程调试失败。';

  @override
  String get advancedSettingAllowWorkAfterCameraAlarm => '摄像头告警后允许作业';

  @override
  String get advancedSettingAllowWorkAfterCameraAlarmHint =>
      '摄像头通讯异常时将无法使用 AI 自动检测功能';

  @override
  String get advancedSettingAllowWorkAfterFeederAlarm => '送丝机告警后允许作业';

  @override
  String get advancedSettingAllowWorkAfterFeederAlarmHint =>
      '送丝机异常时连续焊接模式将无法正常工作，但其他模式可以继续工作。';

  @override
  String get advancedSettingAllowWorkAfterGasAlarm => '保护气告警后允许作业';

  @override
  String get advancedSettingAllowWorkAfterGasAlarmHint =>
      '保护气异常时强制允许出光可能会损坏设备，仅应在确定无影响时打开。';

  @override
  String get advancedSettingAllowWorkAfterLensContamination => '保护镜脏污告警后允许作业';

  @override
  String get advancedSettingAllowWorkAfterLensContaminationHint =>
      '保护镜脏污时强制允许出光可能会损坏设备，仅应在 AI 检测不准时打开。';

  @override
  String get advancedSettingAutoZeroOffsetMessage =>
      '请将焊枪对准安全区域并按住扳机，然后点击自动。自动过程会临时允许出光，扳机触发激光。请等待进度条完成自动零点校正。';

  @override
  String get advancedSettingAutoZeroOffsetTitle => '自动零点校正';

  @override
  String get advancedSettingCollimatingLensTempAlarmThreshold => '聚焦镜温度报警阈值';

  @override
  String get advancedSettingDriverTempAlarmThreshold => '驱动器温度报警阈值';

  @override
  String get advancedSettingEnterCollimatingLensTempAlarmThreshold =>
      '请输入聚焦镜温度报警阈值';

  @override
  String get advancedSettingEnterDriverTempAlarmThreshold => '请输入驱动器温度报警阈值';

  @override
  String get advancedSettingEnterInletGasPressure => '请输入进气气压阈值';

  @override
  String get advancedSettingEnterLaserEndPower => '请输入激光终止功率';

  @override
  String get advancedSettingEnterLaserStartPower => '请输入激光起始功率';

  @override
  String get advancedSettingEnterMinGasPressure => '请输入最低气压阈值';

  @override
  String get advancedSettingEnterMotorTempAlarmThreshold => '请输入电机温度报警阈值';

  @override
  String get advancedSettingEnterProtectiveLensTempAlarmThreshold =>
      '请输入保护镜温度报警阈值';

  @override
  String get advancedSettingEnterScanWidthCorrection => '请输入摆宽校正';

  @override
  String get advancedSettingEnterTempAlarmRecoveryHysteresis => '请输入温度报警恢复差值';

  @override
  String get advancedSettingEnterZeroOffset => '请输入零点校正';

  @override
  String get advancedSettingInletGasPressure => '进气气压阈值';

  @override
  String get advancedSettingKeepLaserOnWhileAlarmed => '告警时保持出光';

  @override
  String get advancedSettingKeepLaserOnWhileAlarmedHint =>
      '开启后，作业过程中出现编码告警时不会自动关光，告警弹窗仍会显示。仅应在明确风险可控时使用。';

  @override
  String get advancedSettingLaserEndPower => '激光终止功率';

  @override
  String get advancedSettingLaserStartPower => '激光起始功率';

  @override
  String get advancedSettingLensContaminationDetection => '镜片污染检测';

  @override
  String get advancedSettingLensContaminationDetectionHint =>
      '作业时通过摄像头与 AI 监测保护镜脏污情况，发现污染时提示处理。仅在检测不准或不可用时关闭。';

  @override
  String get advancedSettingMinGasPressure => '最低气压阈值';

  @override
  String get advancedSettingMotorTempAlarmThreshold => '电机温度报警阈值';

  @override
  String get advancedSettingProtectiveLensTempAlarmThreshold => '保护镜温度报警阈值';

  @override
  String get advancedSettingScale0Celsius => '0℃';

  @override
  String get advancedSettingScale20Celsius => '20℃';

  @override
  String get advancedSettingScale80Celsius => '80℃';

  @override
  String get advancedSettingScale85Celsius => '85℃';

  @override
  String get advancedSettingScanWidthCorrection => '摆宽校正';

  @override
  String get advancedSettingShowBootSelfCheck => '显示开机自检';

  @override
  String get advancedSettingTempAlarmRecoveryHysteresis => '温度报警恢复差值';

  @override
  String get advancedSettingText => '高级设置';

  @override
  String get advancedSettingValueRequired => '值不能为空';

  @override
  String get advancedSettingZeroOffset => '零点校正';

  @override
  String get advancedSettingZeroOffsetAuto => '自动';

  @override
  String get advancedSettingZeroPointOffsetDetection => '零点偏移检测';

  @override
  String get advancedSettingZeroPointOffsetDetectionHint =>
      '通过 AI 判断光斑是否居中，零点偏移时提示校正。若不需要此类告警可关闭。';

  @override
  String get advancedSettings => '高级设置';

  @override
  String get advancedSettingsGroupAiAssistance => 'AI 辅助';

  @override
  String get advancedSettingsGroupDangerousOperations => '危险作业（覆盖保护）';

  @override
  String get advancedSettingsGroupOffsetCorrection => '偏移与校正';

  @override
  String get advancedSettingsGroupPowerThresholds => '功率阈值';

  @override
  String get advancedSettingsGroupTemperatureThresholds => '温度阈值';

  @override
  String get aiDetectionLabel => '检测';

  @override
  String get aiOverlayClsDisabled => '分类：未启用';

  @override
  String get aiOverlayClsMetal => '金属';

  @override
  String get aiOverlayClsOther => '其他';

  @override
  String aiOverlayClsPrefix(String className, double score) {
    return '分类：$className（$score）';
  }

  @override
  String get aiOverlayClsWaiting => '分类：等待中…';

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
    return '最新结果：$result';
  }

  @override
  String get aiOverlayResultWaiting => '最新结果：等待中…';

  @override
  String get aiOverlayStateIdle => '空闲';

  @override
  String get aiOverlayStateLocked => '已锁定';

  @override
  String get aiOverlayStateMonitoring => '监控中';

  @override
  String get aiOverlayStateStainDetect => '污点检测';

  @override
  String get aiVisionAiEngineNotReady => 'AI 引擎未就绪';

  @override
  String get aiVisionChooseBtn => '选择视频';

  @override
  String get aiVisionComingSoon => 'AI视觉 — 即将推出';

  @override
  String get aiVisionDetectBtn => '检测';

  @override
  String get aiVisionInferenceVideoNotReady => '推理视频尚未准备好';

  @override
  String get aiVisionMaterialTypeText => '材料类型';

  @override
  String get aiVisionNavLabel => 'AI视觉';

  @override
  String get aiVisionOfflineInferenceNotAvailable => '当前 AI 库不支持离线推理';

  @override
  String get aiVisionProcessTypeText => '工艺类型';

  @override
  String get aiVisionReinferBtn => '重新检测';

  @override
  String get aiVisionReplaceBtn => '更换';

  @override
  String get aiVisionSelectBtn => '选择';

  @override
  String get aiVisionSelectVideoFirst => '请选择一个视频进行检测';

  @override
  String aiVisionStreamFailureFirstFrameTimeout(int timeoutMs) {
    return '等待首帧超时：$timeoutMs ms';
  }

  @override
  String get aiVisionStreamFailurePlayerTimeout => '播放器连接或取流超时';

  @override
  String aiVisionStreamFailureRtspEvent(String message) {
    return 'RTSP 事件错误：$message';
  }

  @override
  String aiVisionStreamFailureStartCode(int code) {
    return '播放器 start 返回错误码：$code';
  }

  @override
  String get aiVisionStreamFailureSurfaceUnavailable => '视频渲染 Surface 未就绪';

  @override
  String get aiVisionStreamFailureUnknown => '未知原因';

  @override
  String get aiVisionStreamFailureUnsupportedVideo => '视频编码不支持或解码器初始化失败';

  @override
  String get aiVisionTitle => 'AI 视觉';

  @override
  String get aiVisionUploadBtn => '上传';

  @override
  String get aiVisionVideoAnalyzing => '分析中…';

  @override
  String aiVisionVideoExportFailed(String error) {
    return '推理视频导出失败：$error';
  }

  @override
  String get aiVisionVideoExporting => '正在生成结果视频...';

  @override
  String aiVisionVideoInferenceFailed(String error) {
    return '视频分析失败：$error';
  }

  @override
  String aiVisionVideoInferenceProgress(int percent) {
    return '正在分析视频... $percent%';
  }

  @override
  String get aiVisionVideoInferring => '分析中…';

  @override
  String get aiVisionVideoPause => '暂停';

  @override
  String get aiVisionVideoPlay => '播放';

  @override
  String get aiVisionVideoReplay => '重播';

  @override
  String get aiVisionWorkInfoUnavailable => '-';

  @override
  String get aiVisualizedLabel => '可视化';

  @override
  String get alarmFaultClearedContent =>
      '该故障已解除，可继续作业。若频繁出现，请联系 LaserCyber 售后。';

  @override
  String get alarmInfoLaserDevice => '激光设备';

  @override
  String get alarmInfoWeldingGun => '焊枪';

  @override
  String get alarmInfoWireFeeder => '送丝机';

  @override
  String get alarmLogsClearedMessage => '完成';

  @override
  String get alarmLogsClearedTitle => '已清除';

  @override
  String get alarmLogsTitle => '告警日志';

  @override
  String get alarmRebootThenSupportContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get alarmTitle => '告警信息';

  @override
  String get anyMaterialLabel => '任意材料';

  @override
  String get applyToDevice => '应用到设备';

  @override
  String get autoCheckOtaUpdate => '自动检查更新';

  @override
  String autoOtaUpdateDialogMessage(String version) {
    return '新版本 $version 可用，请前往设置下载并安装。';
  }

  @override
  String get autoOtaUpdateDialogTitle => '新版本可用';

  @override
  String get autoWireFeed => '自动送丝';

  @override
  String get blowOnLabel => '吹气';

  @override
  String get blowText => '通气状态';

  @override
  String get blowingAirPressureText => '吹气气压';

  @override
  String get bluetoothAsSpeaker => '作为音箱';

  @override
  String get bluetoothCloseFailedText => '蓝牙关闭失败';

  @override
  String get bluetoothClosedText => '蓝牙已关闭';

  @override
  String get bluetoothNotSupportedText => '本设备不支持蓝牙';

  @override
  String get bluetoothOpenFailedText => '蓝牙开启失败';

  @override
  String get bluetoothOpenedText => '蓝牙已开启';

  @override
  String get bluetoothSettings => '蓝牙设置';

  @override
  String get bluetoothText => '蓝牙';

  @override
  String get bootSelfCheckClose => '关闭';

  @override
  String get bootSelfCheckControllerComm => '控制器通讯状态';

  @override
  String get bootSelfCheckDialogTitle => '开机自检';

  @override
  String get bootSelfCheckDontShowAgain => '以后不再显示';

  @override
  String get bootSelfCheckStatusChecking => '检测中…';

  @override
  String get bootSelfCheckStatusFail => '异常';

  @override
  String get bootSelfCheckStatusPass => '正常';

  @override
  String get bootSelfCheckStatusSkipped => '跳过';

  @override
  String get builtInLabel => '内置';

  @override
  String bundledFirmwareDialogMessage(
      String currentVersion, String newVersion) {
    return '检测到新控制板固件（当前 $currentVersion → $newVersion）。\n请保持设备通电，升级过程中请勿操作。';
  }

  @override
  String get bundledFirmwareDialogTitle => '控制板固件更新';

  @override
  String get bundledFirmwareFailedMessage => '控制板固件升级失败，请稍后重试。';

  @override
  String get bundledFirmwareFailedTitle => '固件升级失败';

  @override
  String bundledFirmwareProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get bundledFirmwareSuccessMessage => '控制板固件已更新完成。';

  @override
  String get bundledFirmwareSuccessTitle => '固件升级成功';

  @override
  String get bundledFirmwareUpgradingMessage => '请保持设备通电，升级过程中请勿操作。';

  @override
  String get bundledFirmwareUpgradingTitle => '正在升级控制板固件';

  @override
  String get callBackHomeTitle => '回到主页';

  @override
  String get cameraCommStatusText => '摄像头通讯状态';

  @override
  String get cameraCommunicationAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get cameraCommunicationAlarmTitle => '摄像头通讯告警';

  @override
  String get cameraStatus => '状态';

  @override
  String get cameraStatusEstablishing => '连接中…';

  @override
  String get cameraStatusFailed => '失败';

  @override
  String get cameraType => '摄像头类型';

  @override
  String get cameraTypeBlueLight => '蓝光';

  @override
  String get cameraTypeRedLight => '红光';

  @override
  String get cameraVersion => '摄像头版本';

  @override
  String get cancelText => '取消';

  @override
  String get cellularNetworkText => '蜂窝网络';

  @override
  String get celsiusUnit => '℃';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get checkingStatus => '检测中…';

  @override
  String get clearAlarmLogs => '清除';

  @override
  String get closeText => '关闭';

  @override
  String get cloudEnvironmentTier => '云环境';

  @override
  String get cloudEnvironmentTierDev => '开发';

  @override
  String get cloudEnvironmentTierProd => '生产';

  @override
  String get cloudEnvironmentTierTest => '测试';

  @override
  String get coldWaterInterlockAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get coldWaterInterlockAlarmTitle => '冷水互锁告警';

  @override
  String get collimatingLensOvertemperatureAlarmTitle => '聚焦镜温度告警';

  @override
  String get collimatorTempLabel => '准直镜';

  @override
  String get collimatorTemperatureText => '聚焦镜温度';

  @override
  String get commonSettings => '通用设置';

  @override
  String get commonSettingsGroupDateTime => '日期与时间';

  @override
  String get commonSettingsGroupDisplaySound => '显示与声音';

  @override
  String get commonSettingsGroupMisc => '其他';

  @override
  String get commonSettingsGroupNetwork => '网络';

  @override
  String get commonSettingsShowSafetyGroundLockAlarm => '显示安全夹告警';

  @override
  String get completeSelectionToPreview => '请完成选择以预览参数。';

  @override
  String get confirmText => '确定';

  @override
  String get connectSafetyClampBeforeLaser => '启用激光前请先连接安全地线夹。';

  @override
  String get connectedText => '已连接';

  @override
  String get controllerTabletCommAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get controllerTabletCommAlarmTitle => '控制板通讯故障';

  @override
  String get copyAsUserProcess => '复制为用户工艺';

  @override
  String get currentAlarmText => '电流报警';

  @override
  String get currentProcessName => '当前工艺名称';

  @override
  String get customHomePage => '自定义首页';

  @override
  String get customHomeReplacementSelected => '已选择';

  @override
  String get customHomeSelectFourCards => '请先选择 4 张卡片';

  @override
  String get customHomeSelectReplaceCard => '请选择替换的卡片';

  @override
  String get customMaterialName => '自定义材料名称';

  @override
  String get cuttingProportionText => '切割占比';

  @override
  String get dateTimeApplyFailed => '无法更新日期/时间';

  @override
  String get dateTimeAutoDateTime => '自动设置日期和时间';

  @override
  String get dateTimeAutoSyncFailed => '网络时间服务不可用';

  @override
  String get dateTimeAutoSyncOff => '自动同步已关闭';

  @override
  String get dateTimeAutoSyncOffline => '网络不可用，等待同步';

  @override
  String get dateTimeAutoSyncOk => '网络时间同步成功';

  @override
  String get dateTimeAutoSyncing => '正在通过网络时间服务同步…';

  @override
  String get dateTimeAutoTimeZone => '自动设置时区';

  @override
  String get dateTimeAutomatic => '自动';

  @override
  String get dateTimeModeAuto => '自动';

  @override
  String get dateTimeModeManual => '手动';

  @override
  String get dateTimeNtpAliyun => '阿里云';

  @override
  String get dateTimeNtpApple => 'Apple';

  @override
  String get dateTimeNtpCloudflare => 'Cloudflare';

  @override
  String get dateTimeNtpCnPool => '中国 NTP Pool';

  @override
  String get dateTimeNtpGoogle => 'Google';

  @override
  String get dateTimeNtpPool => 'NTP Pool';

  @override
  String get dateTimeNtpServer => '时间服务器';

  @override
  String get dateTimeNtpTencent => '腾讯';

  @override
  String get dateTimeNtpWindows => 'Windows';

  @override
  String get dateTimePermissionDenied => '缺少系统级日期时间设置权限';

  @override
  String get dateTimeSearchTimezoneHint => '搜索时区（例如 Asia/Shanghai）';

  @override
  String get dateTimeSelectDate => '选择日期';

  @override
  String get dateTimeSelectTime => '选择时间';

  @override
  String get dateTimeSelectTimeZone => '选择时区';

  @override
  String get dateTimeSetDate => '日期';

  @override
  String get dateTimeSetFailed => '日期或时间设置失败';

  @override
  String get dateTimeSetTime => '时间';

  @override
  String get dateTimeSetTimeZone => '时区';

  @override
  String get dateTimeSettings => '日期和时间';

  @override
  String get dateTimeTimezoneApplyFailed => '无法更新时区';

  @override
  String get dateTimeTimezoneGeoFailed => '无法根据网络位置设置时区';

  @override
  String get dateTimeUse24HourFormat => '使用 24 小时制';

  @override
  String get defaultLabel => '默认';

  @override
  String get deleteText => '删除';

  @override
  String get deviceBindBody => '请使用 LaserCyber App 扫描二维码绑定此设备。';

  @override
  String get deviceBindTitle => '绑定此设备';

  @override
  String get deviceControlAutoWireFeedOff => '送丝已关闭';

  @override
  String get deviceControlAutoWireFeedOn => '自动送丝已开启';

  @override
  String get deviceControlCameraUnavailable => '相机不可用';

  @override
  String get deviceControlContinuousFeedLabel => '连续送丝';

  @override
  String get deviceControlEmergencyStopError => '设备处于急停状态';

  @override
  String get deviceControlEndOfWorkFailed => '结束工作失败 — 请检查控制板连接';

  @override
  String get deviceControlEndOfWorkFirst => '请先结束工作';

  @override
  String get deviceControlFeedHoldHint => '长按 3 秒保持开启';

  @override
  String get deviceControlFeedOngoing => '送丝中…';

  @override
  String get deviceControlFeedPulseSuccess => '送丝+已启动';

  @override
  String get deviceControlFeedStopped => '送丝已停止';

  @override
  String get deviceControlKeySwitchOffError => '钥匙开关未打开';

  @override
  String get deviceControlManualGasOff => '手动吹气已关闭';

  @override
  String get deviceControlManualGasOn => '手动吹气已开启';

  @override
  String get deviceControlOperationFailed => '操作失败';

  @override
  String get deviceControlRetractPulseSuccess => '送丝已启动';

  @override
  String get deviceControlStopFeed => '停止送丝+';

  @override
  String get deviceControlWireUnavailableInMode => '当前模式不可送丝';

  @override
  String get deviceInformation => '设备信息';

  @override
  String get deviceInformationText => '设备信息';

  @override
  String get deviceModel => '设备型号';

  @override
  String get deviceMonitorHomeTitle => '监测';

  @override
  String get deviceMonitorMachineStatusTitle => '机台状态';

  @override
  String get deviceMonitorTitle => '设备监测';

  @override
  String get deviceMonitorWarnInfoTitle => '告警信息';

  @override
  String get deviceMonitorWorkInfoTitle => '工作信息';

  @override
  String get deviceRegisterBody => '无法识别此设备，请使用 LaserCyber App 扫描二维码完成注册。';

  @override
  String get deviceRegisterReconnect => '重新连接';

  @override
  String get deviceRegisterTitle => '注册此设备';

  @override
  String get deviceRemoteLockBody => '此设备已被远程锁定。请联系管理员解锁。';

  @override
  String get deviceRemoteLockTitle => '设备已锁定';

  @override
  String get deviceSettingText => '设备设置';

  @override
  String get deviceSn => '设备 SN';

  @override
  String get diodeShortCircuitAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get diodeShortCircuitAlarmTitle => '二极管短路故障';

  @override
  String get diodeShortCircuitErrorClearedTitle => '二极管短路故障解除';

  @override
  String get doneText => '完成';

  @override
  String get dontShowAgain => '不再显示';

  @override
  String get dontShowAgainThisSession => '本次不再显示';

  @override
  String get driveOvertemperatureAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get driveOvertemperatureAlarmTitle => '驱动温度告警';

  @override
  String get driverBoardOvervoltageTitle => '驱动板过压';

  @override
  String get driverModuleOvertemperatureAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get driverModuleOvertemperatureAlarmTitle => '驱动模块超温告警';

  @override
  String get eStopLabel => '急停';

  @override
  String get editProcess => '编辑工艺';

  @override
  String get editText => '编辑';

  @override
  String get emptyText => '';

  @override
  String get endOfWork => '结束工作';

  @override
  String get engineerModeEntryBody =>
      '工程师模式提供面向熟练用户的高级参数自定义。建议先熟悉设备工作方式，再进行精细调整。';

  @override
  String get engineerModeEntryConfirm => '确认并进入';

  @override
  String get engineerModeEntryTitle => '工程师模式提示';

  @override
  String get environmentTemperatureAlarmContent =>
      '环境温度超出允许范围。请改善车间温控；若读数明显异常，请联系 LaserCyber 售后。';

  @override
  String get environmentTemperatureAlarmTitle => '环境温度告警';

  @override
  String get environmentTemperatureText => '环境温度';

  @override
  String get equipmentStatusBack => '返回';

  @override
  String get equipmentStatusHome => '主页';

  @override
  String get ethernetLink => '链路';

  @override
  String get ethernetManualIp => '手动 IP';

  @override
  String get ethernetPrefix => '前缀长度';

  @override
  String get ethernetText => '以太网';

  @override
  String get fahrenheitUnit => '℉';

  @override
  String get failStatus => '故障';

  @override
  String get favoriteMaterial => '常用材料';

  @override
  String get feed => '送丝';

  @override
  String get fiberDisconnectionAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get fiberDisconnectionAlarmTitle => '光纤断开告警';

  @override
  String get fiberTemperatureUpperLimitAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get fiberTemperatureUpperLimitAlarmTitle => '光纤温度超上限告警';

  @override
  String get fiberTemperatureUpperLimitClearedTitle => '光纤温度超上限解除';

  @override
  String get firmwareVersion => '控制板版本';

  @override
  String get flashErrorAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get flashErrorAlarmTitle => 'FLASH 错误告警';

  @override
  String get flashUnencryptedAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get flashUnencryptedAlarmTitle => 'FLASH 未加密告警';

  @override
  String get focusScaleReference => '焦点刻度参考';

  @override
  String get frontLightPdVoltageText => '前向光PD电压';

  @override
  String get galvanometerMotorOvercurrentAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get galvanometerMotorOvercurrentAlarmTitle => '振镜电机过流告警';

  @override
  String get galvanometerMotorStallAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get galvanometerMotorStallAlarmTitle => '振镜电机堵转告警';

  @override
  String get galvanometerMotorTrajectoryErrorTitle => '振镜电机轨迹异常';

  @override
  String get gasFlowLabel => '气体流量';

  @override
  String get gasPressureLabel => '气压';

  @override
  String get gearLabel => '档位';

  @override
  String get gotItText => '知道了';

  @override
  String get groundClampLabel => '接地夹';

  @override
  String get gunHeadCommunicationAlarmContent =>
      '主机与焊枪通讯失败。请检查枪头线缆与接头；重新连接后若仍报警，请联系 LaserCyber 售后。';

  @override
  String get gunHeadCommunicationAlarmTitle => '枪头通讯告警';

  @override
  String get gunHeadCommunicationText => '枪头通讯状态';

  @override
  String get gunHeadMotorOvertemperatureAlarmContent =>
      '焊枪电机过温。请暂停作业并等待冷却；若再次出现，请联系 LaserCyber 售后。';

  @override
  String get gunHeadMotorOvertemperatureAlarmTitle => '枪头电机过温告警';

  @override
  String get gunHeadSwitchText => '激光枪开关';

  @override
  String get gunSn => '枪头 SN';

  @override
  String get gunSwitchLabel => '焊枪开关';

  @override
  String get hardwareBusErrorAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get hardwareBusErrorAlarmTitle => '硬件总线错误告警';

  @override
  String get holdToEnableLaser => '长按开启激光';

  @override
  String get homeAiVisionLabel => 'AI 视觉';

  @override
  String get homeEngineerModeLabel => '工程师模式';

  @override
  String get homeMonitorLabel => '监控';

  @override
  String get homeQuickModeLabel => '快速模式';

  @override
  String get homeSettingsLabel => '设置';

  @override
  String get httpProxyAuthBasic => 'Basic';

  @override
  String get httpProxyAuthNone => '无';

  @override
  String get httpProxyAuthType => '认证方式';

  @override
  String get httpProxyEnable => '启用代理';

  @override
  String get httpProxyHost => '主机';

  @override
  String get httpProxyHostHint => 'proxy.example.com';

  @override
  String get httpProxyPassword => '密码';

  @override
  String get httpProxyPort => '端口';

  @override
  String get httpProxyPortHint => '8080';

  @override
  String get httpProxySave => '保存';

  @override
  String get httpProxySaveSuccess => '代理设置已保存';

  @override
  String get httpProxySettingsTitle => '代理';

  @override
  String get httpProxyStatusIncomplete => '开启（未完成）';

  @override
  String get httpProxyStatusOff => '关闭';

  @override
  String get httpProxyTestConnection => '测试连接';

  @override
  String get httpProxyTestFailed => '连接失败';

  @override
  String get httpProxyTestNoOrigin => '无可用的 API 源进行测试';

  @override
  String get httpProxyTestSuccess => '连接成功';

  @override
  String get httpProxyTitle => '代理';

  @override
  String get httpProxyUsername => '用户名';

  @override
  String get httpProxyValidationHostRequired => '请输入主机地址';

  @override
  String get httpProxyValidationPortInvalid => '端口必须为 1–65535';

  @override
  String get httpProxyValidationUsernameRequired => 'Basic 认证需要用户名';

  @override
  String get illegalInstructionAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get illegalInstructionAlarmTitle => '非法指令告警';

  @override
  String get inUnit => 'in';

  @override
  String inputDialogTitleWithUnit(String title, String unit) {
    return '$title ($unit)';
  }

  @override
  String get internalHumidityExceedsTheUpperLimitAlarmTitle => '内部湿度超上限告警';

  @override
  String get internalHumidityUpperLimitAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get ipCameraCameraNotConnected => '相机未连接';

  @override
  String get ipCameraDemoRecordHint => '仅演示 — 不会出现在监视器 → 视频列表';

  @override
  String get ipCameraEstablishingVideo => '正在建立视频…';

  @override
  String get ipCameraPreviewFailed => '预览失败';

  @override
  String ipCameraRecordError(String error) {
    return '录制错误：$error';
  }

  @override
  String ipCameraRecordingSaved(String path) {
    return '已保存：$path';
  }

  @override
  String ipCameraStopError(String error) {
    return '停止错误：$error';
  }

  @override
  String get ipCameraText => '摄像头';

  @override
  String get jobRuntime => '作业时长';

  @override
  String get kernelVersion => '内核版本';

  @override
  String get keySwitchLabel => '钥匙开关';

  @override
  String get keyboardApplyConfirmBody =>
      '将保存所选布局并重启 HMI，使软键盘 CyberIME 与实体键盘同时生效。重启后会重新打开本页。';

  @override
  String get keyboardApplyConfirmTitle => '应用键盘布局？';

  @override
  String get keyboardLayoutHelp => '请连接与所选规格匹配的实体键盘。规格不匹配可能导致部分按键输出异常字符。';

  @override
  String get keyboardLongPressAccentHint => '长按可输入重音字符';

  @override
  String get keyboardNotDetected => '未检测到';

  @override
  String get keyboardPhysicalSection => '实体键盘';

  @override
  String get keyboardText => '键盘';

  @override
  String get languageAppliesToUi => '应用于产品界面语言与软键盘。';

  @override
  String get languageOptionChinese => '简体中文';

  @override
  String get languageOptionEnglish => 'English';

  @override
  String get languageOptionTraditionalChinese => '繁體中文';

  @override
  String get languagePreferenceUnavailable => '无法读取语言偏好。';

  @override
  String get languageSettingText => '语言';

  @override
  String get laserCommunicationAlarmContent =>
      '请确认已经按下了 Reset 按钮。若依旧没有恢复，请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get laserCommunicationAlarmTitle => '激光器通讯告警';

  @override
  String get laserCurrentAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get laserCurrentAlarmTitle => '激光器电流告警';

  @override
  String get laserCurrentLabel => '激光电流';

  @override
  String get laserDriverCommunicationAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get laserDriverCommunicationAlarmTitle => '激光器驱动通讯告警';

  @override
  String get laserEmergencyStopAlarmContent => '激光器急停已触发。请松开急停并复位设备后再继续作业。';

  @override
  String get laserEmergencyStopAlarmTitle => '激光器急停告警';

  @override
  String get laserEnable => '激光使能';

  @override
  String get laserEnableBlockAlarmBlocked => '告警阻止激光使能';

  @override
  String get laserEnableBlockBusy => '控制忙';

  @override
  String get laserEnableBlockEmergencyStop => '请先解除急停';

  @override
  String get laserEnableBlockKeySwitchOff => '请打开钥匙开关';

  @override
  String get laserEnableBlockManualGasOn => '请先关闭手动吹气';

  @override
  String get laserEnableBlockStatusUnavailable => '请检查设备状态';

  @override
  String get laserEnableBlockWriteFailed => '激光使能写入失败';

  @override
  String get laserEnableReminderConfirm => '是的 — 我已完成以上安全检查';

  @override
  String get laserEnableReminderFocus => '请将焊枪焦距刻度调至所示数值。';

  @override
  String get laserEnableReminderNozzleClean => '请确认已拆除激光管与铜嘴。';

  @override
  String get laserEnableReminderNozzleCut => '请确认已安装切割铜嘴。';

  @override
  String get laserEnableReminderNozzleWeld => '请确认已安装焊接铜嘴。';

  @override
  String get laserEnableReminderPpe => '请确认已佩戴激光防护装备。';

  @override
  String get laserEnableReminderTitle => '重要提示';

  @override
  String get laserOff => '关闭激光';

  @override
  String get liveMachineStatusTitle => '实时设备状态';

  @override
  String get laserOnLabel => '激光';

  @override
  String get laserOutputEnergyLowerLimitAlarmContent =>
      '激光输出能量过低。请检查保护镜与工艺功率设置。若持续出现，请联系 LaserCyber 售后。';

  @override
  String get laserOutputEnergyLowerLimitAlarmTitle => '激光输出能量低于下限告警';

  @override
  String get laserOutputEnergyLowerLimitClearedTitle => '激光输出能量低于下限解除';

  @override
  String get laserReflectedEnergyUpperLimitAlarmContent =>
      '激光反射能量过高。请停止出光，检查工件角度、装配间隙与工艺参数。若持续出现，请联系 LaserCyber 售后。';

  @override
  String get laserReflectedEnergyUpperLimitAlarmTitle => '激光反射能量超上限告警';

  @override
  String get laserReflectedEnergyUpperLimitClearedTitle => '激光反射能量超上限解除';

  @override
  String get laserText => '激光';

  @override
  String get laserTimeVsLastWeek => '激光时间对比上周';

  @override
  String get laserVersion => '激光器版本';

  @override
  String get ledColorGreen => '绿色';

  @override
  String get ledColorRed => '红色';

  @override
  String get ledColorYellow => '黄色';

  @override
  String get ledModeBlink => '闪烁';

  @override
  String get ledModeSteady => '常亮';

  @override
  String get lensHeavyContaminationAlarmContent => '保护镜严重脏污，需要清洁或更换保护镜片';

  @override
  String get lensHeavyContaminationAlarmTitle => '镜片脏污告警';

  @override
  String get liveVideoFailed => '实时视频不可用';

  @override
  String get loadingText => '加载中...';

  @override
  String get machineBlowContent => '气压';

  @override
  String get machineBlowTitle => '吹气';

  @override
  String get machineLaserCurrentContent => '电流';

  @override
  String get machineLaserCurrentTitle => '激光';

  @override
  String get machinePumpContent => '当前';

  @override
  String get machinePumpTitle => '泵源';

  @override
  String get machineTitle => '机台状态';

  @override
  String get mainControllerTempBoardCommAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get mainControllerTempBoardCommAlarmTitle => '主控板与温控板通讯故障';

  @override
  String get manualGas => '手动吹气';

  @override
  String get materialAluminumAlloy => '铝合金';

  @override
  String get materialBrass => '黄铜';

  @override
  String get materialCarbonSteel => '碳钢';

  @override
  String get materialCustom => '自定义';

  @override
  String get materialGalvanizedSheet => '镀锌板';

  @override
  String get materialLabel => '材料';

  @override
  String get materialStainlessSteel => '不锈钢';

  @override
  String get materialThickness => '材料厚度';

  @override
  String get memoryAccessErrorTitle => '内存访问错误';

  @override
  String get memoryManagementErrorTitle => '内存管理错误';

  @override
  String get mmUnit => 'mm';

  @override
  String get mmiOscillatorMalfunctionAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get mmiOscillatorMalfunctionAlarmTitle => 'MMI 振荡器故障告警';

  @override
  String get modbusCommunicationFault => 'Modbus 通讯故障';

  @override
  String get monitorCleanTimeRatio => '清洗时间占比';

  @override
  String get monitorCutTimeRatio => '切割时间占比';

  @override
  String get monitorLaserOnTime => '激光开启时间';

  @override
  String get monitorLastJob => '上次作业';

  @override
  String get monitorNavLabel => '设备监控';

  @override
  String get monitorWeldTimeRatio => '焊接时间占比';

  @override
  String get monitorWeldingConsumables => '焊接耗材';

  @override
  String get moreFavorites => '更多收藏';

  @override
  String get motorCableOpenAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get motorCableOpenAlarmTitle => '电机连接线开路告警';

  @override
  String get motorDriverTempLabel => '电机驱动';

  @override
  String get motorDriverTemperatureText => '电机驱动板温度';

  @override
  String get motorTempLabel => '电机';

  @override
  String get mouseButtonLeft => '左键';

  @override
  String get mouseButtonRight => '右键';

  @override
  String get mouseNaturalScrolling => '自然滚动';

  @override
  String get mousePointerSize => '指针大小';

  @override
  String get mousePrimaryButton => '主按钮';

  @override
  String get mouseText => '鼠标';

  @override
  String get mouseTrackingSpeed => '跟踪速度';

  @override
  String get narrowPulseProtectionAlarmContent =>
      '已触发窄脉冲保护。请调整工艺参数后重试；若反复出现，请联系 LaserCyber 售后。';

  @override
  String get narrowPulseProtectionAlarmTitle => '窄脉冲保护告警';

  @override
  String get networkSettingText => '网络设置';

  @override
  String get networkSettings => '网络设置';

  @override
  String get newUserProcess => '新建用户工艺';

  @override
  String get noActiveAlarms => '无当前告警';

  @override
  String get noEngineerProcesses => '该类型暂无工程师工艺';

  @override
  String get noMatchingProcess => '无匹配工艺';

  @override
  String get noMoreFavorites => '没有更多收藏';

  @override
  String get noProcesses => '暂无工艺';

  @override
  String get noSignedProcessLibrary => '未安装已签名的工艺库';

  @override
  String get notConnected => '未连接';

  @override
  String get notConnectingText => '未连接';

  @override
  String get notPersistedYet => '尚未持久化';

  @override
  String get offLabel => '关闭';

  @override
  String get okText => 'OK';

  @override
  String get onLabel => '开启';

  @override
  String get otaCheckUnavailable => '当前版本暂不支持软件更新检查。';

  @override
  String get otaUpgradeStatusApk => '正在安装应用';

  @override
  String get otaUpgradeStatusDownloading => '正在下载升级包';

  @override
  String otaUpgradeStatusFirmware(int percent) {
    return '正在升级控制板固件 ($percent%)';
  }

  @override
  String get otaUpgradeStatusPreparing => '正在准备升级';

  @override
  String get otaUpgradeStatusSystem => '升级系统中';

  @override
  String get overTempLabel => '超温';

  @override
  String get paramBackDrawLength => '回抽长度';

  @override
  String get paramBackDrawLengthCatalog => '回抽长度';

  @override
  String get paramBackDrawSpeed => '回抽速度';

  @override
  String get paramBackDrawSpeedCatalog => '回抽速度';

  @override
  String get paramBlowingDelay => '提前送气';

  @override
  String get paramBlowingDelayCatalog => '吹气延时';

  @override
  String get paramGasOffDelay => '延时关气';

  @override
  String get paramGasOffDelayCatalog => '关气延时';

  @override
  String get paramGasPostFlow => '延时关气';

  @override
  String get paramGasPreFlow => '提前送气';

  @override
  String get paramLaserDutyCycle => '激光占空比';

  @override
  String get paramLaserFrequency => '激光频率';

  @override
  String get paramLaserOffDelay => '关光延时';

  @override
  String get paramLaserPower => '激光功率';

  @override
  String get paramLightOffDelay => '关光延时';

  @override
  String get paramLightOffDelayCatalog => '关光延时';

  @override
  String get paramPiercingDuration => '穿孔时长';

  @override
  String get paramPiercingDutyCycle => '穿孔占空比';

  @override
  String get paramPiercingFrequency => '穿孔频率';

  @override
  String get paramPiercingPower => '穿孔功率';

  @override
  String get paramPowerRampDown => '功率下降';

  @override
  String get paramPowerRampUp => '功率爬升';

  @override
  String get paramRampDownTime => '下降时间';

  @override
  String get paramRampUpTime => '爬升时间';

  @override
  String get paramRefeedDelay => '补丝延时';

  @override
  String get paramRefeedLength => '补丝长度';

  @override
  String get paramRetractLength => '回抽长度';

  @override
  String get paramRetractSpeed => '回抽速度';

  @override
  String get paramScanFrequency => '扫描频率';

  @override
  String get paramScanWidth => '扫描宽度';

  @override
  String get paramSpotWeldDuration => '点焊时长';

  @override
  String get paramSpotWeldInterval => '点焊间隔';

  @override
  String get paramSpotWeldingDurationCatalog => '点焊时长';

  @override
  String get paramSpotWeldingIntervalCatalog => '点焊间隔';

  @override
  String get paramSwingFrequency => '扫描频率';

  @override
  String get paramSwingFrequencyCatalog => '摆动频率';

  @override
  String get paramSwingWidth => '摆动宽度';

  @override
  String get paramWireFeedSpeed => '送丝速度';

  @override
  String get paramWireFeedingDelay => '送丝延时';

  @override
  String get paramWireFeedingSpeedCatalog => '送丝速度';

  @override
  String get paramWireFillingDelay => '补丝延时';

  @override
  String get paramWireFillingDelayCatalog => '补丝延时';

  @override
  String get paramWireFillingLength => '补丝长度';

  @override
  String get paramWireFillingLengthCatalog => '补丝长度';

  @override
  String get passStatus => '正常';

  @override
  String get pleaseTryAgain => '请重试';

  @override
  String get pleaseWait => '请稍候…';

  @override
  String get positioningLightFaultAlarmContent =>
      '红光（定位光）故障。请检查指示光是否正常；若不亮，请联系 LaserCyber 售后。';

  @override
  String get positioningLightFaultAlarmTitle => '定位光故障告警';

  @override
  String get presetLabel => '预设';

  @override
  String get processAppliedVerified => '工艺已应用并校验。';

  @override
  String processApplyFailedGeneric(String error) {
    return '应用失败：$error';
  }

  @override
  String processApplyFailedNamed(String failure) {
    return '工艺未应用：$failure';
  }

  @override
  String get processApplyFailureBaselineReadFailed => '基准读取失败';

  @override
  String get processApplyFailureBusy => '应用忙';

  @override
  String get processApplyFailureGeneric => '应用失败';

  @override
  String get processApplyFailurePartialApply => '部分应用成功';

  @override
  String get processApplyFailureProcessReadbackFailed => '回读不匹配';

  @override
  String get processApplyFailureProcessTypeReadbackMismatch => '工艺类型回读不匹配';

  @override
  String get processApplyFailureProcessTypeWriteFailed => '工艺类型写入失败';

  @override
  String get processApplyFailureProcessWriteFailed => '写入失败';

  @override
  String get processApplyFailureStatusUnavailable => '请检查设备状态';

  @override
  String get processApplyFailureUnsafeMachineState => '激光作业进行中';

  @override
  String get processApplyFailureWireFeedingActive => '请先停止送丝';

  @override
  String get processLibVersion => '工艺库版本';

  @override
  String get processLibraryNotInstalled => '未安装兼容的快速模式工艺库。';

  @override
  String get processLibraryUpdateFailed => '工艺库更新失败。仍在使用上次安装的工艺库。';

  @override
  String get processNameFieldLabel => '名称';

  @override
  String get processNameLabel => '工艺名称';

  @override
  String get processNameMaxLength => '名称不能超过 32 个字符';

  @override
  String get processParameterName => '工艺参数名称';

  @override
  String processSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get processTabContinuous => '连续';

  @override
  String get processTabCutting => '切割';

  @override
  String get processTabSpot => '点焊';

  @override
  String get processTabWeldSeam => '焊缝';

  @override
  String get processTabWideArea => '超宽';

  @override
  String get processTypeCncCutting => 'CNC 切割';

  @override
  String get processTypeContinuousWelding => '连续焊';

  @override
  String get processTypeHandCutting => '切割';

  @override
  String get processTypeLabel => '工艺类型';

  @override
  String get processTypeSpotWelding => '点焊';

  @override
  String get processTypeWeldCleaning => '焊缝清洗';

  @override
  String get processTypeWideCleaning => '超宽清洗';

  @override
  String get processVideoAlreadyUploaded => '已上传';

  @override
  String get processVideoBackToVideos => '返回视频列表';

  @override
  String get processVideoDeleteConfirmMessage => '将从本机删除视频文件及其工艺参数记录。';

  @override
  String get processVideoDeleteConfirmTitle => '删除录像？';

  @override
  String get processVideoDetailTitle => '视频详情';

  @override
  String get processVideoDuration => '时长';

  @override
  String get processVideoEmptySubtitle => '快速模式或工程师模式中的「录制工作」视频将显示在此处。';

  @override
  String get processVideoEmptyTitle => '暂无录像';

  @override
  String processVideoLoadedCount(int loaded, int total) {
    return '$loaded / $total';
  }

  @override
  String get processVideoMaterial => '材料';

  @override
  String get processVideoOperations => '操作';

  @override
  String get processVideoParametersTitle => '参数记录';

  @override
  String get processVideoPlaybackFailed => '无法播放该录像';

  @override
  String get processVideoRecordingTime => '录制时间';

  @override
  String get processVideoRecordingTooShort => '录像过短，未保存';

  @override
  String get processVideoSaveFailed => '录像保存失败';

  @override
  String get processVideoUpload => '上传';

  @override
  String get processVideoUploadConfirmMessage => '将把该视频及其工艺参数上传到云端。请确保设备已联网。';

  @override
  String get processVideoUploadConfirmTitle => '上传录像？';

  @override
  String get processVideoUploadDone => '上传完成';

  @override
  String get processVideoUploadFailed => '上传失败';

  @override
  String get processVideoUploadingCover => '正在上传封面…';

  @override
  String processVideoUploadingVideo(int percent) {
    return '正在上传视频 $percent%';
  }

  @override
  String get processVideoWorkMode => '工作模式';

  @override
  String get processWheelCncCutting => 'CNC 切割';

  @override
  String get processWheelContinuousWelding => '连续焊';

  @override
  String get processWheelHandCutting => '切割';

  @override
  String get processWheelSpotWelding => '点焊';

  @override
  String get processWheelWeldCleaning => '焊缝清洗';

  @override
  String get processWheelWideCleaning => '大面积清洗';

  @override
  String get productDisclaimerContent =>
      '尊敬的用户：感谢您选择我们的手持激光焊接产品。在使用本产品前，我们强烈建议您仔细阅读本免责声明，并严格遵守用户手册中的所有说明和安全措施。\n\n1. 安全警告\n激光设备可能对眼睛和皮肤造成严重伤害。在操作过程中，请始终佩戴适当的个人防护装备（PPE），包括但不限于激光防护眼镜和手套，以确保您的安全。\n\n2. 操作说明\n请确保您已充分理解并能够遵守产品手册中的所有操作流程和安全指南。使用不当可能导致设备损坏或人身伤害。\n\n3. 不当操作\n对于用户未遵循产品手册中的说明或未采取适当安全措施而导致的任何伤害或损失，本公司概不负责。\n\n4. 维护\n请定期检查并维护产品，以确保其处于良好工作状态。由于产品维护不当造成的任何事故，本公司不承担责任。\n\n5. 责任免责声明\n虽然本公司提供了全面的使用说明和安全措施，但对于因用户操作不当或违反手册规定而造成的任何伤害或损坏，本公司保留免责权利。我们强烈建议用户在使用本产品前，充分了解并遵守所有相关安全法规和操作标准。\n\n6. 适用法律\n本免责声明的解释、适用和争议解决，应受本公司总部所在地法律管辖。\n\n7. 完整协议\n本免责声明构成您与本公司之间的完整协议，并取代此前任何口头或书面理解或协议。';

  @override
  String get productDisclaimerInfo => '我已阅读并同意以上内容';

  @override
  String get productDisclaimerTitle => '产品免责声明';

  @override
  String get protectiveLensOvertemperatureAlarmContent => '如果保护镜出现明显烧痕，请立即更换。';

  @override
  String get protectiveLensOvertemperatureAlarmTitle => '保护镜温度告警';

  @override
  String get protectiveMirrorTempLabel => '保护镜';

  @override
  String get protectiveMirrorTemperatureText => '保护镜温度';

  @override
  String get pumpBoardTemperatureText => '泵源板温度';

  @override
  String get pumpCurrentText => '泵源电流';

  @override
  String get pumpModuleOvertemperatureAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get pumpModuleOvertemperatureAlarmTitle => '泵浦模块超温告警';

  @override
  String get pumpModuleOvertemperatureClearedTitle => '泵浦模块超温解除';

  @override
  String get pumpSourceTemperatureAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get pumpSourceTemperatureAlarmTitle => '泵源温度告警';

  @override
  String get pumpSourceVoltageAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get pumpSourceVoltageAlarmTitle => '泵源电压告警';

  @override
  String get pumpStatusText => '泵源通讯状态';

  @override
  String get pumpTemperatureText => '泵源温度';

  @override
  String get quiescentCurrentAbnormalAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get quiescentCurrentAbnormalAlarmTitle => '静态电流异常告警';

  @override
  String get recordWorkLabel => '录制工作';

  @override
  String get redLightCurrentAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get redLightCurrentAlarmTitle => '红光电流告警';

  @override
  String get redLightCurrentText => '红光电流';

  @override
  String get redLightLabel => '红光';

  @override
  String get redLightText => '红光';

  @override
  String get requiredFieldText => '必填';

  @override
  String get resetComplete => '已重置';

  @override
  String get resetToDefault => '恢复默认';

  @override
  String get retract => '回抽';

  @override
  String get retryText => '重试';

  @override
  String get rgbLedFooter => '用这些开关测试本机状态指示灯。';

  @override
  String get rgbLedText => 'LED';

  @override
  String get safetyGroundLockNotConnectedMessage => '请连接安全夹后再打开激光。';

  @override
  String get safetyGroundLockNotConnectedTitle => '安全夹未连通';

  @override
  String get safetyLockLabel => '安全锁';

  @override
  String get safetyLockText => '安全夹';

  @override
  String get safetyTipsAgree => '同意';

  @override
  String get safetyTipsContent =>
      '1. 焊接过程中，请确保周围没有其他人员、反光物体或易燃材料。\n\n2. 请确保安全夹牢固夹在焊接工作台上；不要将安全夹夹在焊枪支架、喷嘴、送丝组件等部位。\n\n3. 请佩戴专业防护眼镜、口罩、耳塞以及耐高温手套。\n\n4. 在安装和调试设备时，激光操作结束后务必将激光切换到关闭位置。\n\n5. 请确保设备已正确接地；接地回路任一环节中断都可能造成人身伤害。\n\n6. 请确保过滤装置通风良好，并及时清除异物或污垢。';

  @override
  String get safetyTipsInfo => '我已阅读以上内容和';

  @override
  String get safetyTipsInfoUse => '产品使用免责声明。';

  @override
  String get safetyTipsTitle => '安全操作提示';

  @override
  String get saveAsFavorite => '收藏为常用';

  @override
  String get selectValidProcessPresetFirst => '请先选择有效的工艺预设';

  @override
  String get saveChanges => '保存更改';

  @override
  String get saveFailed => '保存失败';

  @override
  String get saveSucceeded => '保存成功';

  @override
  String get savedSuccessfully => '已保存';

  @override
  String get screenBrightnessText => '屏幕亮度';

  @override
  String get screenDisplayText => '屏幕显示';

  @override
  String get screenOffNever => '永不';

  @override
  String get screenOffOption10Min => '10 分钟';

  @override
  String get screenOffOption30Min => '30 分钟';

  @override
  String get screenOffOption60Min => '60 分钟';

  @override
  String get screenOffTimeText => '息屏时间';

  @override
  String get screenSettings => '显示';

  @override
  String get selectProcessPrompt => '选择工艺以查看参数。';

  @override
  String get sensorAbnormalAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get sensorAbnormalAlarmTitle => '传感器异常告警';

  @override
  String get sensorChannelDeviationAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get sensorChannelDeviationAlarmTitle => '传感器通道偏差告警';

  @override
  String get settingsMayRestartApp => '部分设置可能会重启应用。';

  @override
  String get settingsNavLabel => '设置';

  @override
  String get settingsTabAdvanced => '高级设置';

  @override
  String get settingsTabCommon => '通用设置';

  @override
  String get settingsTabCustomHome => '自定义首页';

  @override
  String get settingsTabDeviceInfo => '设备信息';

  @override
  String get settingsTitle => '设置';

  @override
  String get shieldingGasAlarmCauseBlowPressure => '吹气气压过低';

  @override
  String get shieldingGasAlarmCauseDeviceService => '设备异常，请联系售后服务';

  @override
  String get shieldingGasAlarmCauseInletPressure => '进气气压过低';

  @override
  String get shieldingGasAlarmCausePressureCheck => '气压检测异常';

  @override
  String get shieldingGasAlarmContent =>
      '请检查保护气是否开启、气瓶是否缺气。如确认无误后机器仍报警，请联系售后服务。';

  @override
  String shieldingGasAlarmEngineerCheckMessage(String reason) {
    return '保护气异常：$reason';
  }

  @override
  String shieldingGasAlarmLogMessage(String reason) {
    return 'A001 保护气告警，原因：$reason';
  }

  @override
  String shieldingGasAlarmReasonBullet(String reason) {
    return '· $reason';
  }

  @override
  String get shieldingGasAlarmReasonHeader => '原因：';

  @override
  String get shieldingGasAlarmTitle => '保护气告警';

  @override
  String shieldingGasAlarmWarnLogContent(String summary) {
    return '$summary。如确认无误后机器仍报警，请联系售后服务。';
  }

  @override
  String get showStartupSelfCheck => '显示开机自检';

  @override
  String get showSystemStatusOverlay => '显示系统状态浮层';

  @override
  String get soundEffectCheck => '音效';

  @override
  String get soundEffectOption1 => '音效 1';

  @override
  String get soundEffectOption2 => '音效 2';

  @override
  String get soundEffectOption3 => '音效 3';

  @override
  String get soundSettings => '声音';

  @override
  String get sshDebugFooter =>
      '开启后，可通过网络远程连接本机进行排查。重启后会自动关闭。USB 调试请在 USB OTG 中单独设置。';

  @override
  String get sshDebugText => 'SSH 调试';

  @override
  String get straightTrackTemperatureAlarmContent => '检查聚焦镜。若聚焦镜有明显烧痕，请立即更换。';

  @override
  String get swingWidthLabel => '摆动宽度';

  @override
  String get syncNow => '立即同步';

  @override
  String get systemVersion => '系统版本';

  @override
  String get tempBoardRefrigerationCommAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get tempBoardRefrigerationCommAlarmTitle => '温控板与制冷系统通讯故障';

  @override
  String get thicknessLabel => '厚度';

  @override
  String get thicknessMmLabel => '厚度 (mm)';

  @override
  String get timezoneSearchHint => '按名称或 UTC 偏移搜索';

  @override
  String get totalLaserOnTime => '激光开启总时长';

  @override
  String get totalWireConsumption => '焊丝总消耗';

  @override
  String get turnOffCncFirst => '请先关闭 CNC。';

  @override
  String get unavailable => '不可用';

  @override
  String get undervoltage24vAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get undervoltage24vAlarmTitle => '24V 欠压告警';

  @override
  String get unitImperial => '英制';

  @override
  String get unitMetric => '公制';

  @override
  String get unitOptionImperial => '英制';

  @override
  String get unitOptionMetric => '公制';

  @override
  String get unitPersistedFooter => '选择公制（℃、毫米）或英制（℉、英寸），用于本机显示的数值。';

  @override
  String get unitPreferenceUnavailable => '暂时无法更改单位设置。';

  @override
  String get unitSettingText => '单位';

  @override
  String get uploadText => '上传';

  @override
  String get usbOtgModeDebug => '调试';

  @override
  String get usbOtgModeHost => '主机';

  @override
  String get usbOtgModeMtp => 'MTP';

  @override
  String get usbOtgText => 'USB OTG';

  @override
  String get userPresetLabel => '用户';

  @override
  String get videosTitle => '视频';

  @override
  String get volumeSetFailed => '音量设置失败';

  @override
  String get volumeSettingText => '音量';

  @override
  String get warnInfoLastWork => '上次作业时长';

  @override
  String get warnInfoLightTime => '出光总时长';

  @override
  String get warnInfoLightTimeInfo => '较上周';

  @override
  String get warnInfoWeldingConsumables => '焊丝耗材总计';

  @override
  String get warnInfoWeldingConsumablesInfo => '常用耗材';

  @override
  String get washProportionText => '清洗占比';

  @override
  String get watchdogResetEventContent =>
      '控制器因看门狗复位而重启。若频繁发生，请联系 LaserCyber 售后。';

  @override
  String get watchdogResetEventTitle => '看门狗复位事件';

  @override
  String get waterTemperatureUpperLimitAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get waterTemperatureUpperLimitAlarmTitle => '水温超上限告警';

  @override
  String get weldingProportionText => '焊接占比';

  @override
  String get wifiAddDnsServer => '添加 DNS 服务器';

  @override
  String get wifiAdvancedSettings => 'IP 设置';

  @override
  String get wifiAdvancedSettingsHide => '收起 IP 设置';

  @override
  String get wifiApply => '应用';

  @override
  String get wifiAssociatingPlaceholder => '（连接中…)';

  @override
  String get wifiAutoJoin => '自动加入';

  @override
  String get wifiAutomatic => '自动';

  @override
  String get wifiBssid => 'BSSID';

  @override
  String get wifiConfigureDns => '配置 DNS';

  @override
  String get wifiConfigureIp => '配置 IP';

  @override
  String get wifiConnectTipBody => '当前未连接 Wi‑Fi。连接网络后可使用云端功能。';

  @override
  String get wifiConnectTipOpenSettings => 'Wi‑Fi 设置';

  @override
  String get wifiConnectTipTitle => '连接 Wi‑Fi';

  @override
  String get wifiDetailsTitle => '无线网络详情';

  @override
  String get wifiDialogConnect => '连接';

  @override
  String get wifiDialogHidePassword => '隐藏密码';

  @override
  String get wifiDialogPasswordLabel => '密码';

  @override
  String get wifiDialogShowPassword => '显示密码';

  @override
  String get wifiDialogSsidLabel => '网络名称';

  @override
  String get wifiDisconnect => '断开连接';

  @override
  String get wifiDns => 'DNS';

  @override
  String get wifiDns1 => 'DNS 1';

  @override
  String get wifiDns2 => 'DNS 2';

  @override
  String get wifiDnsServers => 'DNS 服务器';

  @override
  String get wifiEditIpConfig => '编辑 IP 配置';

  @override
  String get wifiEditIpSuccess => 'IP 配置已保存';

  @override
  String get wifiErrorAddNotAllowed => '系统拒绝此请求，请允许本应用添加无线网络建议。';

  @override
  String get wifiErrorDuplicateProfile => '无线网络配置已存在。';

  @override
  String get wifiErrorInternal => '保存无线网络配置时发生系统内部错误。';

  @override
  String get wifiErrorRemoveInvalid => '无效的已保存无线网络配置。';

  @override
  String wifiErrorSaveFailedFormat(int code) {
    return '保存无线网络配置失败（代码 $code）。';
  }

  @override
  String get wifiErrorTooManyProfiles => '本应用保存的无线网络配置过多。';

  @override
  String get wifiForgetConfirmMessage => '是否忘记此网络并断开连接？';

  @override
  String get wifiForgetNetwork => '忘记网络';

  @override
  String get wifiForgetPartialFailed => '忘记网络未完全成功';

  @override
  String wifiForgetSsid(String ssid) {
    return '忘记 $ssid';
  }

  @override
  String get wifiForgetSuccess => '已忘记该网络';

  @override
  String get wifiFrequency => '频段';

  @override
  String get wifiGateway => '网关';

  @override
  String get wifiHiddenNetworkConnect => '连接隐藏网络';

  @override
  String get wifiHiddenNetworkTitle => '连接隐藏网络';

  @override
  String get wifiIpAddress => 'IP 地址';

  @override
  String wifiIpFieldEnterHint(String field) {
    return '请输入 $field';
  }

  @override
  String get wifiIpMode => 'IP 模式';

  @override
  String get wifiIpModeDhcp => 'DHCP';

  @override
  String get wifiIpModeStatic => '静态';

  @override
  String get wifiIpSettings => 'IP 设置';

  @override
  String get wifiIpSettingsHide => '收起 IP 设置';

  @override
  String get wifiIpv4 => 'IPv4';

  @override
  String get wifiIpv4AddressSection => 'IPv4 地址';

  @override
  String wifiJoinSsidFormat(String ssid) {
    return '加入 \"$ssid\"';
  }

  @override
  String get wifiLinkSpeed => '链路速率';

  @override
  String wifiListStandardFormat(String band) {
    return 'WiFi $band';
  }

  @override
  String get wifiMacAddress => 'MAC 地址';

  @override
  String get wifiManual => '手动';

  @override
  String get wifiMaxDnsServers => '最多可添加 3 个 DNS 服务器';

  @override
  String get wifiMyNetworks => '我的网络';

  @override
  String get wifiNetworkText => '无线网络';

  @override
  String get wifiNoNetworksScan => '（无网络 — 扫描）';

  @override
  String get wifiNoOtherNetworks => '未找到网络';

  @override
  String get wifiNoSavedNetworks => '暂无已保存网络';

  @override
  String get wifiNotAvailable => '不可用';

  @override
  String get wifiOpenSystemSettingsHint => '该网络由系统无线网络管理，请打开系统设置完成彻底忽略。';

  @override
  String get wifiOtherNetworks => '其他网络';

  @override
  String get wifiOthersSection => '其他';

  @override
  String get wifiPhase => '阶段';

  @override
  String get wifiRemoveDnsServer => '移除';

  @override
  String get wifiRouter => '路由器';

  @override
  String get wifiScanning => '正在扫描…';

  @override
  String get wifiSecurity => '安全类型';

  @override
  String get wifiSecurityOpen => '开放';

  @override
  String get wifiSecurityWpa2 => 'WPA2';

  @override
  String get wifiSecurityWpa3 => 'WPA3';

  @override
  String get wifiSignal => '信号';

  @override
  String get wifiSignalStrength => '信号强度';

  @override
  String get wifiStaticIpConflict => 'IP 地址与其他网络接口冲突';

  @override
  String get wifiStaticIpGatewaySubnet => '网关必须与 IP 在同一子网';

  @override
  String get wifiStaticIpIncomplete => '请填写所有必填的静态 IP 字段';

  @override
  String get wifiStaticIpInvalid => '静态 IP 配置无效';

  @override
  String get wifiStatusConnected => '已连接';

  @override
  String get wifiStatusConnecting => '正在连接，请稍候…';

  @override
  String get wifiStatusNotConnected => '未连接';

  @override
  String get wifiSubnetMask => '子网掩码';

  @override
  String get wifiToastAddCanceledBySystem => '系统已取消添加无线网络。';

  @override
  String get wifiToastAddedConnecting => '无线网络已添加，正在连接…';

  @override
  String get wifiToastConnectedSuccess => '连接成功。';

  @override
  String get wifiToastConnectionFailed => '连接失败。';

  @override
  String get wifiToastDetailsOnlyWhenConnected => '仅已连接的无线网络可查看详情。';

  @override
  String get wifiToastInvalidBssid => 'BSSID 格式无效。';

  @override
  String get wifiToastNoConnectionDetails => '无已连接无线网络详情。';

  @override
  String get wifiToastPasswordRequired => '密码不能为空。';

  @override
  String get wifiToastProfileExistsConnecting => '无线网络配置已存在，正在尝试连接。';

  @override
  String get wifiToastProfileSavedUseSystem => '配置已保存，请在系统无线网络列表中连接。';

  @override
  String get wifiToastRequiresSystemPrivilege => '需要系统级无线网络权限，请以特权系统应用安装。';

  @override
  String get wifiToastSsidRequired => '网络名称不能为空。';

  @override
  String get wifiToastWifiDisabled => '无线网络未开启';

  @override
  String get wifiWlanLabel => '无线局域网';

  @override
  String get wireFeederCommunicationAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get wireFeederCommunicationAlarmTitle => '送丝机通讯告警';

  @override
  String get wireFeederCurrentAlarmContent =>
      '请先关机，等待 10 秒后再开机。若仍报警，请联系 LaserCyber 售后。';

  @override
  String get wireFeederCurrentAlarmTitle => '送丝机电流告警';

  @override
  String get wireFeederVersion => '送丝机版本';

  @override
  String get wireFeedingLabel => '送丝';

  @override
  String get wireFeedingMachineCommunicationText => '送丝机通讯状态';

  @override
  String get wireFeedingText => '送丝';

  @override
  String get wirelessNetworkText => '无线网络';

  @override
  String get workInfoTitle => '工作信息';

  @override
  String get workTitle => '工作信息';

  @override
  String get zeroPointOffsetAlarmContent => '零点偏移偏离中心。请前往高级设置及时校正后再进行精密作业。';

  @override
  String get zeroPointOffsetAlarmTitle => '零点偏移告警';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get activeAlarmsTitle => '當前告警';

  @override
  String get adFeedbackCommunicationAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get adFeedbackCommunicationAlarmTitle => 'AD 反饋通訊告警';

  @override
  String adbRemoteDebugEnabled(int port) {
    return '已開啓 ADB 遠程調試（端口 $port），可使用 adb connect 連接。';
  }

  @override
  String get adbRemoteDebugFailed => '開啓 ADB 遠程調試失敗。';

  @override
  String get advancedSettingAllowWorkAfterCameraAlarm => '攝像頭告警後允許作業';

  @override
  String get advancedSettingAllowWorkAfterCameraAlarmHint =>
      '攝像頭通訊異常時將無法使用 AI 自動檢測功能';

  @override
  String get advancedSettingAllowWorkAfterFeederAlarm => '送絲機告警後允許作業';

  @override
  String get advancedSettingAllowWorkAfterFeederAlarmHint =>
      '送絲機異常時連續焊接模式將無法正常工作，但其他模式可以繼續工作。';

  @override
  String get advancedSettingAllowWorkAfterGasAlarm => '保護氣告警後允許作業';

  @override
  String get advancedSettingAllowWorkAfterGasAlarmHint =>
      '保護氣異常時強制允許出光可能會損壞設備，僅應在確定無影響時打開。';

  @override
  String get advancedSettingAllowWorkAfterLensContamination => '保護鏡髒污告警後允許作業';

  @override
  String get advancedSettingAllowWorkAfterLensContaminationHint =>
      '保護鏡髒污時強制允許出光可能會損壞設備，僅應在 AI 檢測不準時打開。';

  @override
  String get advancedSettingAutoZeroOffsetMessage =>
      '請將焊槍對準安全區域並按住扳機，然後點擊自動。自動過程會臨時允許出光，扳機觸發激光。請等待進度條完成自動零點校正。';

  @override
  String get advancedSettingAutoZeroOffsetTitle => '自動零點校正';

  @override
  String get advancedSettingCollimatingLensTempAlarmThreshold => '聚焦鏡溫度報警閾值';

  @override
  String get advancedSettingDriverTempAlarmThreshold => '驅動器溫度報警閾值';

  @override
  String get advancedSettingEnterCollimatingLensTempAlarmThreshold =>
      '請輸入聚焦鏡溫度報警閾值';

  @override
  String get advancedSettingEnterDriverTempAlarmThreshold => '請輸入驅動器溫度報警閾值';

  @override
  String get advancedSettingEnterInletGasPressure => '請輸入進氣氣壓閾值';

  @override
  String get advancedSettingEnterLaserEndPower => '請輸入激光終止功率';

  @override
  String get advancedSettingEnterLaserStartPower => '請輸入激光起始功率';

  @override
  String get advancedSettingEnterMinGasPressure => '請輸入最低氣壓閾值';

  @override
  String get advancedSettingEnterMotorTempAlarmThreshold => '請輸入電機溫度報警閾值';

  @override
  String get advancedSettingEnterProtectiveLensTempAlarmThreshold =>
      '請輸入保護鏡溫度報警閾值';

  @override
  String get advancedSettingEnterScanWidthCorrection => '請輸入擺寬校正';

  @override
  String get advancedSettingEnterTempAlarmRecoveryHysteresis => '請輸入溫度報警恢復差值';

  @override
  String get advancedSettingEnterZeroOffset => '請輸入零點校正';

  @override
  String get advancedSettingInletGasPressure => '進氣氣壓閾值';

  @override
  String get advancedSettingKeepLaserOnWhileAlarmed => '告警時保持出光';

  @override
  String get advancedSettingKeepLaserOnWhileAlarmedHint =>
      '開啓後，作業過程中出現編碼告警時不會自動關光，告警彈窗仍會顯示。僅應在明確風險可控時使用。';

  @override
  String get advancedSettingLaserEndPower => '激光終止功率';

  @override
  String get advancedSettingLensContaminationDetection => '鏡片污染檢測';

  @override
  String get advancedSettingLensContaminationDetectionHint =>
      '作業時通過攝像頭與 AI 監測保護鏡髒污情況，發現污染時提示處理。僅在檢測不準或不可用時關閉。';

  @override
  String get advancedSettingMinGasPressure => '最低氣壓閾值';

  @override
  String get advancedSettingMotorTempAlarmThreshold => '電機溫度報警閾值';

  @override
  String get advancedSettingProtectiveLensTempAlarmThreshold => '保護鏡溫度報警閾值';

  @override
  String get advancedSettingScanWidthCorrection => '擺寬校正';

  @override
  String get advancedSettingShowBootSelfCheck => '顯示開機自檢';

  @override
  String get advancedSettingTempAlarmRecoveryHysteresis => '溫度報警恢復差值';

  @override
  String get advancedSettingText => '高級設置';

  @override
  String get advancedSettingValueRequired => '值不能爲空';

  @override
  String get advancedSettingZeroOffset => '零點校正';

  @override
  String get advancedSettingZeroOffsetAuto => '自動';

  @override
  String get advancedSettingZeroPointOffsetDetection => '零點偏移檢測';

  @override
  String get advancedSettingZeroPointOffsetDetectionHint =>
      '通過 AI 判斷光斑是否居中，零點偏移時提示校正。若不需要此類告警可關閉。';

  @override
  String get advancedSettings => '高級設置';

  @override
  String get advancedSettingsGroupAiAssistance => 'AI 輔助';

  @override
  String get advancedSettingsGroupDangerousOperations => '危險作業（覆蓋保護）';

  @override
  String get advancedSettingsGroupOffsetCorrection => '偏移與校正';

  @override
  String get advancedSettingsGroupPowerThresholds => '功率閾值';

  @override
  String get advancedSettingsGroupTemperatureThresholds => '溫度閾值';

  @override
  String get aiDetectionLabel => '檢測';

  @override
  String get aiOverlayClsDisabled => '分類：未啓用';

  @override
  String get aiOverlayClsMetal => '金屬';

  @override
  String aiOverlayClsPrefix(String className, double score) {
    return '分類：$className（$score）';
  }

  @override
  String get aiOverlayClsWaiting => '分類：等待中…';

  @override
  String aiOverlayResultPrefix(String result) {
    return '最新結果：$result';
  }

  @override
  String get aiOverlayResultWaiting => '最新結果：等待中…';

  @override
  String get aiOverlayStateIdle => '空閒';

  @override
  String get aiOverlayStateLocked => '已鎖定';

  @override
  String get aiOverlayStateMonitoring => '監控中';

  @override
  String get aiOverlayStateStainDetect => '污點檢測';

  @override
  String get aiVisionAiEngineNotReady => 'AI 引擎未就緒';

  @override
  String get aiVisionChooseBtn => '選擇視頻';

  @override
  String get aiVisionComingSoon => 'AI視覺 — 即將推出';

  @override
  String get aiVisionDetectBtn => '檢測';

  @override
  String get aiVisionInferenceVideoNotReady => '推理視頻尚未準備好';

  @override
  String get aiVisionMaterialTypeText => '材料類型';

  @override
  String get aiVisionNavLabel => 'AI視覺';

  @override
  String get aiVisionOfflineInferenceNotAvailable => '當前 AI 庫不支持離線推理';

  @override
  String get aiVisionProcessTypeText => '工藝類型';

  @override
  String get aiVisionReinferBtn => '重新檢測';

  @override
  String get aiVisionReplaceBtn => '更換';

  @override
  String get aiVisionSelectBtn => '選擇';

  @override
  String get aiVisionSelectVideoFirst => '請選擇一個視頻進行檢測';

  @override
  String aiVisionStreamFailureFirstFrameTimeout(int timeoutMs) {
    return '等待首幀超時：$timeoutMs ms';
  }

  @override
  String get aiVisionStreamFailurePlayerTimeout => '播放器連接或取流超時';

  @override
  String aiVisionStreamFailureRtspEvent(String message) {
    return 'RTSP 事件錯誤：$message';
  }

  @override
  String aiVisionStreamFailureStartCode(int code) {
    return '播放器 start 返回錯誤碼：$code';
  }

  @override
  String get aiVisionStreamFailureSurfaceUnavailable => '視頻渲染 Surface 未就緒';

  @override
  String get aiVisionStreamFailureUnsupportedVideo => '視頻編碼不支持或解碼器初始化失敗';

  @override
  String get aiVisionTitle => 'AI 視覺';

  @override
  String get aiVisionUploadBtn => '上傳';

  @override
  String aiVisionVideoExportFailed(String error) {
    return '推理視頻導出失敗：$error';
  }

  @override
  String get aiVisionVideoExporting => '正在生成結果視頻...';

  @override
  String aiVisionVideoInferenceFailed(String error) {
    return '視頻分析失敗：$error';
  }

  @override
  String aiVisionVideoInferenceProgress(int percent) {
    return '正在分析視頻... $percent%';
  }

  @override
  String get aiVisionVideoPause => '暫停';

  @override
  String get aiVisualizedLabel => '可視化';

  @override
  String get alarmFaultClearedContent =>
      '該故障已解除，可繼續作業。若頻繁出現，請聯繫 LaserCyber 售後。';

  @override
  String get alarmInfoLaserDevice => '激光設備';

  @override
  String get alarmInfoWeldingGun => '焊槍';

  @override
  String get alarmInfoWireFeeder => '送絲機';

  @override
  String get alarmLogsTitle => '告警日誌';

  @override
  String get alarmRebootThenSupportContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get applyToDevice => '應用到設備';

  @override
  String get autoCheckOtaUpdate => '自動檢查更新';

  @override
  String autoOtaUpdateDialogMessage(String version) {
    return '新版本 $version 可用，請前往設置下載並安裝。';
  }

  @override
  String get autoWireFeed => '自動送絲';

  @override
  String get blowOnLabel => '吹氣';

  @override
  String get blowText => '通氣狀態';

  @override
  String get blowingAirPressureText => '吹氣氣壓';

  @override
  String get bluetoothAsSpeaker => '作爲音箱';

  @override
  String get bluetoothCloseFailedText => '藍牙關閉失敗';

  @override
  String get bluetoothClosedText => '藍牙已關閉';

  @override
  String get bluetoothNotSupportedText => '本設備不支持藍牙';

  @override
  String get bluetoothOpenFailedText => '藍牙開啓失敗';

  @override
  String get bluetoothOpenedText => '藍牙已開啓';

  @override
  String get bluetoothSettings => '藍牙設置';

  @override
  String get bluetoothText => '藍牙';

  @override
  String get bootSelfCheckClose => '關閉';

  @override
  String get bootSelfCheckControllerComm => '控制器通訊狀態';

  @override
  String get bootSelfCheckDialogTitle => '開機自檢';

  @override
  String get bootSelfCheckDontShowAgain => '以後不再顯示';

  @override
  String get bootSelfCheckStatusChecking => '檢測中…';

  @override
  String get bootSelfCheckStatusFail => '異常';

  @override
  String get bootSelfCheckStatusSkipped => '跳過';

  @override
  String get builtInLabel => '內置';

  @override
  String bundledFirmwareDialogMessage(
      String currentVersion, String newVersion) {
    return '檢測到新控制板固件（當前 $currentVersion → $newVersion）。\n請保持設備通電，升級過程中請勿操作。';
  }

  @override
  String get bundledFirmwareFailedMessage => '控制板固件升級失敗，請稍後重試。';

  @override
  String get bundledFirmwareFailedTitle => '固件升級失敗';

  @override
  String get bundledFirmwareSuccessTitle => '固件升級成功';

  @override
  String get bundledFirmwareUpgradingMessage => '請保持設備通電，升級過程中請勿操作。';

  @override
  String get bundledFirmwareUpgradingTitle => '正在升級控制板固件';

  @override
  String get callBackHomeTitle => '回到主頁';

  @override
  String get cameraCommStatusText => '攝像頭通訊狀態';

  @override
  String get cameraCommunicationAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get cameraCommunicationAlarmTitle => '攝像頭通訊告警';

  @override
  String get cameraStatus => '狀態';

  @override
  String get cameraStatusEstablishing => '連接中…';

  @override
  String get cameraStatusFailed => '失敗';

  @override
  String get cameraType => '攝像頭類型';

  @override
  String get cameraTypeBlueLight => '藍光';

  @override
  String get cameraTypeRedLight => '紅光';

  @override
  String get cameraVersion => '攝像頭版本';

  @override
  String get cellularNetworkText => '蜂窩網絡';

  @override
  String get checkUpdate => '檢查更新';

  @override
  String get checkingStatus => '檢測中…';

  @override
  String get closeText => '關閉';

  @override
  String get cloudEnvironmentTier => '雲環境';

  @override
  String get cloudEnvironmentTierDev => '開發';

  @override
  String get cloudEnvironmentTierProd => '生產';

  @override
  String get cloudEnvironmentTierTest => '測試';

  @override
  String get coldWaterInterlockAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get coldWaterInterlockAlarmTitle => '冷水互鎖告警';

  @override
  String get collimatingLensOvertemperatureAlarmTitle => '聚焦鏡溫度告警';

  @override
  String get collimatorTempLabel => '準直鏡';

  @override
  String get collimatorTemperatureText => '聚焦鏡溫度';

  @override
  String get commonSettings => '通用設置';

  @override
  String get commonSettingsGroupDateTime => '日期與時間';

  @override
  String get commonSettingsGroupDisplaySound => '顯示與聲音';

  @override
  String get commonSettingsGroupNetwork => '網絡';

  @override
  String get commonSettingsShowSafetyGroundLockAlarm => '顯示安全夾告警';

  @override
  String get completeSelectionToPreview => '請完成選擇以預覽參數。';

  @override
  String get confirmText => '確定';

  @override
  String get connectSafetyClampBeforeLaser => '啓用激光前請先連接安全地線夾。';

  @override
  String get connectedText => '已連接';

  @override
  String get controllerTabletCommAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get controllerTabletCommAlarmTitle => '控制板通訊故障';

  @override
  String get copyAsUserProcess => '復製爲用戶工藝';

  @override
  String get currentAlarmText => '電流報警';

  @override
  String get currentProcessName => '當前工藝名稱';

  @override
  String get customHomePage => '自定義首頁';

  @override
  String get customHomeReplacementSelected => '已選擇';

  @override
  String get customHomeSelectFourCards => '請先選擇 4 張卡片';

  @override
  String get customHomeSelectReplaceCard => '請選擇替換的卡片';

  @override
  String get customMaterialName => '自定義材料名稱';

  @override
  String get cuttingProportionText => '切割佔比';

  @override
  String get dateTimeApplyFailed => '無法更新日期/時間';

  @override
  String get dateTimeAutoDateTime => '自動設置日期和時間';

  @override
  String get dateTimeAutoSyncFailed => '網絡時間服務不可用';

  @override
  String get dateTimeAutoSyncOff => '自動同步已關閉';

  @override
  String get dateTimeAutoSyncOffline => '網絡不可用，等待同步';

  @override
  String get dateTimeAutoSyncOk => '網絡時間同步成功';

  @override
  String get dateTimeAutoSyncing => '正在通過網絡時間服務同步…';

  @override
  String get dateTimeAutoTimeZone => '自動設置時區';

  @override
  String get dateTimeAutomatic => '自動';

  @override
  String get dateTimeModeAuto => '自動';

  @override
  String get dateTimeModeManual => '手動';

  @override
  String get dateTimeNtpAliyun => '阿裏雲';

  @override
  String get dateTimeNtpCnPool => '中國 NTP Pool';

  @override
  String get dateTimeNtpServer => '時間服務器';

  @override
  String get dateTimeNtpTencent => '騰訊';

  @override
  String get dateTimePermissionDenied => '缺少系統級日期時間設置權限';

  @override
  String get dateTimeSearchTimezoneHint => '搜索時區（例如 Asia/Shanghai）';

  @override
  String get dateTimeSelectDate => '選擇日期';

  @override
  String get dateTimeSelectTime => '選擇時間';

  @override
  String get dateTimeSelectTimeZone => '選擇時區';

  @override
  String get dateTimeSetFailed => '日期或時間設置失敗';

  @override
  String get dateTimeSetTime => '時間';

  @override
  String get dateTimeSetTimeZone => '時區';

  @override
  String get dateTimeSettings => '日期和時間';

  @override
  String get dateTimeTimezoneApplyFailed => '無法更新時區';

  @override
  String get dateTimeTimezoneGeoFailed => '無法根據網絡位置設置時區';

  @override
  String get dateTimeUse24HourFormat => '使用 24 小時制';

  @override
  String get defaultLabel => '默認';

  @override
  String get deleteText => '刪除';

  @override
  String get deviceBindBody => '請使用 LaserCyber App 掃描二維碼綁定此設備。';

  @override
  String get deviceBindTitle => '綁定此設備';

  @override
  String get deviceControlAutoWireFeedOff => '送絲已關閉';

  @override
  String get deviceControlAutoWireFeedOn => '自動送絲已開啓';

  @override
  String get deviceControlCameraUnavailable => '相機不可用';

  @override
  String get deviceControlContinuousFeedLabel => '連續送絲';

  @override
  String get deviceControlEmergencyStopError => '設備處於急停狀態';

  @override
  String get deviceControlEndOfWorkFailed => '結束工作失敗 — 請檢查控制板連接';

  @override
  String get deviceControlEndOfWorkFirst => '請先結束工作';

  @override
  String get deviceControlFeedHoldHint => '長按 3 秒保持開啓';

  @override
  String get deviceControlFeedOngoing => '送絲中…';

  @override
  String get deviceControlFeedPulseSuccess => '送絲+已啓動';

  @override
  String get deviceControlFeedStopped => '送絲已停止';

  @override
  String get deviceControlKeySwitchOffError => '鑰匙開關未打開';

  @override
  String get deviceControlManualGasOff => '手動吹氣已關閉';

  @override
  String get deviceControlManualGasOn => '手動吹氣已開啓';

  @override
  String get deviceControlOperationFailed => '操作失敗';

  @override
  String get deviceControlRetractPulseSuccess => '送絲已啓動';

  @override
  String get deviceControlStopFeed => '停止送絲+';

  @override
  String get deviceControlWireUnavailableInMode => '當前模式不可送絲';

  @override
  String get deviceInformation => '設備信息';

  @override
  String get deviceInformationText => '設備信息';

  @override
  String get deviceModel => '設備型號';

  @override
  String get deviceMonitorHomeTitle => '監測';

  @override
  String get deviceMonitorMachineStatusTitle => '機臺狀態';

  @override
  String get deviceMonitorTitle => '設備監測';

  @override
  String get deviceRegisterBody => '無法識別此設備，請使用 LaserCyber App 掃描二維碼完成註冊。';

  @override
  String get deviceRegisterReconnect => '重新連接';

  @override
  String get deviceRegisterTitle => '註冊此設備';

  @override
  String get deviceRemoteLockBody => '此設備已被遠程鎖定。請聯繫管理員解鎖。';

  @override
  String get deviceRemoteLockTitle => '設備已鎖定';

  @override
  String get deviceSettingText => '設備設置';

  @override
  String get deviceSn => '設備 SN';

  @override
  String get diodeShortCircuitAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get diodeShortCircuitAlarmTitle => '二極管短路故障';

  @override
  String get diodeShortCircuitErrorClearedTitle => '二極管短路故障解除';

  @override
  String get dontShowAgain => '不再顯示';

  @override
  String get dontShowAgainThisSession => '本次不再顯示';

  @override
  String get driveOvertemperatureAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get driveOvertemperatureAlarmTitle => '驅動溫度告警';

  @override
  String get driverBoardOvervoltageTitle => '驅動板過壓';

  @override
  String get driverModuleOvertemperatureAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get driverModuleOvertemperatureAlarmTitle => '驅動模塊超溫告警';

  @override
  String get editProcess => '編輯工藝';

  @override
  String get editText => '編輯';

  @override
  String get endOfWork => '結束工作';

  @override
  String get engineerModeEntryBody =>
      '工程師模式提供面向熟練用戶的高級參數自定義。建議先熟悉設備工作方式，再進行精細調整。';

  @override
  String get engineerModeEntryConfirm => '確認並進入';

  @override
  String get engineerModeEntryTitle => '工程師模式提示';

  @override
  String get environmentTemperatureAlarmContent =>
      '環境溫度超出允許範圍。請改善車間溫控；若讀數明顯異常，請聯繫 LaserCyber 售後。';

  @override
  String get environmentTemperatureAlarmTitle => '環境溫度告警';

  @override
  String get environmentTemperatureText => '環境溫度';

  @override
  String get equipmentStatusHome => '主頁';

  @override
  String get ethernetLink => '鏈路';

  @override
  String get ethernetManualIp => '手動 IP';

  @override
  String get ethernetPrefix => '前綴長度';

  @override
  String get ethernetText => '以太網';

  @override
  String get feed => '送絲';

  @override
  String get fiberDisconnectionAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get fiberDisconnectionAlarmTitle => '光纖斷開告警';

  @override
  String get fiberTemperatureUpperLimitAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get fiberTemperatureUpperLimitAlarmTitle => '光纖溫度超上限告警';

  @override
  String get fiberTemperatureUpperLimitClearedTitle => '光纖溫度超上限解除';

  @override
  String get flashErrorAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get flashErrorAlarmTitle => 'FLASH 錯誤告警';

  @override
  String get flashUnencryptedAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get focusScaleReference => '焦點刻度參考';

  @override
  String get frontLightPdVoltageText => '前向光PD電壓';

  @override
  String get galvanometerMotorOvercurrentAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get galvanometerMotorOvercurrentAlarmTitle => '振鏡電機過流告警';

  @override
  String get galvanometerMotorStallAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get galvanometerMotorStallAlarmTitle => '振鏡電機堵轉告警';

  @override
  String get galvanometerMotorTrajectoryErrorTitle => '振鏡電機軌跡異常';

  @override
  String get gasFlowLabel => '氣體流量';

  @override
  String get gasPressureLabel => '氣壓';

  @override
  String get gearLabel => '檔位';

  @override
  String get groundClampLabel => '接地夾';

  @override
  String get gunHeadCommunicationAlarmContent =>
      '主機與焊槍通訊失敗。請檢查槍頭線纜與接頭；重新連接後若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get gunHeadCommunicationAlarmTitle => '槍頭通訊告警';

  @override
  String get gunHeadCommunicationText => '槍頭通訊狀態';

  @override
  String get gunHeadMotorOvertemperatureAlarmContent =>
      '焊槍電機過溫。請暫停作業並等待冷卻；若再次出現，請聯繫 LaserCyber 售後。';

  @override
  String get gunHeadMotorOvertemperatureAlarmTitle => '槍頭電機過溫告警';

  @override
  String get gunHeadSwitchText => '激光槍開關';

  @override
  String get gunSn => '槍頭 SN';

  @override
  String get gunSwitchLabel => '焊槍開關';

  @override
  String get hardwareBusErrorAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get hardwareBusErrorAlarmTitle => '硬件總線錯誤告警';

  @override
  String get holdToEnableLaser => '長按開啓激光';

  @override
  String get homeAiVisionLabel => 'AI 視覺';

  @override
  String get homeEngineerModeLabel => '工程師模式';

  @override
  String get homeMonitorLabel => '監控';

  @override
  String get homeSettingsLabel => '設置';

  @override
  String get httpProxyAuthNone => '無';

  @override
  String get httpProxyAuthType => '認證方式';

  @override
  String get httpProxyEnable => '啓用代理';

  @override
  String get httpProxyHost => '主機';

  @override
  String get httpProxyPassword => '密碼';

  @override
  String get httpProxySaveSuccess => '代理設置已保存';

  @override
  String get httpProxyStatusIncomplete => '開啓（未完成）';

  @override
  String get httpProxyStatusOff => '關閉';

  @override
  String get httpProxyTestConnection => '測試連接';

  @override
  String get httpProxyTestFailed => '連接失敗';

  @override
  String get httpProxyTestNoOrigin => '無可用的 API 源進行測試';

  @override
  String get httpProxyTestSuccess => '連接成功';

  @override
  String get httpProxyUsername => '用戶名';

  @override
  String get httpProxyValidationHostRequired => '請輸入主機地址';

  @override
  String get httpProxyValidationPortInvalid => '端口必須爲 1–65535';

  @override
  String get httpProxyValidationUsernameRequired => 'Basic 認證需要用戶名';

  @override
  String get illegalInstructionAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get internalHumidityExceedsTheUpperLimitAlarmTitle => '內部溼度超上限告警';

  @override
  String get internalHumidityUpperLimitAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get ipCameraCameraNotConnected => '相機未連接';

  @override
  String get ipCameraDemoRecordHint => '僅演示 — 不會出現在監視器 → 視頻列表';

  @override
  String get ipCameraEstablishingVideo => '正在建立視頻…';

  @override
  String get ipCameraPreviewFailed => '預覽失敗';

  @override
  String ipCameraRecordError(String error) {
    return '錄製錯誤：$error';
  }

  @override
  String ipCameraStopError(String error) {
    return '停止錯誤：$error';
  }

  @override
  String get ipCameraText => '攝像頭';

  @override
  String get jobRuntime => '作業時長';

  @override
  String get kernelVersion => '內核版本';

  @override
  String get keySwitchLabel => '鑰匙開關';

  @override
  String get keyboardApplyConfirmBody =>
      '將保存所選佈局並重啓 HMI，使軟鍵盤 CyberIME 與實體鍵盤同時生效。重啓後會重新打開本頁。';

  @override
  String get keyboardApplyConfirmTitle => '應用鍵盤佈局？';

  @override
  String get keyboardLayoutHelp => '請連接與所選規格匹配的實體鍵盤。規格不匹配可能導致部分按鍵輸出異常字符。';

  @override
  String get keyboardLongPressAccentHint => '長按可輸入重音字符';

  @override
  String get keyboardNotDetected => '未檢測到';

  @override
  String get keyboardPhysicalSection => '實體鍵盤';

  @override
  String get keyboardText => '鍵盤';

  @override
  String get languageAppliesToUi => '應用於產品界面語言與軟鍵盤。';

  @override
  String get languagePreferenceUnavailable => '無法讀取語言偏好。';

  @override
  String get languageSettingText => '語言';

  @override
  String get laserCommunicationAlarmContent =>
      '請確認已經按下了 Reset 按鈕。若依舊沒有恢復，請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get laserCommunicationAlarmTitle => '激光器通訊告警';

  @override
  String get laserCurrentAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get laserCurrentAlarmTitle => '激光器電流告警';

  @override
  String get laserCurrentLabel => '激光電流';

  @override
  String get laserDriverCommunicationAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get laserDriverCommunicationAlarmTitle => '激光器驅動通訊告警';

  @override
  String get laserEmergencyStopAlarmContent => '激光器急停已觸發。請鬆開急停並復位設備後再繼續作業。';

  @override
  String get laserEnableBlockEmergencyStop => '請先解除急停';

  @override
  String get laserEnableBlockKeySwitchOff => '請打開鑰匙開關';

  @override
  String get laserEnableBlockManualGasOn => '請先關閉手動吹氣';

  @override
  String get laserEnableBlockStatusUnavailable => '請檢查設備狀態';

  @override
  String get laserEnableBlockWriteFailed => '激光使能寫入失敗';

  @override
  String get laserEnableReminderConfirm => '是的 — 我已完成以上安全檢查';

  @override
  String get laserEnableReminderFocus => '請將焊槍焦距刻度調至所示數值。';

  @override
  String get laserEnableReminderNozzleClean => '請確認已拆除激光管與銅嘴。';

  @override
  String get laserEnableReminderNozzleCut => '請確認已安裝切割銅嘴。';

  @override
  String get laserEnableReminderNozzleWeld => '請確認已安裝焊接銅嘴。';

  @override
  String get laserEnableReminderPpe => '請確認已佩戴激光防護裝備。';

  @override
  String get laserOff => '關閉激光';

  @override
  String get liveMachineStatusTitle => '實時設備狀態';

  @override
  String get laserOutputEnergyLowerLimitAlarmContent =>
      '激光輸出能量過低。請檢查保護鏡與工藝功率設置。若持續出現，請聯繫 LaserCyber 售後。';

  @override
  String get laserOutputEnergyLowerLimitAlarmTitle => '激光輸出能量低於下限告警';

  @override
  String get laserOutputEnergyLowerLimitClearedTitle => '激光輸出能量低於下限解除';

  @override
  String get laserReflectedEnergyUpperLimitAlarmContent =>
      '激光反射能量過高。請停止出光，檢查工件角度、裝配間隙與工藝參數。若持續出現，請聯繫 LaserCyber 售後。';

  @override
  String get laserTimeVsLastWeek => '激光時間對比上週';

  @override
  String get ledColorGreen => '綠色';

  @override
  String get ledColorRed => '紅色';

  @override
  String get ledColorYellow => '黃色';

  @override
  String get ledModeBlink => '閃爍';

  @override
  String get lensHeavyContaminationAlarmContent => '保護鏡嚴重髒污，需要清潔或更換保護鏡片';

  @override
  String get lensHeavyContaminationAlarmTitle => '鏡片髒污告警';

  @override
  String get liveVideoFailed => '實時視頻不可用';

  @override
  String get loadingText => '加載中...';

  @override
  String get machineBlowContent => '氣壓';

  @override
  String get machineBlowTitle => '吹氣';

  @override
  String get machineLaserCurrentContent => '電流';

  @override
  String get machinePumpContent => '當前';

  @override
  String get machineTitle => '機臺狀態';

  @override
  String get mainControllerTempBoardCommAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get mainControllerTempBoardCommAlarmTitle => '主控板與溫控板通訊故障';

  @override
  String get manualGas => '手動吹氣';

  @override
  String get materialAluminumAlloy => '鋁合金';

  @override
  String get materialBrass => '黃銅';

  @override
  String get materialCarbonSteel => '碳鋼';

  @override
  String get materialCustom => '自定義';

  @override
  String get materialGalvanizedSheet => '鍍鋅板';

  @override
  String get materialStainlessSteel => '不鏽鋼';

  @override
  String get memoryAccessErrorTitle => '內存訪問錯誤';

  @override
  String get memoryManagementErrorTitle => '內存管理錯誤';

  @override
  String get mmiOscillatorMalfunctionAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get mmiOscillatorMalfunctionAlarmTitle => 'MMI 振盪器故障告警';

  @override
  String get modbusCommunicationFault => 'Modbus 通訊故障';

  @override
  String get monitorCleanTimeRatio => '清洗時間佔比';

  @override
  String get monitorCutTimeRatio => '切割時間佔比';

  @override
  String get monitorLaserOnTime => '激光開啓時間';

  @override
  String get monitorLastJob => '上次作業';

  @override
  String get monitorNavLabel => '設備監控';

  @override
  String get monitorWeldTimeRatio => '焊接時間佔比';

  @override
  String get motorCableOpenAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get motorCableOpenAlarmTitle => '電機連接線開路告警';

  @override
  String get motorDriverTempLabel => '電機驅動';

  @override
  String get motorDriverTemperatureText => '電機驅動板溫度';

  @override
  String get motorTempLabel => '電機';

  @override
  String get mouseButtonLeft => '左鍵';

  @override
  String get mouseButtonRight => '右鍵';

  @override
  String get mouseNaturalScrolling => '自然滾動';

  @override
  String get mousePointerSize => '指針大小';

  @override
  String get mousePrimaryButton => '主按鈕';

  @override
  String get mouseText => '鼠標';

  @override
  String get mouseTrackingSpeed => '跟蹤速度';

  @override
  String get narrowPulseProtectionAlarmContent =>
      '已觸發窄脈衝保護。請調整工藝參數後重試；若反覆出現，請聯繫 LaserCyber 售後。';

  @override
  String get narrowPulseProtectionAlarmTitle => '窄脈衝保護告警';

  @override
  String get networkSettingText => '網絡設置';

  @override
  String get networkSettings => '網絡設置';

  @override
  String get newUserProcess => '新建用戶工藝';

  @override
  String get noActiveAlarms => '無當前告警';

  @override
  String get noEngineerProcesses => '該類型暫無工程師工藝';

  @override
  String get noMatchingProcess => '無匹配工藝';

  @override
  String get noMoreFavorites => '沒有更多收藏';

  @override
  String get noProcesses => '暫無工藝';

  @override
  String get noSignedProcessLibrary => '未安裝已簽名的工藝庫';

  @override
  String get notConnected => '未連接';

  @override
  String get notConnectingText => '未連接';

  @override
  String get offLabel => '關閉';

  @override
  String get onLabel => '開啓';

  @override
  String get otaCheckUnavailable => '當前版本暫不支持軟件更新檢查。';

  @override
  String get otaUpgradeStatusApk => '正在安裝應用';

  @override
  String get otaUpgradeStatusDownloading => '正在下載升級包';

  @override
  String otaUpgradeStatusFirmware(int percent) {
    return '正在升級控制板固件 ($percent%)';
  }

  @override
  String get otaUpgradeStatusPreparing => '正在準備升級';

  @override
  String get otaUpgradeStatusSystem => '升級系統中';

  @override
  String get overTempLabel => '超溫';

  @override
  String get paramBackDrawLength => '回抽長度';

  @override
  String get paramBackDrawLengthCatalog => '回抽長度';

  @override
  String get paramBlowingDelay => '提前送氣';

  @override
  String get paramBlowingDelayCatalog => '吹氣延時';

  @override
  String get paramGasOffDelay => '延時關氣';

  @override
  String get paramGasOffDelayCatalog => '關氣延時';

  @override
  String get paramGasPostFlow => '延時關氣';

  @override
  String get paramGasPreFlow => '提前送氣';

  @override
  String get paramLaserDutyCycle => '激光佔空比';

  @override
  String get paramLaserFrequency => '激光頻率';

  @override
  String get paramLaserOffDelay => '關光延時';

  @override
  String get paramLightOffDelay => '關光延時';

  @override
  String get paramLightOffDelayCatalog => '關光延時';

  @override
  String get paramPiercingDuration => '穿孔時長';

  @override
  String get paramPiercingDutyCycle => '穿孔佔空比';

  @override
  String get paramPiercingFrequency => '穿孔頻率';

  @override
  String get paramRampDownTime => '下降時間';

  @override
  String get paramRampUpTime => '爬升時間';

  @override
  String get paramRefeedDelay => '補絲延時';

  @override
  String get paramRefeedLength => '補絲長度';

  @override
  String get paramRetractLength => '回抽長度';

  @override
  String get paramScanFrequency => '掃描頻率';

  @override
  String get paramScanWidth => '掃描寬度';

  @override
  String get paramSpotWeldDuration => '點焊時長';

  @override
  String get paramSpotWeldInterval => '點焊間隔';

  @override
  String get paramSpotWeldingDurationCatalog => '點焊時長';

  @override
  String get paramSpotWeldingIntervalCatalog => '點焊間隔';

  @override
  String get paramSwingFrequency => '掃描頻率';

  @override
  String get paramSwingFrequencyCatalog => '擺動頻率';

  @override
  String get paramSwingWidth => '擺動寬度';

  @override
  String get paramWireFeedSpeed => '送絲速度';

  @override
  String get paramWireFeedingDelay => '送絲延時';

  @override
  String get paramWireFeedingSpeedCatalog => '送絲速度';

  @override
  String get paramWireFillingDelay => '補絲延時';

  @override
  String get paramWireFillingDelayCatalog => '補絲延時';

  @override
  String get paramWireFillingLength => '補絲長度';

  @override
  String get paramWireFillingLengthCatalog => '補絲長度';

  @override
  String get pleaseTryAgain => '請重試';

  @override
  String get pleaseWait => '請稍候…';

  @override
  String get positioningLightFaultAlarmContent =>
      '紅光（定位光）故障。請檢查指示光是否正常；若不亮，請聯繫 LaserCyber 售後。';

  @override
  String get presetLabel => '預設';

  @override
  String get processAppliedVerified => '工藝已應用並校驗。';

  @override
  String processApplyFailedGeneric(String error) {
    return '應用失敗：$error';
  }

  @override
  String processApplyFailedNamed(String failure) {
    return '工藝未應用：$failure';
  }

  @override
  String get processApplyFailureBaselineReadFailed => '基準讀取失敗';

  @override
  String get processApplyFailureBusy => '應用忙';

  @override
  String get processApplyFailureGeneric => '應用失敗';

  @override
  String get processApplyFailurePartialApply => '部分應用成功';

  @override
  String get processApplyFailureProcessReadbackFailed => '回讀不匹配';

  @override
  String get processApplyFailureProcessTypeReadbackMismatch => '工藝類型回讀不匹配';

  @override
  String get processApplyFailureProcessTypeWriteFailed => '工藝類型寫入失敗';

  @override
  String get processApplyFailureProcessWriteFailed => '寫入失敗';

  @override
  String get processApplyFailureStatusUnavailable => '請檢查設備狀態';

  @override
  String get processApplyFailureUnsafeMachineState => '激光作業進行中';

  @override
  String get processApplyFailureWireFeedingActive => '請先停止送絲';

  @override
  String get processLibVersion => '工藝庫版本';

  @override
  String get processLibraryNotInstalled => '未安裝兼容的快速模式工藝庫。';

  @override
  String get processLibraryUpdateFailed => '工藝庫更新失敗。仍在使用上次安裝的工藝庫。';

  @override
  String get processNameFieldLabel => '名稱';

  @override
  String get processNameLabel => '工藝名稱';

  @override
  String get processNameMaxLength => '名稱不能超過 32 個字符';

  @override
  String get processParameterName => '工藝參數名稱';

  @override
  String processSaveFailed(String error) {
    return '保存失敗：$error';
  }

  @override
  String get processTabContinuous => '連續';

  @override
  String get processTabSpot => '點焊';

  @override
  String get processTabWeldSeam => '焊縫';

  @override
  String get processTabWideArea => '超寬';

  @override
  String get processTypeContinuousWelding => '連續焊';

  @override
  String get processTypeLabel => '工藝類型';

  @override
  String get processTypeSpotWelding => '點焊';

  @override
  String get processTypeWeldCleaning => '焊縫清洗';

  @override
  String get processTypeWideCleaning => '超寬清洗';

  @override
  String get processVideoAlreadyUploaded => '已上傳';

  @override
  String get processVideoBackToVideos => '返回視頻列表';

  @override
  String get processVideoDeleteConfirmMessage => '將從本機刪除視頻文件及其工藝參數記錄。';

  @override
  String get processVideoDeleteConfirmTitle => '刪除錄像？';

  @override
  String get processVideoDetailTitle => '視頻詳情';

  @override
  String get processVideoDuration => '時長';

  @override
  String get processVideoEmptySubtitle => '快速模式或工程師模式中的「錄製工作」視頻將顯示在此處。';

  @override
  String get processVideoEmptyTitle => '暫無錄像';

  @override
  String get processVideoParametersTitle => '參數記錄';

  @override
  String get processVideoPlaybackFailed => '無法播放該錄像';

  @override
  String get processVideoRecordingTime => '錄製時間';

  @override
  String get processVideoRecordingTooShort => '錄像過短，未保存';

  @override
  String get processVideoSaveFailed => '錄像保存失敗';

  @override
  String get processVideoUpload => '上傳';

  @override
  String get processVideoUploadConfirmMessage => '將把該視頻及其工藝參數上傳到雲端。請確保設備已聯網。';

  @override
  String get processVideoUploadConfirmTitle => '上傳錄像？';

  @override
  String get processVideoUploadDone => '上傳完成';

  @override
  String get processVideoUploadFailed => '上傳失敗';

  @override
  String get processVideoUploadingCover => '正在上傳封面…';

  @override
  String processVideoUploadingVideo(int percent) {
    return '正在上傳視頻 $percent%';
  }

  @override
  String get processWheelContinuousWelding => '連續焊';

  @override
  String get processWheelSpotWelding => '點焊';

  @override
  String get processWheelWeldCleaning => '焊縫清洗';

  @override
  String get processWheelWideCleaning => '大面積清洗';

  @override
  String get productDisclaimerContent =>
      '尊敬的用戶：感謝您選擇我們的手持激光焊接產品。在使用本產品前，我們強烈建議您仔細閱讀本免責聲明，並嚴格遵守用戶手冊中的所有說明和安全措施。\n\n1. 安全警告\n激光設備可能對眼睛和皮膚造成嚴重傷害。在操作過程中，請始終佩戴適當的個人防護裝備（PPE），包括但不限於激光防護眼鏡和手套，以確保您的安全。\n\n2. 操作說明\n請確保您已充分理解並能夠遵守產品手冊中的所有操作流程和安全指南。使用不當可能導致設備損壞或人身傷害。\n\n3. 不當操作\n對於用戶未遵循產品手冊中的說明或未採取適當安全措施而導致的任何傷害或損失，本公司概不負責。\n\n4. 維護\n請定期檢查並維護產品，以確保其處於良好工作狀態。由於產品維護不當造成的任何事故，本公司不承擔責任。\n\n5. 責任免責聲明\n雖然本公司提供了全面的使用說明和安全措施，但對於因用戶操作不當或違反手冊規定而造成的任何傷害或損壞，本公司保留免責權利。我們強烈建議用戶在使用本產品前，充分瞭解並遵守所有相關安全法規和操作標準。\n\n6. 適用法律\n本免責聲明的解釋、適用和爭議解決，應受本公司總部所在地法律管轄。\n\n7. 完整協議\n本免責聲明構成您與本公司之間的完整協議，並取代此前任何口頭或書面理解或協議。';

  @override
  String get productDisclaimerInfo => '我已閱讀並同意以上內容';

  @override
  String get productDisclaimerTitle => '產品免責聲明';

  @override
  String get protectiveLensOvertemperatureAlarmContent => '如果保護鏡出現明顯燒痕，請立即更換。';

  @override
  String get protectiveLensOvertemperatureAlarmTitle => '保護鏡溫度告警';

  @override
  String get protectiveMirrorTempLabel => '保護鏡';

  @override
  String get protectiveMirrorTemperatureText => '保護鏡溫度';

  @override
  String get pumpBoardTemperatureText => '泵源板溫度';

  @override
  String get pumpCurrentText => '泵源電流';

  @override
  String get pumpModuleOvertemperatureAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get pumpModuleOvertemperatureAlarmTitle => '泵浦模塊超溫告警';

  @override
  String get pumpModuleOvertemperatureClearedTitle => '泵浦模塊超溫解除';

  @override
  String get pumpSourceTemperatureAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get pumpSourceTemperatureAlarmTitle => '泵源溫度告警';

  @override
  String get pumpSourceVoltageAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get pumpSourceVoltageAlarmTitle => '泵源電壓告警';

  @override
  String get pumpStatusText => '泵源通訊狀態';

  @override
  String get pumpTemperatureText => '泵源溫度';

  @override
  String get quiescentCurrentAbnormalAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get quiescentCurrentAbnormalAlarmTitle => '靜態電流異常告警';

  @override
  String get recordWorkLabel => '錄製工作';

  @override
  String get redLightCurrentAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get redLightCurrentAlarmTitle => '紅光電流告警';

  @override
  String get redLightCurrentText => '紅光電流';

  @override
  String get redLightLabel => '紅光';

  @override
  String get redLightText => '紅光';

  @override
  String get resetToDefault => '恢復默認';

  @override
  String get retryText => '重試';

  @override
  String get rgbLedFooter => '用這些開關測試本機狀態指示燈。';

  @override
  String get safetyGroundLockNotConnectedMessage => '請連接安全夾後再打開激光。';

  @override
  String get safetyGroundLockNotConnectedTitle => '安全夾未連通';

  @override
  String get safetyLockLabel => '安全鎖';

  @override
  String get safetyLockText => '安全夾';

  @override
  String get safetyTipsContent =>
      '1. 焊接過程中，請確保周圍沒有其他人員、反光物體或易燃材料。\n\n2. 請確保安全夾牢固夾在焊接工作臺上；不要將安全夾夾在焊槍支架、噴嘴、送絲組件等部位。\n\n3. 請佩戴專業防護眼鏡、口罩、耳塞以及耐高溫手套。\n\n4. 在安裝和調試設備時，激光操作結束後務必將激光切換到關閉位置。\n\n5. 請確保設備已正確接地；接地迴路任一環節中斷都可能造成人身傷害。\n\n6. 請確保過濾設備通風良好，並及時清除異物或污垢。';

  @override
  String get safetyTipsInfo => '我已閱讀以上內容和';

  @override
  String get safetyTipsInfoUse => '產品使用免責聲明。';

  @override
  String get saveAsFavorite => '收藏爲常用';

  @override
  String get selectValidProcessPresetFirst => '請先選擇有效的工藝預設';

  @override
  String get saveFailed => '保存失敗';

  @override
  String get screenDisplayText => '屏幕顯示';

  @override
  String get screenOffOption10Min => '10 分鐘';

  @override
  String get screenOffOption30Min => '30 分鐘';

  @override
  String get screenOffOption60Min => '60 分鐘';

  @override
  String get screenOffTimeText => '息屏時間';

  @override
  String get screenSettings => '顯示';

  @override
  String get selectProcessPrompt => '選擇工藝以查看參數。';

  @override
  String get sensorAbnormalAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get sensorAbnormalAlarmTitle => '傳感器異常告警';

  @override
  String get sensorChannelDeviationAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get sensorChannelDeviationAlarmTitle => '傳感器通道偏差告警';

  @override
  String get settingsMayRestartApp => '部分設置可能會重啓應用。';

  @override
  String get settingsNavLabel => '設置';

  @override
  String get settingsTabAdvanced => '高級設置';

  @override
  String get settingsTabCommon => '通用設置';

  @override
  String get settingsTabCustomHome => '自定義首頁';

  @override
  String get settingsTabDeviceInfo => '設備信息';

  @override
  String get settingsTitle => '設置';

  @override
  String get shieldingGasAlarmCauseBlowPressure => '吹氣氣壓過低';

  @override
  String get shieldingGasAlarmCauseDeviceService => '設備異常，請聯繫售後服務';

  @override
  String get shieldingGasAlarmCauseInletPressure => '進氣氣壓過低';

  @override
  String get shieldingGasAlarmCausePressureCheck => '氣壓檢測異常';

  @override
  String get shieldingGasAlarmContent =>
      '請檢查保護氣是否開啓、氣瓶是否缺氣。如確認無誤後機器仍報警，請聯繫售後服務。';

  @override
  String shieldingGasAlarmEngineerCheckMessage(String reason) {
    return '保護氣異常：$reason';
  }

  @override
  String shieldingGasAlarmLogMessage(String reason) {
    return 'A001 保護氣告警，原因：$reason';
  }

  @override
  String get shieldingGasAlarmTitle => '保護氣告警';

  @override
  String shieldingGasAlarmWarnLogContent(String summary) {
    return '$summary。如確認無誤後機器仍報警，請聯繫售後服務。';
  }

  @override
  String get showStartupSelfCheck => '顯示開機自檢';

  @override
  String get showSystemStatusOverlay => '顯示系統狀態浮層';

  @override
  String get soundSettings => '聲音';

  @override
  String get sshDebugFooter =>
      '開啓後，可通過網絡遠程連接本機進行排查。重啓後會自動關閉。USB 調試請在 USB OTG 中單獨設置。';

  @override
  String get sshDebugText => 'SSH 調試';

  @override
  String get straightTrackTemperatureAlarmContent => '檢查聚焦鏡。若聚焦鏡有明顯燒痕，請立即更換。';

  @override
  String get swingWidthLabel => '擺動寬度';

  @override
  String get systemVersion => '系統版本';

  @override
  String get tempBoardRefrigerationCommAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get tempBoardRefrigerationCommAlarmTitle => '溫控板與製冷系統通訊故障';

  @override
  String get timezoneSearchHint => '按名稱或 UTC 偏移搜索';

  @override
  String get totalLaserOnTime => '激光開啓總時長';

  @override
  String get totalWireConsumption => '焊絲總消耗';

  @override
  String get turnOffCncFirst => '請先關閉 CNC。';

  @override
  String get undervoltage24vAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get undervoltage24vAlarmTitle => '24V 欠壓告警';

  @override
  String get unitPersistedFooter => '選擇公制（℃、毫米）或英制（℉、英寸），用於本機顯示的數值。';

  @override
  String get unitPreferenceUnavailable => '暫時無法更改單位設置。';

  @override
  String get unitSettingText => '單位';

  @override
  String get uploadText => '上傳';

  @override
  String get usbOtgModeDebug => '調試';

  @override
  String get usbOtgModeHost => '主機';

  @override
  String get userPresetLabel => '用戶';

  @override
  String get videosTitle => '視頻';

  @override
  String get volumeSetFailed => '音量設置失敗';

  @override
  String get warnInfoLastWork => '上次作業時長';

  @override
  String get warnInfoLightTime => '出光總時長';

  @override
  String get warnInfoLightTimeInfo => '較上週';

  @override
  String get warnInfoWeldingConsumables => '焊絲耗材總計';

  @override
  String get washProportionText => '清洗佔比';

  @override
  String get watchdogResetEventContent =>
      '控制器因看門狗復位而重啓。若頻繁發生，請聯繫 LaserCyber 售後。';

  @override
  String get watchdogResetEventTitle => '看門狗復位事件';

  @override
  String get waterTemperatureUpperLimitAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get waterTemperatureUpperLimitAlarmTitle => '水溫超上限告警';

  @override
  String get weldingProportionText => '焊接佔比';

  @override
  String get wifiAddDnsServer => '添加 DNS 服務器';

  @override
  String get wifiAdvancedSettings => 'IP 設置';

  @override
  String get wifiAdvancedSettingsHide => '收起 IP 設置';

  @override
  String get wifiApply => '應用';

  @override
  String get wifiAssociatingPlaceholder => '（連接中…)';

  @override
  String get wifiAutoJoin => '自動加入';

  @override
  String get wifiAutomatic => '自動';

  @override
  String get wifiConnectTipBody => '當前未連接 Wi‑Fi。連接網絡後可使用雲端功能。';

  @override
  String get wifiConnectTipOpenSettings => 'Wi‑Fi 設置';

  @override
  String get wifiConnectTipTitle => '連接 Wi‑Fi';

  @override
  String get wifiDetailsTitle => '無線網絡詳情';

  @override
  String get wifiDialogConnect => '連接';

  @override
  String get wifiDialogHidePassword => '隱藏密碼';

  @override
  String get wifiDialogPasswordLabel => '密碼';

  @override
  String get wifiDialogShowPassword => '顯示密碼';

  @override
  String get wifiDialogSsidLabel => '網絡名稱';

  @override
  String get wifiDisconnect => '斷開連接';

  @override
  String get wifiDnsServers => 'DNS 服務器';

  @override
  String get wifiEditIpConfig => '編輯 IP 配置';

  @override
  String get wifiErrorAddNotAllowed => '系統拒絕此請求，請允許本應用添加無線網絡建議。';

  @override
  String get wifiErrorDuplicateProfile => '無線網絡配置已存在。';

  @override
  String get wifiErrorInternal => '保存無線網絡配置時發生系統內部錯誤。';

  @override
  String get wifiErrorRemoveInvalid => '無效的已保存無線網絡配置。';

  @override
  String wifiErrorSaveFailedFormat(int code) {
    return '保存無線網絡配置失敗（代碼 $code）。';
  }

  @override
  String get wifiErrorTooManyProfiles => '本應用保存的無線網絡配置過多。';

  @override
  String get wifiForgetConfirmMessage => '是否忘記此網絡並斷開連接？';

  @override
  String get wifiForgetNetwork => '忘記網絡';

  @override
  String get wifiForgetPartialFailed => '忘記網絡未完全成功';

  @override
  String wifiForgetSsid(String ssid) {
    return '忘記 $ssid';
  }

  @override
  String get wifiForgetSuccess => '已忘記該網絡';

  @override
  String get wifiFrequency => '頻段';

  @override
  String get wifiGateway => '網關';

  @override
  String get wifiHiddenNetworkConnect => '連接隱藏網絡';

  @override
  String get wifiHiddenNetworkTitle => '連接隱藏網絡';

  @override
  String wifiIpFieldEnterHint(String field) {
    return '請輸入 $field';
  }

  @override
  String get wifiIpModeStatic => '靜態';

  @override
  String get wifiIpSettings => 'IP 設置';

  @override
  String get wifiIpSettingsHide => '收起 IP 設置';

  @override
  String get wifiLinkSpeed => '鏈路速率';

  @override
  String get wifiManual => '手動';

  @override
  String get wifiMaxDnsServers => '最多可添加 3 個 DNS 服務器';

  @override
  String get wifiMyNetworks => '我的網絡';

  @override
  String get wifiNetworkText => '無線網絡';

  @override
  String get wifiNoNetworksScan => '（無網絡 — 掃描）';

  @override
  String get wifiNoOtherNetworks => '未找到網絡';

  @override
  String get wifiNoSavedNetworks => '暫無已保存網絡';

  @override
  String get wifiOpenSystemSettingsHint => '該網絡由系統無線網絡管理，請打開系統設置完成徹底忽略。';

  @override
  String get wifiOtherNetworks => '其他網絡';

  @override
  String get wifiPhase => '階段';

  @override
  String get wifiScanning => '正在掃描…';

  @override
  String get wifiSecurity => '安全類型';

  @override
  String get wifiSecurityOpen => '開放';

  @override
  String get wifiSignal => '信號';

  @override
  String get wifiSignalStrength => '信號強度';

  @override
  String get wifiStaticIpConflict => 'IP 地址與其他網絡接口衝突';

  @override
  String get wifiStaticIpGatewaySubnet => '網關必須與 IP 在同一子網';

  @override
  String get wifiStaticIpIncomplete => '請填寫所有必填的靜態 IP 字段';

  @override
  String get wifiStaticIpInvalid => '靜態 IP 配置無效';

  @override
  String get wifiStatusConnected => '已連接';

  @override
  String get wifiStatusConnecting => '正在連接，請稍候…';

  @override
  String get wifiStatusNotConnected => '未連接';

  @override
  String get wifiSubnetMask => '子網掩碼';

  @override
  String get wifiToastAddCanceledBySystem => '系統已取消添加無線網絡。';

  @override
  String get wifiToastAddedConnecting => '無線網絡已添加，正在連接…';

  @override
  String get wifiToastConnectedSuccess => '連接成功。';

  @override
  String get wifiToastConnectionFailed => '連接失敗。';

  @override
  String get wifiToastDetailsOnlyWhenConnected => '僅已連接的無線網絡可查看詳情。';

  @override
  String get wifiToastInvalidBssid => 'BSSID 格式無效。';

  @override
  String get wifiToastNoConnectionDetails => '無已連接無線網絡詳情。';

  @override
  String get wifiToastPasswordRequired => '密碼不能爲空。';

  @override
  String get wifiToastProfileExistsConnecting => '無線網絡配置已存在，正在嘗試連接。';

  @override
  String get wifiToastProfileSavedUseSystem => '配置已保存，請在系統無線網絡列表中連接。';

  @override
  String get wifiToastRequiresSystemPrivilege => '需要系統級無線網絡權限，請以特權系統應用安裝。';

  @override
  String get wifiToastSsidRequired => '網絡名稱不能爲空。';

  @override
  String get wifiToastWifiDisabled => '無線網絡未開啓';

  @override
  String get wifiWlanLabel => '無線局域網';

  @override
  String get wireFeederCommunicationAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get wireFeederCommunicationAlarmTitle => '送絲機通訊告警';

  @override
  String get wireFeederCurrentAlarmContent =>
      '請先關機，等待 10 秒後再開機。若仍報警，請聯繫 LaserCyber 售後。';

  @override
  String get wireFeederCurrentAlarmTitle => '送絲機電流告警';

  @override
  String get wireFeederVersion => '送絲機版本';

  @override
  String get wireFeedingLabel => '送絲';

  @override
  String get wireFeedingMachineCommunicationText => '送絲機通訊狀態';

  @override
  String get wireFeedingText => '送絲';

  @override
  String get wirelessNetworkText => '無線網絡';

  @override
  String get zeroPointOffsetAlarmContent => '零點偏移偏離中心。請前往高級設置及時校正後再進行精密作業。';

  @override
  String get zeroPointOffsetAlarmTitle => '零點偏移告警';
}
