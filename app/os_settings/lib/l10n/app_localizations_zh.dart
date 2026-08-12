// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get osSettingsText => 'OS 设置';

  @override
  String get storageTitle => '存储空间';

  @override
  String get wifiNetworkText => '无线网络';

  @override
  String get ethernetText => '以太网';

  @override
  String get ethernetLink => '链路';

  @override
  String get ethernetManualIp => '手动 IP';

  @override
  String get ethernetPrefix => '前缀长度';

  @override
  String get bluetoothText => '蓝牙';

  @override
  String get httpProxySettingsTitle => '代理';

  @override
  String get dateTimeSettings => '日期和时间';

  @override
  String get countrySettingText => '国家/地区';

  @override
  String get languageSettingText => '语言';

  @override
  String get unitSettingText => '单位';

  @override
  String get screenSettings => '屏幕设置';

  @override
  String get soundSettings => '声音';

  @override
  String get powerModeSettingText => '效能模式';

  @override
  String get powerModePersistedFooter =>
      '性能模式保持满频与完整动画；均衡模式通过限制时钟并减少装饰动画降低机身发热与负载。';

  @override
  String get keyboardText => '键盘';

  @override
  String get mouseText => '鼠标';

  @override
  String get usbOtgText => 'USB OTG';

  @override
  String get offLabel => '关闭';

  @override
  String get onLabel => '开启';

  @override
  String get notConnected => '未连接';

  @override
  String get unavailable => '不可用';

  @override
  String get cancelText => '取消';

  @override
  String get confirmText => '确定';

  @override
  String get wifiApply => '应用';

  @override
  String get screenBrightnessText => '屏幕亮度';

  @override
  String get screenOffTimeText => '息屏时间';

  @override
  String get screenOffNever => '永不';

  @override
  String get screenOffOption10Min => '10 分钟';

  @override
  String get screenOffOption30Min => '30 分钟';

  @override
  String get screenOffOption60Min => '60 分钟';

  @override
  String get wallpaperSettingText => '壁纸';

  @override
  String get wallpaperOptionDefault => '默认';

  @override
  String get wallpaperApplyRestarts => '更改壁纸将重启应用。';

  @override
  String get storageMountSystem => '系统';

  @override
  String get storageMountUserData => '用户数据';

  @override
  String get storageAvailableLegend => '可用';

  @override
  String storageUsedOfTotal(String used, String total) {
    return '已用 $used，共 $total';
  }

  @override
  String get wifiConfigureIp => '配置 IP';

  @override
  String get wifiIpModeDhcp => 'DHCP';

  @override
  String get wifiManual => '手动';

  @override
  String get wifiIpAddress => 'IP 地址';

  @override
  String get wifiRouter => '路由器';

  @override
  String get wifiDns => 'DNS';

  @override
  String get wifiIpMode => 'IP 模式';

  @override
  String get wifiIpModeStatic => '静态';

  @override
  String get customHomeReplacementSelected => '已选择';

  @override
  String get wifiScanning => '正在扫描…';

  @override
  String get wifiNoSavedNetworks => '暂无已保存网络';

  @override
  String get wifiAutoJoin => '自动加入';

  @override
  String get wifiForgetNetwork => '忘记网络';

  @override
  String get wifiAutomatic => '自动';

  @override
  String get wifiSubnetMask => '子网掩码';

  @override
  String get wifiDnsServers => 'DNS 服务器';

  @override
  String get keyboardSoftLayoutPreview => '软件键盘布局预览';

  @override
  String get keyboardPhysicalSection => '实体键盘';

  @override
  String get keyboardLayoutHelp => '请连接与所选规格匹配的实体键盘。规格不匹配可能导致部分按键输出异常字符。';

  @override
  String get keyboardApplyConfirmTitle => '应用键盘布局？';

  @override
  String get keyboardApplyConfirmBody =>
      '将保存所选布局并重启 HMI，使软键盘 CyberIME 与实体键盘同时生效。重启后会重新打开本页。';

  @override
  String get keyboardLongPressAccentHint => '长按可输入重音字符';

  @override
  String get keyboardNotDetected => '未检测到';

  @override
  String get cameraStatus => '状态';

  @override
  String get dateTimeAutomatic => '自动';

  @override
  String get dateTimeModeManual => '手动';

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
  String get cloudEnvironmentTier => '云环境';

  @override
  String get cloudEnvironmentTierProd => '生产';

  @override
  String get cloudEnvironmentTierTest => '测试';

  @override
  String get cloudEnvironmentFooter =>
      '选择本机连接的云服务环境。日常使用请选「生产」；仅在对接测试云时使用「测试」。对本机所有应用生效。';

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
  String get performanceLabel => '性能';

  @override
  String get balancedLabel => '均衡';

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
  String get uiScaleHelp => 'UI Scale 在 100% 时对应面板的自然尺寸。若界面偏小或偏大，可提高或降低比例。';

  @override
  String get volumeOnlyHelp => '调节本机媒体与系统提示音的音量。';

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
  String get languageSettingHelp => '选择本机菜单与提示使用的语言。';

  @override
  String get regionSettingHelp => '用于无线法规区域，以及默认时区与网络时间服务器。界面语言仍单独设置。';

  @override
  String get unitSettingHelp => '选择公制（℃、毫米）或英制（℉、英寸），用于本机显示的数值。';

  @override
  String get previewLabel => 'Preview';

  @override
  String get wlanLabel => 'Wi-Fi';

  @override
  String get connectingLabel => 'Connecting…';

  @override
  String get secretsSealHelp =>
      'Secrets Seal 显示本机如何保护已保存的机密信息（如 Wi‑Fi 密码和云密钥）。software 表示软件加密；op-tee 表示安全芯片。';

  @override
  String get selinuxHelp =>
      'SELinux 是 Linux 的安全策略层。Disabled 表示关闭；Permissive 表示违规只记录不拦截；Enforcing 表示按策略强制执行。';

  @override
  String get wallpaperSectionHelp => '壁纸用于桌面背景及应用界面。更改后会短暂重启设置，以加载新壁纸。';

  @override
  String get keyboardApplyConfirmOsBody => '将保存键盘布局，并重启设置，以便匹配的实体键盘正常工作。';

  @override
  String get keyboardLayoutHelpOs => '预览显示屏幕键盘布局。点「应用」保存后，设置会重启，以便匹配的实体键盘正常工作。';

  @override
  String get mousePointerHelp => '更改指针大小后，当前使用的应用会短暂重启。';

  @override
  String get wifiConfigureDns => '配置 DNS';

  @override
  String get wifiIpv4AddressSection => 'IPv4 地址';

  @override
  String get wifiGateway => '网关';

  @override
  String get wifiDnsLimit => '最多可添加 3 个 DNS 服务器';

  @override
  String get wifiOthersSection => '其他';

  @override
  String get wifiMacAddress => 'MAC 地址';

  @override
  String get wifiLinkSpeed => '链路速度';

  @override
  String get ethernetCableLink => '网线';

  @override
  String ethernetSpeedMbps(int speed) {
    return '$speed Mbps';
  }
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get osSettingsText => 'OS 設置';

  @override
  String get storageTitle => '存儲空間';

  @override
  String get wifiNetworkText => '無線網絡';

  @override
  String get ethernetText => '以太網';

  @override
  String get ethernetLink => '鏈路';

  @override
  String get ethernetManualIp => '手動 IP';

  @override
  String get ethernetPrefix => '前綴長度';

  @override
  String get bluetoothText => '藍牙';

  @override
  String get dateTimeSettings => '日期和時間';

  @override
  String get countrySettingText => '國家/地區';

  @override
  String get languageSettingText => '語言';

  @override
  String get unitSettingText => '單位';

  @override
  String get screenSettings => '顯示';

  @override
  String get soundSettings => '聲音';

  @override
  String get powerModeSettingText => '效能模式';

  @override
  String get powerModePersistedFooter =>
      '性能模式保持滿頻與完整動畫；均衡模式透過限制時鐘並減少裝飾動畫降低機身發熱與負載。';

  @override
  String get keyboardText => '鍵盤';

  @override
  String get mouseText => '鼠標';

  @override
  String get usbOtgText => 'USB OTG';

  @override
  String get offLabel => '關閉';

  @override
  String get onLabel => '開啓';

  @override
  String get notConnected => '未連接';

  @override
  String get confirmText => '確定';

  @override
  String get wifiApply => '應用';

  @override
  String get screenOffTimeText => '息屏時間';

  @override
  String get screenOffOption10Min => '10 分鐘';

  @override
  String get screenOffOption30Min => '30 分鐘';

  @override
  String get screenOffOption60Min => '60 分鐘';

  @override
  String get wallpaperSettingText => '壁紙';

  @override
  String get wallpaperOptionDefault => '默認';

  @override
  String get wallpaperApplyRestarts => '更改壁紙將重啓應用。';

  @override
  String get storageMountSystem => '系統';

  @override
  String get storageMountUserData => '用戶數據';

  @override
  String get wifiManual => '手動';

  @override
  String get wifiIpModeStatic => '靜態';

  @override
  String get customHomeReplacementSelected => '已選擇';

  @override
  String get wifiScanning => '正在掃描…';

  @override
  String get wifiNoSavedNetworks => '暫無已保存網絡';

  @override
  String get wifiAutoJoin => '自動加入';

  @override
  String get wifiForgetNetwork => '忘記網絡';

  @override
  String get wifiAutomatic => '自動';

  @override
  String get wifiSubnetMask => '子網掩碼';

  @override
  String get wifiDnsServers => 'DNS 服務器';

  @override
  String get keyboardSoftLayoutPreview => '軟件鍵盤佈局預覽';

  @override
  String get keyboardPhysicalSection => '實體鍵盤';

  @override
  String get keyboardLayoutHelp => '請連接與所選規格匹配的實體鍵盤。規格不匹配可能導致部分按鍵輸出異常字符。';

  @override
  String get keyboardApplyConfirmTitle => '應用鍵盤佈局？';

  @override
  String get keyboardApplyConfirmBody =>
      '將保存所選佈局並重啓 HMI，使軟鍵盤 CyberIME 與實體鍵盤同時生效。重啓後會重新打開本頁。';

  @override
  String get keyboardLongPressAccentHint => '長按可輸入重音字符';

  @override
  String get keyboardNotDetected => '未檢測到';

  @override
  String get cameraStatus => '狀態';

  @override
  String get dateTimeAutomatic => '自動';

  @override
  String get dateTimeModeManual => '手動';

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
  String get cloudEnvironmentTier => '雲環境';

  @override
  String get cloudEnvironmentTierProd => '生產';

  @override
  String get cloudEnvironmentTierTest => '測試';

  @override
  String get cloudEnvironmentFooter =>
      '選擇本機連接的雲服務環境。日常使用請選「生產」；僅在對接測試雲時使用「測試」。對本機所有應用生效。';

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
  String get performanceLabel => '性能';

  @override
  String get balancedLabel => '均衡';

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
  String get uiScaleHelp => 'UI Scale 在 100% 時對應面板的自然尺寸。若介面偏小或偏大，可提高或降低比例。';

  @override
  String get volumeOnlyHelp => '調節本機媒體與系統提示音的音量。';

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
  String get languageSettingHelp => '選擇本機選單與提示使用的語言。';

  @override
  String get regionSettingHelp => '用於無線法規區域，以及預設時區與網路時間伺服器。介面語言仍單獨設定。';

  @override
  String get unitSettingHelp => '選擇公制（℃、毫米）或英制（℉、英寸），用於本機顯示的數值。';

  @override
  String get previewLabel => 'Preview';

  @override
  String get wlanLabel => 'Wi-Fi';

  @override
  String get connectingLabel => 'Connecting…';

  @override
  String get secretsSealHelp =>
      'Secrets Seal 顯示本機如何保護已儲存的機密資訊（如 Wi‑Fi 密碼與雲金鑰）。software 表示軟體加密；op-tee 表示安全晶片。';

  @override
  String get selinuxHelp =>
      'SELinux 是 Linux 的安全策略層。Disabled 表示關閉；Permissive 表示違規只記錄不攔截；Enforcing 表示依策略強制執行。';

  @override
  String get wallpaperSectionHelp => '桌布用於桌面背景及應用介面。變更後會短暫重新啟動設定，以載入新桌布。';

  @override
  String get keyboardApplyConfirmOsBody => '將儲存鍵盤配置，並重新啟動設定，以便匹配的實體鍵盤正常運作。';

  @override
  String get keyboardLayoutHelpOs =>
      '預覽顯示螢幕鍵盤配置。點「套用」儲存後，設定會重新啟動，以便匹配的實體鍵盤正常運作。';

  @override
  String get mousePointerHelp => '變更指標大小後，目前使用的應用會短暫重新啟動。';

  @override
  String get wifiConfigureDns => '設定 DNS';

  @override
  String get wifiIpv4AddressSection => 'IPv4 地址';

  @override
  String get wifiGateway => '閘道';

  @override
  String get wifiDnsLimit => '最多可新增 3 個 DNS 伺服器';

  @override
  String get wifiOthersSection => '其他';

  @override
  String get wifiMacAddress => 'MAC 位址';

  @override
  String get wifiLinkSpeed => '連線速度';

  @override
  String get ethernetCableLink => '網路線';

  @override
  String ethernetSpeedMbps(int speed) {
    return '$speed Mbps';
  }
}
