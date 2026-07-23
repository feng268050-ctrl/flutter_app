# YNHAPI reference (`YNHAPI-20250310.jar`)

Innohi YNH 工控平板硬件 SDK。本仓库仅 vendored JAR，**无厂商原版 PDF/HTML 文档**；本文档由 `javap` 从 JAR 导出签名，并标注 **lws-ui 项目内实际用法**。

| 项 | 值 |
|----|-----|
| Artifact | `vendor/ynhapi/libs/YNHAPI-20250310.jar` |
| 主类 | `com.innohi.YNHAPI` |
| Gradle | `:vendor:ynhapi`（`api` 暴露给 `:app`） |
| 重新导出签名 | `javap -public -classpath vendor/ynhapi/libs/YNHAPI-20250310.jar com.innohi.YNHAPI` |

图例：**✓** = 本仓库有调用；**—** = JAR 有、本项目未用。

---

## 使用注意（lws-ui）

1. **模拟器 / 非 Innohi 固件**：`YNHAPI.getInstance()` 可能抛异常，调用方应 try/catch 降级（见 `DevActivity`、`SystemSettingUtils`）。
2. **侧边 RGB 指示灯（ynh960）**：走 **GPIO** `setGpioState(pin, HIGH|LOW)` 与 `LedIndicatorManager` 闪烁任务，引脚见 `GpioLedConfig`（红=4，黄=3，绿=6）。**不是** `YNHAPI.Light` / `LIGHT_RED` 等 PWM 枚举路径。Dev 页可选 `LedIndicatorManager.setExperimentalPwmBrightness`（GPIO 占空比 PWM，实验性）。
3. **`setLightBrightness(int lightId, …)` 的 `lightId` 是 SDK 内建灯光 ID**（如 `LIGHT_RED` 或 `Light` 枚举对应通道），**不能**传入 GPIO 引脚号调节侧边 RGB 亮度。
4. **两套 API 风格**：许多能力同时有 `System_*` 静态方法与 `getInstance()` 实例方法，新项目优先实例方法。
5. **静默安装**：`installApkSilently` 后进程可能被系统结束，OTA 路径勿依赖安装返回后继续执行（见 `docs/ota-upgrade-flow.md`）。

---

## 入口与常量

### 单例

| 方法 | lws-ui |
|------|--------|
| `static YNHAPI getInstance()` | ✓ 多处 |
| `static void init(Context)` | — |
| `float getApiVersion()` | — |

### 引脚 / 设备 ID 常量

```text
GPIO_1 … GPIO_12, RELAY
LIGHT_RED, LIGHT_BLUE, LIGHT_GREEN, LIGHT_WHITE, LIGHT_INFRARED, LIGHT_CAMERA_EXTERNAL_INFRARED
CASHBOX_0, CASHBOX_1
```

ynh960 侧边灯 GPIO 映射（业务配置，非 JAR 文档）：`app/.../GpioLedConfig.java` → 红 4 / 黄 3 / 绿 6。

---

## GPIO

| 方法 | lws-ui |
|------|--------|
| `boolean setGpioMode(int, GpioMode)` | — |
| `boolean setGpioMode(char, int, GpioMode)` | — |
| `GpioMode getGpioMode(int)` / `(char, int)` | — |
| `boolean setGpioState(int, GpioState)` | ✓ `LedIndicatorManager` |
| `boolean setGpioState(char, int, GpioState)` | — |
| `GpioState getGpioState(int)` / `(char, int)` | — |
| `void listenGpio(int, GpioListenerCallback)` | — |
| `void unlistenGpio(int, GpioListenerCallback)` | — |
| `static void registerGpioListener` / `unregisterGpioListener` | — |
| `static void Gpio_setGpioMux(int, int)` | — |
| `static int Gpio_readGpioMux(int)` | — |
| `static void Gpio_writeGpioVal(int, boolean)` | — |
| `static int Gpio_readGpioVal(int)` | — |

**枚举 `GpioMode`：** `INPUT`, `OUTPUT`, `UNKNOWN`  
**枚举 `GpioState`：** `LOW`, `HIGH`, `UNKNOWN`

**回调 `GpioListenerCallback`：** `void onChanged(int gpio, int oldVal, int newVal)`

---

## 灯光（Light / PWM）

| 方法 | lws-ui |
|------|--------|
| `static void setLightState(Light, boolean)` | — |
| `static boolean getLightState(Light)` | — |
| `static void setLightBrightness(Light, int)` | — |
| `static int getLightBrightness(Light)` | — |
| `void setLightBrightness(int lightId, int brightness)` | — |
| `int getLightBrightness(int lightId)` | — |

**枚举 `Light`：** `Light_Red`, `Light_Green`, `Light_Blue`, `Light_White`, `Light_InfraredLed`

---

## Wiegand（门禁）

| 方法 | lws-ui |
|------|--------|
| `static boolean openWiegand(Wiegand)` / `closeWiegand` | — |
| `static void setWiegandMode(Wiegand)` | — |
| `void writeWiegandMode(WiegandMode)` | — |
| `static int getWiegandMode()` / `WiegandMode readWiegandMode()` | — |
| `static String readWiegand(Wiegand)` / `long readWiegand()` | — |
| `static void readWiegandAsync(WiegandCallback)` / `readWiegandAsyn` | — |
| `static void writeWiegand(Wiegand, String)` | — |
| `void writeWiegand(WiegandFormat, long)` | — |

**枚举：** `Wiegand`（Input / Output26 / Output34）、`WiegandMode`、`WiegandFormat`（FORMAT_26 / FORMAT_34）  
**回调 `WiegandCallback`：** `onSuccess(long)`, `onFailure()`

---

## USB / 外设电源

| 方法 | lws-ui |
|------|--------|
| `static boolean getUsbState(Usb)` / `setUsbState(Usb, boolean)` | — |
| `static boolean getDeviceState(Device)` / `setDeviceState(Device, boolean)` | — |

**枚举 `Usb`：** `Usb_1`, `Usb_2`, `Usb_3`  
**枚举 `Device`：** `Device_5V`, `Device_12V`, `Device_Relay`

---

## 系统控制

| 方法 | lws-ui |
|------|--------|
| `void shutdown()` / `static System_shutDown()` | — |
| `void reboot()` / `static System_reboot()` | — |
| `void sleep()` / `wakeUp()` | — |
| `static System_capScreen(String)` | — |
| `void enableWatchdog(boolean)` / `feedWatchDog()` | — |
| `static System_openWatchDog` / `_feedWatchDog` / `_closeWatchDog` / `_clearWatchDog` | — |
| `void otaUpdate(String)` / `static System_otaUpdate` | — |
| `void installApkSilently(String)` | — |
| `void installApkSilently(String pkgPath, String packageName, String mainActivity)` | ✓ `SystemSettingUtils`, `UpgradeActivity` |
| `static System_installApkSilence` / `void uninstallApkSilently` | — |
| `void setBootLaunchApk(String packageName, boolean enable)` | ✓ `SystemSettingUtils` |
| `static setBootLaunch` | — |
| `void setBootLogo(String)` / `setBootAnimation(String)` | ✓ `setBootAnimation` |
| `void setAppKeepLive(String, int)` | — |
| `void setForegroundAppKeepLive(String, int)` | ✓ `SystemSettingUtils` |
| `void setPowerOnOffAlarm` / `setPowerOnOffAlarmCycle` / `cancelPowerOnOffAlarm` | — |
| `static System_setTimingPowerOnOff` / `System_cancelTimingPowerOnOff` | — |
| `void setSystemTime(long)` | — |
| `boolean isRoot()` / `enableRoot(boolean)` | — |
| `boolean isScreenOn()` / `setScreenOnOff(boolean)` | — |
| `boolean isEnableNetworkProvidedTime()` / `setEnableNetworkProvidedTime(boolean)` | — |
| `void setCameraInfo(int, CameraInfo)` | — |
| `void updateLanguage(String, String)` | — |

---

## 显示与导航栏

| 方法 | lws-ui |
|------|--------|
| `void setNavigationBarVisibility(NavigationBarVisibility)` | ✓ `SystemSettingUtils` |
| `NavigationBarVisibility getNavigationBarVisibility()` | — |
| `static System_hideNavBar` / `System_allwaysHideNavBar` / `System_getNavBarState` | — |
| `void setExtendStatusBarVisibility(ExtendStatusBarVisibility)` | ✓ `SystemSettingUtils` |
| `ExtendStatusBarVisibility getExtendStatusBarVisibility()` | — |
| `void setScreenRotation(ScreenType, RotationDegree)` / `getScreenRotation` | — |
| `void setInputRotation` / `getInputRotation` | — |
| `static System_setRotation` | — |
| `void setLcdDensity(LcdDensity)` / `getLcdDensity()` | — |

**`NavigationBarVisibility`：** `INVISIBLE`, `VISIBLE`, `ALWAYS_INVISIBLE`, `INVISIBLE_FOREVER`, `VISIBLE_FOREVER`, `ALWAYS_INVISIBLE_FOREVER`, `UNKNOWN`

**`ExtendStatusBarVisibility`：** `VISIBLE_NOT_EXPAND`, `VISABLE_EXPAND`, `INVISIBLE`, `*_FOREVER`, `UNKNOWN`

**`ScreenType`：** `MAIN`, `AUX` · **`RotationDegree`：** `DEGREE_0/90/180/270`, `UNKNOWN` · **`LcdDensity`：** `140/160/240/320`, `UNKNOWN`

---

## 网络

| 方法 | lws-ui |
|------|--------|
| `boolean isEthernetOpen()` | ✓ `CameraUtils`, `SystemSettingUtils` |
| `void setEthernetState(boolean)` | ✓ `SystemSettingUtils` |
| `IpConfig getIpConfig()` | — |
| `void setStaticIp(IpConfig)` / `setDhcpIp()` | — |
| `IpMode getIpMode()` | — |
| `static String[] System_getIP()` / `System_setIP(...)` | — |

**`IpConfig`：** `ip`, `mask`, `gateway`, `dnsList`（`com.innohi.entity.IpConfig`）  
**`IpMode`：** `STATIC`, `DHCP`, `UNKNOWN`

---

## 设备信息

| 方法 | lws-ui |
|------|--------|
| `String getSerialNo()` / `setSerialNo` | ✓ `DeviceIdentity` |
| `static System_getSerialNo()` | — |
| `String getEthernetMAC()` / `setEthernetMAC` | — |
| `String getIMEI()` / `setIMEI` | — |
| `String getProductModel()` / `setProductModel` | — |
| `String getBoardModel()` | — |
| `List<StorageInfo> getStorageInfos()` | ✓ `CameraRecordCoordinator` |
| `List<String> get4GModuleNames()` / `set4GModule` | — |
| `List<String> getGPSModuleNames()` / `setGPSModule` | — |

**`StorageInfo`：** `getType()`, `getTotalSize()`, `getFreeSize()`, `getPath()`  
类型常量：`TYPE_MEMORY`, `TYPE_LOCAL_STORAGE`, `TYPE_TFCARD`, `TYPE_USB_STORAGE`

---

## 同 JAR 其他类

### `com.innohi.ShellCmdUtil`

| 方法 | lws-ui |
|------|--------|
| `static boolean executeCmd(String)` | ✓ 经 `app` 的 `ShellCmdUtil.executeCmdAsRoot`（`su`/`ssu` 提权） |

应用内非 root 命令走 `app/.../ShellCmdUtil.executeCmd`（`sh -c`），与厂商类同名但分包不同。

### `com.innohi.PropertyUtil`

| 方法 | lws-ui |
|------|--------|
| `static String get(String, String)` | — |
| `static void set(String, String)` | — |
| `static boolean getBoolean(String, boolean)` | — |

---

## lws-ui 调用索引

| 文件 | 使用的 API |
|------|------------|
| `LedIndicatorManager` | `getInstance`, `setGpioState`, `setExperimentalPwmBrightness`（Dev 实验） |
| `SystemSettingUtils` | `setBootLaunchApk`, `setForegroundAppKeepLive`, `installApkSilently`, 状态栏/导航栏, `isEthernetOpen`, `setEthernetState`, `setBootAnimation` |
| `UpgradeActivity` | `installApkSilently` |
| `CameraUtils` | `isEthernetOpen` |
| `CameraRecordCoordinator` | `getStorageInfos` |
| `DeviceIdentity` | `getSerialNo` |
| `DevActivity` | `getInstance`（可用性探测） |
| `ShellCmdUtil`（app） | `com.innohi.ShellCmdUtil.executeCmd`（root 路径） |

---

## 延伸阅读（本仓库）

- `vendor/README.md` — vendored 模块总览
- `openspec/specs/rgb-gpio-indicator-lights/spec.md` — 侧边 RGB 业务语义
- `app/.../GpioLedConfig.java` — GPIO 引脚号
- `docs/ota-upgrade-flow.md` — 静默安装行为

完整厂商手册需向 Innohi / 板卡供应商索取；若 SDK 升级，请替换 JAR 并重新运行 `javap` 更新本文档。
