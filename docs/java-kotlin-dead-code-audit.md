# Java/Kotlin 遗留代码审计清单

> 生成日期：2026-06-24  
> 范围：`app` 模块 main/test 源码 + Gradle 依赖（不含 native/resources 专项）  
> 目的：供后续瘦身时逐项人工确认与删除。

---

## 方法论

- 对 `app/src/main/java`、`app/src/main/kotlin` 约 **939** 个源文件做类名全工程引用扫描（含 test/androidTest）。
- **0 外部引用** → 标为「疑似孤儿类」；再结合 Manifest、layout XML、Gradle 人工复核。
- **局限**：
  - 会漏掉：反射、字符串 class 名、仅 JNI 调用的符号。
  - 会误报：DataBinding `@BindingAdapter`（layout 用 `app:*` 引用）、Manifest 注册的 Receiver。
  - **vendored 子模块**（`vendor/easydarwin`、`vendor/modbus4j` 等）：只审计 **app 是否仍引用其 public API**，**不删库内 Java 源文件**。
- **删除前必做**：`./gradlew :app:assembleDebug` + 关键路径手测；Room entity 删除需 migration。

---

## 量化摘要

| 指标 | 数量 |
|------|------|
| app main Java/Kotlin 源文件 | ~939 |
| 疑似孤儿类（符号扫描） | 31（部分已人工剔除误报） |
| `@Deprecated` 标记 | ~100+ 处 / 40+ 文件 |
| Room migration 文件 | 34 个（~1010 行，**保留**，非死代码） |
| 高置信度可删整文件候选 | ~40–50 个 |
| release 构建 | `minifyEnabled=false`，`shrinkResources=false`；APK ~135 MB（Wave 5 R8 曾试 ~88 MB，已回退） |

---

## A. 高置信度死代码（建议优先检查/删除）

### A.1 工程师模式旧 ViewModel（已被 `BaseProcessParametersDataViewModel` 取代）

当前 Fragment 使用 `ProcessParametersDataViewModel` → `BaseProcessParametersDataViewModel`。

| 文件 | 路径 |
|------|------|
| `EngineerCuttingViewModel` | `app/src/main/java/com/lasercyber/lws/ui/activitys/engineer/mode/model/EngineerCuttingViewModel.java` |
| `EngineerWashViewModel` | `app/src/main/java/com/lasercyber/lws/ui/activitys/engineer/mode/model/EngineerWashViewModel.java` |
| `EngineerWeldingViewModel` | `app/src/main/java/com/lasercyber/lws/ui/activitys/engineer/mode/model/EngineerWeldingViewModel.java` |
| `EngineerBaseViewModel` | `app/src/main/java/com/lasercyber/lws/ui/activitys/engineer/mode/model/EngineerBaseViewModel.java` |

- [x] 2026-06-24 Wave 1 已删除（4 个 ViewModel + `EngineerBaseViewModel`）

---

### A.2 机台监控 ECharts 仪表盘（已改为 `CircleProgressView`）

`MachineStatusBaseFragment` 已用 `CircleProgressView`；`WorkInfoFragment.initCharConfig` 已改为 `StatAdapter` RecyclerView。

| 文件 | 路径 |
|------|------|
| `AirPressureChartViewModel` | `app/src/main/java/com/lasercyber/lws/ui/activitys/device/monitor/model/AirPressureChartViewModel.java` |
| `CurrentChartViewModel` | `app/src/main/java/com/lasercyber/lws/ui/activitys/device/monitor/model/CurrentChartViewModel.java` |
| `ChartInterface` | `app/src/main/java/com/lasercyber/lws/ui/bean/ui/ChartInterface.java` |
| `EchartsConstant` | `app/src/main/java/com/lasercyber/lws/ui/common/constant/EchartsConstant.java` |
| `ThemeModeManager` | `app/src/main/java/com/lasercyber/lws/ui/common/utils/ThemeModeManager.java` |

**连带清理：**

- `Home.java` 中未使用的 import：`import static com.github.abel533.echarts.code.ColorMappingBy.index;`
- Gradle：`libs.echarts`（xui echarts）
- `LaserApplication` / `BaseActivity` 中已注释的 `ThemeModeManager.init` 块

- [x] 2026-06-24 Wave 2 已删除 5 个类并移除 `libs.echarts`；清理 `Home.java` import 与 `ThemeModeManager` 注释块

---

### A.3 AgentWeb / WebView 图表栈（调用链已断）

| 文件 | 路径 | 说明 |
|------|------|------|
| `WebUtils` | `app/src/main/java/com/lasercyber/lws/ui/common/utils/web/WebUtils.java` | `createAgentWeb()` 无调用者 |
| `WebViewPreloader` | `app/src/main/java/com/lasercyber/lws/ui/config/WebViewPreloader.java` | 无引用 |
| `MiddlewareWebViewClient` | `app/src/main/java/com/lasercyber/lws/ui/component/webview/MiddlewareWebViewClient.java` | 仅被 WebUtils 引用 |
| `HtmlTemplate` | `app/src/main/java/com/lasercyber/lws/ui/common/constant/HtmlTemplate.java` | 无引用 |
| `HtmlPageConfigUtil` | `app/src/main/java/com/lasercyber/lws/ui/common/utils/HtmlPageConfigUtil.java` | 无引用 |
| `BaseWebFragment` | `app/src/main/java/com/lasercyber/lws/ui/activitys/BaseWebFragment.java` | 子类不再 override `initWebView()` |

**结构遗留：** `MachineStatusBaseFragment extends BaseWebFragment`，但实际不再使用 WebView。后续可改为 `extends BaseFragment` 并删除 AgentWeb 生命周期代码。

**连带 Gradle 依赖（删除代码后评估）：**

- `libs.com.github.xuexiangjys.agentweb.agentweb.core2`
- `libs.com.github.xuexiangjys.agentweb.agentweb.download2`
- `libs.com.github.xuexiangjys.agentweb.agentweb.filechooser2`

- [x] 2026-06-24 Wave 2 已删除 Web 栈 6 个类；`MachineStatusBaseFragment` 改继承 `BaseFragment`；移除 AgentWeb 三件套依赖

**结构遗留：** ~~`MachineStatusBaseFragment extends BaseWebFragment`~~ 已改为 `extends BaseFragment`（2026-06-24 Wave 2）。

**连带 Gradle 依赖（删除代码后评估）：**

- ~~`libs.echarts`~~ 已移除
- ~~AgentWeb 三件套~~ 已移除

**assets 遗留（Wave 2 未删，2026-06-25 清理）：**

| 路径 | 说明 |
|------|------|
| `assets/echarts/` | ECharts JS + `homeStatic.js` + `laserDark` 主题（~2 MB） |
| `assets/index.html` / `index.js` / `index.css` / `vue.js` | 旧 Vue WebView 首页（~1.1 MB） |
| `assets/template/chartTemplate.*` | 旧 WebView 图表模板 |
| `assets/page/lod.html` | 旧加载页，无 Java 引用 |
| `WebViewAndEntity` | 零引用 bean |

- [x] 2026-06-25 已删除上述 assets 与 `WebViewAndEntity`；首页统计仍由 `StatisticFragment` + `SemiCircleProgressView` 原生实现

---

### A.4 测试/样例代码误入生产

| 项 | 路径 | 问题 |
|----|------|------|
| `DeviceTest` | `app/src/main/java/com/lasercyber/lws/ui/bean/test/DeviceTest.java` | 仍在 Room `@Database(entities=...)` |
| `DeviceTestDao` | `app/src/main/java/com/lasercyber/lws/ui/bean/test/DeviceTestDao.java` | 无引用 |
| `DeviceHexTest` | `app/src/main/java/com/lasercyber/lws/ui/bean/test/DeviceHexTest.java` | 仅 unit test 使用 |
| `User` | `app/src/main/java/com/lasercyber/lws/ui/bean/test/User.java` | 仅 test 使用 |
| `DataBean` | `app/src/main/java/com/lasercyber/lws/ui/bean/test/DataBean.java` | 仅 `TestRemoteApi` 使用 |
| `DeviceConfigExecutionDayBean` | `app/src/main/java/com/lasercyber/lws/ui/bean/test/DeviceConfigExecutionDayBean.java` | 仅 DataBean 字段 |
| `TestRemoteApi` | `app/src/main/java/com/lasercyber/lws/ui/network/http/api/TestRemoteApi.java` | 无业务调用 |
| `RequestApi.getApiService()` | `app/src/main/java/com/lasercyber/lws/ui/network/http/RequestApi.java` | 创建 TestRemoteApi，无调用者 |
| `ExampleUnitTest` | `app/src/test/java/com/lasercyber/lws/ui/ExampleUnitTest.java` | hex 转换样例 |

- [x] 2026-06-24 Wave 3：`Migration_50_51` 删除 `t_device_test`；hex fixture 迁至 `src/test`；移除 `TestRemoteApi` / `getApiService()`

---

### A.5 EventBus 事件（串口时代残留）

云端推送已走 WebSocket（`DeviceWebSocketConnectionManager`）。`MqttMessageEvent` / `MqttStatusEvent` 已于 2026-06 删除。

| 文件 | 路径 |
|------|------|
| `SerialPortEvent` | `app/src/main/java/com/lasercyber/lws/ui/bean/event/SerialPortEvent.java` |

- [x] 2026-06-24 Wave 1 已删除 `SerialPortEvent`

---

### A.6 空接口 / 未接线 Fragment / Builder

| 文件 | 路径 | 说明 |
|------|------|------|
| `DeviceCommandChannel` | `app/src/main/java/com/lasercyber/lws/ui/network/channel/DeviceCommandChannel.java` | 空 interface |
| `DeviceDataChannel` | `app/src/main/java/com/lasercyber/lws/ui/network/channel/DeviceDataChannel.java` | 空 interface |
| `LaserWorkFragment` | `app/src/main/java/com/lasercyber/lws/ui/activitys/engineer/mode/fragment/LaserWorkFragment.java` | 未加入 ViewPager |
| `TurnLaserFragment` | `app/src/main/java/com/lasercyber/lws/ui/activitys/engineer/mode/fragment/TurnLaserFragment.java` | 未加入 ViewPager |
| `PickerBuilder` | `app/src/main/java/com/lasercyber/lws/ui/activitys/engineer/mode/ui/PickerBuilder.java` | 无引用 |
| `SpinnerBuilder` | `app/src/main/java/com/lasercyber/lws/ui/activitys/engineer/mode/ui/SpinnerBuilder.java` | 无引用 |
| `ScreenDisplay` | `app/src/main/java/com/lasercyber/lws/ui/bean/entity/ScreenDisplay.java` | 无引用 |
| `ProcessParameter` | `app/src/main/java/com/lasercyber/lws/ui/bean/ui/ProcessParameter.java` | 无引用（勿与 `ProcessParameterDisplayRows` 混淆） |
| `ProcessParameterListViewAdapter` | `app/src/main/java/com/lasercyber/lws/ui/activitys/engineer/mode/adapter/ProcessParameterListViewAdapter.java` | 无引用 |

- [x] 2026-06-24 Wave 1 已删除（含 `fragment_laser_work.xml` / `fragment_turn_laser.xml`）

---

### A.7 AI / Gson / IME 遗留

| 文件 | 路径 | 说明 |
|------|------|------|
| `AiVisionInferenceVideoUploadRunner` | `app/src/main/java/com/lasercyber/lws/ui/common/handler/AiVisionInferenceVideoUploadRunner.java` | 从未实例化 |
| `ProcessVideoAiMuxerEncoder` | `app/src/main/java/com/lasercyber/lws/ui/common/ai/video/ProcessVideoAiMuxerEncoder.java` | package-private，同包无引用 |
| `ImeDialogSession` | `app/src/main/kotlin/com/lasercyber/lws/ime/interop/ImeDialogSession.kt` | `@Deprecated`，零调用 |

- [x] 2026-06-24 Wave 1 已删除

---

### A.8 工具类 / DAO 孤儿

| 文件 | 路径 | 说明 |
|------|------|------|
| `DeviceDataConstant` | `app/src/main/java/com/lasercyber/lws/ui/common/constant/DeviceDataConstant.java` | 无引用 |
| `EditUtils` | `app/src/main/java/com/lasercyber/lws/ui/common/utils/EditUtils.java` | 无引用 |
| `NetworkStatusUtil` | `app/src/main/java/com/lasercyber/lws/ui/common/utils/NetworkStatusUtil.java` | 无引用 |
| `SpinnerUtils` | `app/src/main/java/com/lasercyber/lws/ui/common/utils/SpinnerUtils.java` | 无引用 |
| `Byte2ShortConverter` | `app/src/main/java/com/lasercyber/lws/ui/common/utils/Byte2ShortConverter.java` | 无引用 |
| `RxTaskCallBack` | `app/src/main/java/com/lasercyber/lws/ui/common/rx/modbus/call/RxTaskCallBack.java` | interface，无引用 |
| `OtherConfigDao` | `app/src/main/java/com/lasercyber/lws/ui/repository/OtherConfigDao.java` | 无引用 |
| `ParameterSettingsDao` | `app/src/main/java/com/lasercyber/lws/ui/repository/ParameterSettingsDao.java` | 无引用 |
| `XUIDialogBaseStyleUtils` | `app/src/main/java/com/lasercyber/lws/ui/common/utils/XUIDialogBaseStyleUtils.java` | 无引用 |
| `XUISimplePopupUtils` | `app/src/main/java/com/lasercyber/lws/ui/common/utils/XUISimplePopupUtils.java` | 无引用 |
| `EngineerModeMenu` | `app/src/main/java/com/lasercyber/lws/ui/bean/ui/EngineerModeMenu.java` | 仅被 XUISimplePopupUtils 引用 |

**BindingAdapter（扫描误报为孤儿，需 layout 复核）：**

| 文件 | 结论 |
|------|------|
| `ImageBindingAdapter` | layout 中未见 `app:imageSrc` 等 → **倾向可删** |
| `LinearLayoutBindingAdapter` | layout 中未见自定义 margin/padding 绑定 → **倾向可删** |
| `CommStatusBindingAdapter` | **仍在用**（告警/通讯 UI）→ **保留** |
| `MachineStatusBindingAdapter` | **仍在用**（`fragment_machine_status.xml` `app:machineStatusChecked`）→ **保留** |

- [x] 2026-06-24 Wave 1 已删除 `LinearLayoutBindingAdapter`、XUI popup 工具链及 DAO/工具孤儿（**保留** `ImageBindingAdapter`，`fragment_c_n_c_cut.xml` 仍用 `imageSrc`）

---

### A.9 WorkInfo 数据库层半拆除

| 项 | 路径 | 状态 |
|----|------|------|
| `WorkInfo` | `app/src/main/java/com/lasercyber/lws/ui/bean/entity/WorkInfo.java` | 实体仍在，DB 中已注释 |
| `WorkInfoDao` | `app/src/main/java/com/lasercyber/lws/ui/repository/WorkInfoDao.java` | DB 中 dao 已注释 |
| `WorkInfoViewModel` | `app/src/main/java/com/lasercyber/lws/ui/activitys/device/monitor/model/WorkInfoViewModel.java` | 逻辑全部注释，空壳 |
| `WorkInfoFragment` | `app/src/main/java/com/lasercyber/lws/ui/activitys/device/monitor/fragment/WorkInfoFragment.java` | 已改用 `StaticData` + `StatAdapter` |
| `AppDatabase` | `app/src/main/java/com/lasercyber/lws/ui/common/database/AppDatabase.java` | `WorkInfo.class` / `workInfoDao()` 已注释 |

- [x] 2026-06-24 Wave 3：删除 `WorkInfo` / `WorkInfoDao` / `WorkInfoViewModel`；`WorkInfoFragment` 保留（`StaticData` + `StatAdapter`）；`Migration_50_51` 删除 `t_work_info`

---

## B. @Deprecated 但仍被使用（分阶段清理，不可直删）

| 区域 | 规模 | 说明 |
|------|------|------|
| `DeviceStatus.java` | 28 处 `@Deprecated` | Modbus 字段演进，仍参与转换/缓存 |
| `ProcessParametersData.java` | 7 处 | 含 deprecated 焊接功率/宽度等 |
| `WarnInfo.java` | 整类 `@Deprecated` | 仍被 `ModbusFiledConvert`、`WarnInfoFragment` 使用 |
| `DefaultValueUtils.java` | ~~10+ 处注释块~~ Wave 4 已清理 deprecated 字段赋值注释 |
| `CacheKey.java` | ~~2 个 deprecated key~~ Wave 4 已删 `MACHINE_STATUS_KEY` / `EQUIPMENT_STATUS_KEY` |
| 其他 | ~50 处 / 40+ 文件 | 见下方文件列表 |

**含 `@Deprecated` 的主要文件（供 grep 跟进）：**

```
AiInferenceSseHub.java          AiInferenceSseJson.java
AiManager.java                  BootSelfCheckCoordinator.java
CacheKey.java                   CameraConfig.java
DeviceDialogHandler.java        DeviceLocalHttpServer.java
DeviceStatus.java               DeviceStatusConstant.java
DeviceWebSocketConfig.java      EngineerCuttingConvert.java
EngineerWeldingConvert.java     GeneralOperationsFragment.java
MediaMtxConfigRenderer.java     ModbusConfig.java
ModbusFiledConvert.java         ProcessDataType.java
ProcessParametersData.java      ProcessVideoDetailsFragment.java
QuickProcessParametersDataViewModel.java
RxModbusTaskBuilder.java        TopTabView.java
WarnInfo.java                   ZeroPointDetectJson.java
AdvancedSettingViewModel.java   BaseDeviceControlData.java
DeviceControlUtils.java         DeviceControllerRegisterAddress.java
DeviceDataRegisterAddress.java  DeviceInfoRegisterAddress.java
EquipmentStatus.java            MachineStatus.java
WheelView.java / BaseWheelAdapter.java
ImeOverlaySpec.kt               ImeKeyboardOverlay.kt
KeyboardController.kt             KeyboardLanguageSelector.kt
KeyboardLayouts.kt
FrostPanelBorderForeground.kt   PanelBorderDrawable.kt
PanelCompositeDrawable.kt       PanelFillDrawable.kt
```

- [x] 2026-06-24 Wave 4（阶段 1）：移除零调用 `@Deprecated` API；清理 `DefaultValueUtils` 注释块；`ModbusManager` 统一 `COMMAND_INTERVAL_MS`

**Wave 4 阶段 1 已删除/清理：**

| 类别 | 项 |
|------|-----|
| SSE 别名 | `AiInferenceSseHub.publishInference` / `publishLiveCameraInferenceAt`；`AiInferenceSseJson.inferenceData` |
| 设备/UI | `DeviceDialogHandler.checkDeviceStatus` / `showCameraCommunicationDialog`；`DeviceControlUtils.createWireFeedEnableConfig` |
| 相机/MediaMTX | `CameraConfig.getMediaMtxUpstreamRtspUrl` / `getPr0RecordingRtspCandidates`；`MediaMtxConfigRenderer.currentUpstreamRtspUrl` |
| Modbus | `ModbusFiledConvert.machineStatusConvert` / `warnInfoConvert` / `equipmentStatusConvert`；`RxModbusTaskBuilder.buildReadInputTask(long)`；`ModbusConfig.SAME/DIFF_PROTOCOL_INTERVAL`；`DeviceInfoRegisterAddress.RESERVED_3_*` |
| 缓存/网络 | `CacheKey.MACHINE_STATUS_KEY` / `EQUIPMENT_STATUS_KEY`；`DeviceWebSocketConfig.PROD/TEST_API_HOST` |
| AI/IME | `AiManager.onI420Frame`；`ZeroPointDetectJson.CODE_SPOT_SIZE_REJECTED`；`KeyboardController.forNumericInput`；`KeyboardLanguageSelector.initialKind(Boolean)`；`QuickProcessParametersDataViewModel.getAdvancedSettingData` |
| 注释/F | `DefaultValueUtils` deprecated 字段赋值注释；`EngineerModeActivity` / `GeneralOperationsFragment` 送丝注释；Gradle serialport/okdownload 注释行 |

**Wave 4 阶段 2（待硬件对齐，未动）：** `DeviceStatus` reserveSeg、`WarnInfo`、`ProcessParametersData` deprecated 字段、`EquipmentStatus` deprecated 布尔位等

- [ ] 阶段 2：Room migration 删除 `ProcessParametersData` deprecated 列；对齐 Modbus 寄存器后删 `DeviceStatus` reserveSeg

---

## C. 命名遗留但仍在运行（改名需协议兼容，非死代码）

| 遗留名 | 现实用途 | 备注 |
|--------|----------|------|
| `ObjectStorageUrls` | R2 读 URL 拼接（`joinPublicBaseUrl`）、视频大小校验 | 原 `OSSManger`（2026-06-24 改名）；**阿里云 OSS SDK 已移除** |
| `ServerPushEnvelope` / `msgType` 1·2 | WebSocket JSON 仍沿用历史字段名 | 2026-06 自 `bean/mq/*` 迁至 `bean/push/*` |
| `ProcessVideoR2CoverUpload` 等 `*R2*` 类 | R2 STS + S3 PutObject 实际上传 | Worker `POST /v1/storage/r2/sts` |
| `AiInferenceSseHub` deprecated 方法 | ~~SSE API 演进~~ Wave 4 阶段 1 已删零调用别名 | — |
| `DeviceLocalHttpServer.DEPRECATED_PORT = 8080` | 文档常量 | 当前端口 5580 |
| `CommonSettingsLanguage.fromLegacyLanguageSetting` | 语言设置迁移 | 保留至无旧数据 |
| `LibraryVersionHelper` LEGACY placeholder | 版本显示 | 保留 |

- [x] 2026-06-24：`OSSManger` → `ObjectStorageUrls`（`app/.../common/oss/`）

---

## D. 调试 / 开发专用（保留在 release / main）

| 项 | 路径 | 说明 |
|----|------|------|
| `DevActivity` | `app/src/main/java/com/lasercyber/lws/ui/activitys/dev/DevActivity.java` | Manifest 注册；adb 可启动（Splash 不跳转） |
| `DemoAlarmReceiver` | `app/src/main/java/com/lasercyber/lws/ui/common/handler/DemoAlarmReceiver.java` | `make alarm` adb |
| `DemoSafetyGroundLockReceiver` | `app/src/main/java/com/lasercyber/lws/ui/common/handler/DemoSafetyGroundLockReceiver.java` | adb 广播 |
| `SyncFirmwareReceiver` | `app/src/main/java/com/lasercyber/lws/ui/common/handler/SyncFirmwareReceiver.java` | `make sync-firmware` |
| `AiUploadFailureSampleHook` | `app/src/main/java/com/lasercyber/lws/ui/ai/upload/AiUploadFailureSampleHook.java` | 手动/debug 入口；无自动调用 |

- [x] **保留在 `main` / release APK**（2026-06-24 产品决策）：设备以 **release 构建** 安装为 priv-app；debug 变体会缺失系统权限，日常开发与产线均走 release，故 **不迁入 `debug` 源集**。

---

## E. Gradle 依赖遗留 / 重复

文件：`app/build.gradle.kts`

| 依赖 | 状态 | 建议 |
|------|------|------|
| ~~`libs.echarts`~~ | **已移除**（2026-06 Wave 2） | — |
| ~~AgentWeb 三件套~~ | **已移除**（2026-06 Wave 2） | — |
| ~~`libs.oss.android.sdk`~~ | **已移除**（2026-06） | 工艺视频仅用 R2 + AWS S3 SDK |
| AWS S3 SDK (`software.amazon.awssdk:s3`) | R2 在用 | 保留 |
| `// libs.liulishuo.okdownload` | **已删注释**（2026-06 Wave 4） | — |
| `// libs.android.serialport` | **已删注释**（2026-06 Wave 4） | — |
| `appcompat` / `material` / `activity` | ~~重复声明~~ **已去重**（2026-06-24 后续 1） | — |
| `isMinifyEnabled` / `isShrinkResources` | **`false`**（Wave 5 R8 **已回退**） | 真机曾踩 JNI / FrostUI 动态资源 / Modbus commons-logging；维护成本高 |
| `multiDexEnabled` | **`true`** + `androidx.multidex` | release 未 minify，方法数仍 > 64K |
| `proguard-rules.pro` | 保留 `-dontshrink` / `-dontoptimize` | minify 关闭时不生效；勿删 Modbus/串口 keep 块 |

**子模块（勿误删）：**

| 模块 | 用途 |
|------|------|
| `modbus4j` | Serotonin 协议栈（`vendor/modbus4j`） |
| `modbus4android` | Modbus RTU + 串口（`vendor/modbus4android`） |
| `easydarwin` | RTSP/录制，`EasyPlayerClient`（Gradle `:vendor:easydarwin`） |

**library（EasyDarwin，vendored 第三方 — 只审计 app 用法，不删库内代码）：**

> **原则**：`vendor/*`（`easydarwin`、`modbus4j`、`modbus4android`）视为上游快照，**不做库内 dead-code 删除**（避免升级/合并困难、误删库内反射/JNI 链）。瘦身范围仅限 **app 是否仍依赖该模块的 public API**。

| app 侧用法 | 入口 | 状态 |
|------------|------|------|
| RTSP 预览 / I420 推理 | `AiVisionFragment`、`LivePr1InferenceStreamClient` → `EasyPlayerClient` | ✅ 在用 |
| PR0 工艺视频录制 | `EasyPlayerClientManger` → `EasyMuxer2` | ✅ 在用 |
| 后台循环录 | `BackgroundLoopRecorder` | ✅ 在用 |
| LAN HTTP 相机流 | 曾用 `EncodedVideoSink` | 已迁 **MediaMTX**；库内 API 保留不动 |

库内 16 个 Java 源文件均为 EasyDarwin 上游结构；**不逐项删改**。历史误删 `EasyPlayer` / `TxtOverlay` / `ParsableByteArray` 已按此原则 **恢复**。

**可选（Gradle/Manifest，非 Java 删类）：** `vendor/easydarwin/build.gradle` 的 `support-v7` 与 app AndroidX 并存；`AndroidManifest` 历史权限 — 改依赖需单独回归。

- [x] 2026-06-24 后续 1：Gradle 去重（`appcompat`/`activity` 各保留一处；移除 app 侧 `appcompat-v7` + support `constraint-layout`）
- [x] 2026-06-24 后续 5：**library 用法审计**（确认 app 仍依赖 `EasyPlayerClient` 链；**不删** vendored 库内类）
- [x] 2026-06-24 Wave 5（**已回退**）：曾开启 R8 + shrinkResources（APK ~88 MB）；rk3566 真机出现 NativeBridge JNI 回调、`FrostResources` 动态 `@color/frost_*`、`commons-logging`/`modbus4j` 初始化三类故障；**产品决策关闭 R8**，恢复 `multiDexEnabled=true` 与 `proguard-rules.pro` 原 `-dontshrink` 配置

---

## F. 注释块 / TODO 遗留（非整文件删除）

| 位置 | 内容 |
|------|------|
| `LaserApplication.java` | ~~OkDownload init 已注释~~ / ~~后台保存视频 TODO~~ Wave 4 后续 2 已清理 |
| `SplashActivity.java` | ~~DevActivity 跳转已注释~~ Wave 4 后续 2 已清理 |
| `EngineerModeActivity.java` | ~~TODO 后续需要补全~~ Wave 4 后续 2 已清理 |
| `GeneralOperationsFragment.java` | ~~TODO 后续需要补全~~ Wave 4 后续 2 已清理 |
| `ModbusProtocol.java` | ~~TODO + 注释掉的 CRC/错误响应块~~ Wave 4 后续 2 已清理（校验仍跳过，行为不变） |
| `EngineerDataCheck.java` | ~~多处 TODO 占位~~ Wave 4 后续 2 已清理 |
| `ModbusFiledBuilder.java` | ~~测试阶段 wire-feed 注释块~~ Wave 4 后续 2 已清理 |

- [x] 2026-06-24 后续 2：清理 F 节纯注释死代码（Modbus CRC 跳过行为未改）
- [ ] TODO 项纳入产品 backlog 或实现（材料/名称/工艺类型校验规则仍待产品定义）

---

## G. 符号扫描「疑似孤儿」完整列表（含误报，已人工勾选）

以下 31 项来自自动化扫描；结论已与 Wave 1–3 / 后续 4 执行结果同步。

| 类名 | 路径 | 人工结论 |
|------|------|----------|
| `AirPressureChartViewModel` | `.../monitor/model/AirPressureChartViewModel.java` | ✅ Wave 2 已删 |
| `CurrentChartViewModel` | `.../monitor/model/CurrentChartViewModel.java` | ✅ Wave 2 已删 |
| `EngineerCuttingViewModel` | `.../engineer/mode/model/EngineerCuttingViewModel.java` | ✅ Wave 1 已删 |
| `EngineerWashViewModel` | `.../engineer/mode/model/EngineerWashViewModel.java` | ✅ Wave 1 已删 |
| `EngineerWeldingViewModel` | `.../engineer/mode/model/EngineerWeldingViewModel.java` | ✅ Wave 1 已删 |
| `PickerBuilder` | `.../engineer/mode/ui/PickerBuilder.java` | ✅ Wave 1 已删 |
| `SpinnerBuilder` | `.../engineer/mode/ui/SpinnerBuilder.java` | ✅ Wave 1 已删 |
| `ScreenDisplay` | `.../bean/entity/ScreenDisplay.java` | ✅ Wave 1 已删 |
| `DeviceTestDao` | `.../bean/test/DeviceTestDao.java` | ✅ Wave 3 已删 |
| `DeviceDataConstant` | `.../constant/DeviceDataConstant.java` | ✅ Wave 1 已删 |
| `HtmlTemplate` | `.../constant/HtmlTemplate.java` | ✅ Wave 2 已删 |
| `ModbusControlField1Bit` | `.../constant/ModbusControlField1Bit.java` | ✅ 后续 4 已删（零引用；Bit 定义见 `DeviceControllerRegisterAddress` 注释） |
| `AiVisionInferenceVideoUploadRunner` | `.../handler/AiVisionInferenceVideoUploadRunner.java` | ✅ Wave 1 已删 |
| `RxTaskCallBack` | `.../rx/modbus/call/RxTaskCallBack.java` | ✅ Wave 1 已删 |
| `Byte2ShortConverter` | `.../utils/Byte2ShortConverter.java` | ✅ Wave 1 已删 |
| `EditUtils` | `.../utils/EditUtils.java` | ✅ Wave 1 已删 |
| `HtmlPageConfigUtil` | `.../utils/HtmlPageConfigUtil.java` | ✅ Wave 2 已删 |
| `NetworkStatusUtil` | `.../utils/NetworkStatusUtil.java` | ✅ Wave 1 已删 |
| `SpinnerUtils` | `.../utils/SpinnerUtils.java` | ✅ Wave 1 已删 |
| `XUIDialogBaseStyleUtils` | `.../utils/XUIDialogBaseStyleUtils.java` | ✅ Wave 1 已删 |
| `XUISimplePopupUtils` | `.../utils/XUISimplePopupUtils.java` | ✅ Wave 1 已删 |
| `ImageBindingAdapter` | `.../adapter/ImageBindingAdapter.java` | ✅ **保留**（`fragment_c_n_c_cut.xml` `imageSrc`） |
| `LinearLayoutBindingAdapter` | `.../adapter/LinearLayoutBindingAdapter.java` | ✅ Wave 1 已删 |
| `DeviceCommandChannel` | `.../channel/DeviceCommandChannel.java` | ✅ Wave 1 已删 |
| `DeviceDataChannel` | `.../channel/DeviceDataChannel.java` | ✅ Wave 1 已删 |
| `OtherConfigDao` | `.../repository/OtherConfigDao.java` | ✅ Wave 1 已删 |
| `ParameterSettingsDao` | `.../repository/ParameterSettingsDao.java` | ✅ Wave 1 已删 |
| `FrostHomeClockView` | `frostui/clock/interop/FrostHomeClockView.kt` | ✅ **保留**（`activity_main.xml`） |
| `FrostFlankedSliderView` | `frostui/control/interop/...` | ✅ **保留**（`activity_process_video_details.xml`） |
| `FrostSegmentedControlView` | `frostui/control/interop/...` | ✅ **保留**（`fragment_common_settings.xml`） |
| `ImeDialogSession` | `ime/interop/ImeDialogSession.kt` | ✅ Wave 1 已删 |

---

## H. 建议执行顺序（Waves）

```
Wave 1 ─ 删 A 节确认死类 + 清 F 节注释（低风险）                    ✅
   │
Wave 2 ─ 去 ECharts + AgentWeb 依赖；MachineStatusBaseFragment 改继承  ✅
   │
Wave 3 ─ Room：移除 DeviceTest entity；WorkInfo 二选一清理              ✅
   │
Wave 4 阶段 1 ─ 零调用 @Deprecated API + 注释死代码                   ✅
   │
Wave 4 阶段 2 ─ Modbus/Room deprecated 字段（需硬件对齐）             ⏸ 暂缓
   │
后续 1 ─ Gradle 依赖去重 + library 用法确认                              ✅ 2026-06-24
   │
后续 2 ─ F 节剩余注释/TODO 清理（低风险）                         ✅ 2026-06-24
   │
后续 3 ─ D 节：保留 main/release（priv-app 不走 debug 构建）        ✅ 2026-06-24
   │
后续 4 ─ G 节审计文档勾选同步 + ModbusControlField1Bit 复核          ✅ 2026-06-24
   │
后续 5 ─ library 用法审计（不删 vendored 库内类）                        ✅ 2026-06-24
   │
Wave 5 ─ R8 minify/shrinkResources（曾试 ~88 MB APK）→ **已回退**（JNI/Modbus/FrostUI）  ↩ 2026-06-24
   │
后续 6 ─ 删除 dead WebView/ECharts assets（~3 MB）+ `WebViewAndEntity`     ✅ 2026-06-25
```

### 后续任务明细

| # | 任务 | 风险 | 状态 |
|---|------|------|------|
| 1 | **Gradle 去重**：`appcompat`/`activity` 重复声明；移除 app 侧 legacy `appcompat-v7` / support `constraint-layout` | 低 | ✅ 2026-06-24 |
| 1b | **library 用法审计**：确认 app 仍用 `EasyPlayerClient`；**不删** vendored 库内类 | 低 | ✅ 2026-06-24 |
| 1c | ~~library 库内删类~~ | — | ❌ 取消（vendored 第三方不删库内代码） |
| 2 | F 节：`LaserApplication` OkDownload 注释、`SplashActivity` Dev 跳转、`EngineerModeActivity` 等 TODO | 低 | ✅ 2026-06-24 |
| 3 | D 节：`DevActivity` / `Demo*Receiver` / `AiUploadFailureSampleHook` — **保留 release**（priv-app 权限约束，不迁 debug） | 产品决策 | ✅ 2026-06-24 |
| 4 | G 节表格与 Wave 1–3 结论同步；`ModbusControlField1Bit` 零引用已删 | 低 | ✅ 2026-06-24 |
| — | Wave 4 阶段 2：`ProcessParametersData` / `DeviceStatus` / `WarnInfo` deprecated 字段 + Room migration | 高（硬件） | ⏸ |
| 5 | Wave 5：R8 `minifyEnabled` + `shrinkResources` | 中 | ↩ **已回退**（2026-06-24）；release 保持无 R8 |
| — | C 节：`OSSManger` → `ObjectStorageUrls` | 低优先级 | ✅ 2026-06-24 |

**Wave 1 验证命令：**

```bash
./gradlew :app:assembleDebug
ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync
```

---

## I. 仍活跃、勿删（审计中易混淆）

| 组件 | 说明 |
|------|------|
| `MPAndroidChart` | `ContinuousWeldingLineChart`、`WorkInfoFragment` PieChart 等仍用 |
| `BlurView` / `BlurUtils` | FrostUI + QuickMode 模糊仍用 |
| `EasyFloat` | 工程师/快速模式相机浮窗 |
| `SmartRefreshLayout` | `ProcessVideoFragment` 等 |
| `XUI MaterialDialog` / `MiniLoadingDialog` | DevActivity、LoadingUtils 等仍用 |
| `bean/push/ServerPushEnvelope` 等 | WebSocket 推送 JSON 信封（wire 字段名不变） |
| Room migrations `Migration_*` | 历史 schema，不可删 |
| `modbus4j` / `library` 模块 | 核心依赖 |

---

## 变更记录

| 日期 | 说明 |
|------|------|
| 2026-06-24 | 初版：静态扫描 + 人工复核 |
| 2026-06-24 | 移除阿里云 OSS SDK；工艺视频上传统一 R2 STS |
| 2026-06-24 | Wave 1：删除 A.1/A.5/A.6/A.7/A.8 共 31 个源文件 |
| 2026-06-24 | Wave 2：删除 ECharts + AgentWeb 栈，移除 4 项 Gradle 依赖 |
| 2026-06-24 | Wave 3：Room v51 删除 `t_device_test`/`t_work_info`；清理 test bean 与 WorkInfo 层 |
| 2026-06-24 | Wave 4 阶段 1：移除零调用 `@Deprecated` API；清理 DefaultValueUtils/Gradle 注释；Modbus 间隔统一 |
| 2026-06-24 | 后续 1：Gradle 依赖去重；~~删 library `EasyPlayer`~~（后按 vendored 原则恢复） |
| 2026-06-24 | 后续 2：F 节注释死代码清理（LaserApplication/Splash/Modbus 等） |
| 2026-06-24 | 后续 3：D 节保留 main/release（priv-app 不走 debug 构建） |
| 2026-06-24 | 后续 4：G 节 31 项人工结论同步；删除零引用 `ModbusControlField1Bit` |
| 2026-06-24 | Wave 5（试验）：release R8 + shrinkResources；APK ~88 MB（-35%）；关闭 multidex |
| 2026-06-24 | Wave 5 fix（试验）：ProGuard keep `NativeBridge` JNI listener；`keep.xml` FrostUI；commons-logging 早期 init |
| 2026-06-24 | Wave 5 **回退**：关闭 R8/shrinkResources；恢复 multidex；真机 Modbus/JNI/FrostUI 稳定性优先于 APK 体积 |
| 2026-06-24 | C 节：`OSSManger` 重命名为 `ObjectStorageUrls` |
| 2026-06-24 | 后续 5：library **用法**审计；确立 vendored 库不删内类；恢复 `EasyPlayer` 等 |
| 2026-06-25 | 后续 6：删除 dead WebView/ECharts assets（`echarts/`、`index.*`、`vue.js`、`chartTemplate`、`lod.html`）与 `WebViewAndEntity` |
