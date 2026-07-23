# Lens Guard / libai.so — App 对接总览

Android App 消费 YOLO 交付的 **`lens_guard_engine_<version>.zip`**，固定加载 **`libai.so`**（`System.loadLibrary("ai")`）。本文合并原 `APP_INTEGRATION_GUIDE`、`APP_ANOMALY_ASSIST_INTEGRATION`、`CLS_READONLY_JNI_INTEGRATION`、`LENS_DIRTY_ALERT_RULES` 的 App 侧约定；构建与源码结构见仓库根 **`README.md`**。

**相关**

- **det-only 模式（cls 关闭）App 对接**：[`DET_ONLY_APP_INTEGRATION.md`](DET_ONLY_APP_INTEGRATION.md)
- 分类只读 JNI 的 YOLO 需求摘要：[`CLS_READONLY_JNI_YOLO_REQUIREMENTS.md`](CLS_READONLY_JNI_YOLO_REQUIREMENTS.md)
- **AI Vision 预览 + 离线单图**：[`AI_VISION_NATIVE_OFFLINE_INFERENCE_CONTRACT.md`](AI_VISION_NATIVE_OFFLINE_INFERENCE_CONTRACT.md)
- cls/det 调度（native 内，与 App 只读 JNI 正交）：`lensinspector` 仓库 **`cls-det-scheduling.md`**
- **OpenCV detect 完整 App 集成流程**（zero_point / lens_det）：[`OPENCV_DETECT_APP_INTEGRATION.md`](OPENCV_DETECT_APP_INTEGRATION.md)

---

## 1. 交付物与工程布局

ZIP 示例：`lens_guard_engine_v1.0.0.zip`

```text
├── assets/config.yaml
└── jniLibs/arm64-v8a/
    ├── libai.so
    ├── libc++_shared.so
    └── librknnrt.so
```

合并到 `app/src/main/`。**`NativeBridge.java` 等 Java 由本仓库维护**（`com.lasercyber.lws.ai`），不再随 ZIP 提供。历史包名 `com.lasercyber.lws.ui.lensinspector` 已废弃。

| 类 | 职责 |
|----|------|
| `NativeBridge` | JNI 声明与 `guarded*` 封装 |
| `AiManager` | 生命周期、监听转发、EventBus（原 `LensGuardManager`） |
| `AssetDeployer` | 将 `config.yaml` 解压到 `files/lens_guard` |
| `AiLibraryDirectory` | 解析 APK `nativeLibraryDir`（`make ai` 产物） |
| `AiNativeRuntime` | 模拟器上禁止 RKNN 会话/推理（见 §2.1） |

---

## 2. 加载 native 与 RKNN / BSP

```java
static {
    System.loadLibrary("c++_shared");
    System.loadLibrary("rknnrt");
    System.loadLibrary("ai");
}
```

`librknnrt.so` 须与设备 **BSP NPU 驱动** 匹配，否则可能在 `rknn_init` 附近崩溃。

- **APK 内置**：`make ai` → `app/src/main/jniLibs/arm64-v8a/`，安装后由 `NativeBridge.ensureLoaded` 从 `nativeLibraryDir` 按绝对路径 `System.load`（顺序：`libc++_shared` → `librknnrt` → `libai`）。
- **旧 BSP**：`local.properties` 设置 `ai.library.variant=legacy` 时，须使用与该变体联编的 `librknnrt.so`（与 `libai.so` 同一构建矩阵）。

### 2.1 Android 模拟器（libs-only，无 RKNN 会话）

AVD **无 Rockchip NPU**。`libai.so` 与 `librknnrt.so` 可以 `dlopen` 成功，但 **`nativeCreate` 会在 `librknnrt.so` 内 SIGBUS**（无效函数指针，典型 `pc=0x1`）。

| 阶段 | 模拟器 | 真机 |
|------|--------|------|
| `NativeBridge.ensureLoaded` | ✅ 加载三件套并校验 typed JNI | ✅ 同上 |
| `nativeCreate` / `nativeStart` / 推帧与推理 | ❌ **不调用**（`AiNativeRuntime.blocksRknnSession()`） | ✅ 正常 |
| `LensGuardManager.start()` | ✅ 返回 `true`（libs-only）；`isRunning()` 为 **`false`** | ✅ `isRunning()` 为 `true` |
| lens_det（`ENABLE_LENS_DET_APP=true`） | ✅ `isLensDetAvailable()==true`（独立 `ldHandle`，OpenCV CPU） | ✅ 同上 |
| RKNN 离线/实时推理 API | 返回 App 层错误（如 `RKNN inference unavailable on emulator (no Rockchip NPU)`） | 正常 |
| lens_det 离线/实时（flag 开） | AI Vision 工艺视频 / live 可走 `inferLensDetFromI420` | 正常 |

**logcat 验收（冷启动）：**

```text
NativeBridge: System.load ... libai.so
LensGuardJNI: JNI_OnLoad: libai loaded
LensGuardManager: Emulator: native libraries loaded; skipping RKNN engine session — ...
application: startup_phase=lens_guard, outcome=ok, reason=emulator_libs_only_no_npu
```

**实现要点：** `com.lasercyber.lws.ai.AiNativeRuntime`（`AndroidEmulatorUtils.isLikelyEmulator()`）；`NativeBridge.guarded*` 在模拟器上短路；`DISABLE_LENS_GUARD=true` 仍会完全跳过 `initLensGuard`（连 so 也不加载）。Instrumentation 测试仍跳过引擎初始化，避免 RKNN SIGBUS 干扰用例。

**ABI：** 工程仅打包 `arm64-v8a`；请使用 **arm64 系统镜像** 的 AVD（如 `sdk_phone_arm64`），不要用 x86_64 镜像指望加载 `libai.so`。

---

## 3. 运行时目录与配置

`assets/config.yaml` 须复制到可读写路径再传给 JNI。

```text
/data/data/<package>/files/lens_guard/
├── config.yaml
├── clean_ref/<sn>/base|dynamic
├── clean_candidate/<sn>/
├── hardcase/false_positive|false_negative/
└── debug_data/
```

- **base**：人工确认干净图 3~10 张，按 **sn** 隔离  
- **dynamic**：引擎双门控通过后维护，App 勿覆盖  
- **hardcase / debug_data**：引擎写入，App 可做容量或上传巡检  

`nativeCreate(configPath, projectRoot)`：`configPath` 为上述 `config.yaml` 绝对路径；`projectRoot` 为 `lens_guard` 根目录。

**前提**：定焦相机；推帧 **全分辨率 I420**（`data.length = width * height * 3 / 2`）。产线标定 **1920×1080**；App 侧建议 **≥ 1265×810**（覆盖引擎固定 ROI 700×700 @(565,110)）。App **不得**对全帧做 letterbox/拉伸/中心裁 640 再 `nativePushFrame`；污点 det 在 native 内 **ROI 700→resize 640**，回调 `boxes` 为**整帧像素**（overlay 直接画全图，禁止 App 侧 `×700/640` 或偏移换算）。Mask 圆心固定 **(885,430)** @1080p。详见 [`LENS_GUARD_ROI640_ALIGNMENT.md`](LENS_GUARD_ROI640_ALIGNMENT.md)、[`LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`](../LENS_GUARD_APP_ALIGNMENT_2026-05-19.md) 与引擎 `APP_ALIGNMENT_BRIEF.md`（2026-05-22）。

---

## 4. JNI 生命周期（基础）

| 顺序 | 接口 |
|------|------|
| 1 | `nativeCreate(configPath, projectRoot)` |
| 2 | `nativeSetListener(handle, listener)` |
| 3 | `nativeSetDeviceContext(handle, sn, stationId)`（建议一次） |
| 4 | `nativeNotifyModelSwitched(handle, modelVersion)`（初始 + 切换时） |
| 5 | `nativeStart(handle)` |
| 运行 | 每帧：`nativePushFrameMeta` → `nativePushFrame`；激光变化：`nativeSetLaserOn`；参数 **5~10Hz**：`nativePushCameraParams` |
| 6 | `nativeStop` → `nativeDestroy` |

**查询**：`nativeGetState`（0=IDLE, 1=MONITORING, 2=LOCKED）、`nativeGetStainLevel`、`nativeIsLensDirty`。

**帧来源**：解码回调（如 `EasyPlayerClient.onI420Data`）。回调可能在 native 工作线程，**UI 须切主线程**。

未接扩展接口时引擎仍可运行（亮度门控）；接入后参数风险、freeze、追溯更稳。

---

## 5. 异常辅助（anomaly assist）

在 YOLO + 参考图 + 时序 + 双门控 + 冻结保护方案下，除 §4 外建议上报：

| 数据 | 接口 / 说明 |
|------|-------------|
| 曝光 / 增益 / 补光 / fps | `nativePushCameraParams` |
| 时间戳 / frameId | `nativePushFrameMeta` |
| 模型切换 | `nativeNotifyModelSwitched` |
| sn / 工位 | `nativeSetDeviceContext` |

**config.yaml（`anomaly_assist`）**：`enabled`、`observe_only`、FN/FP 阈值、`roi_*`、双门控与时序、`dynamic_capacity`、freeze 等。灰度建议先 **`observe_only=true`**（只观测不落盘）。

**联调验收要点**：稳定 1280×720 推帧；激光状态一致；`hardcase` 可落盘；`clean_ref/.../base` 有效；日志可见 suspected FP/FN；模型切换后 freeze 生效。

**性能基准包（MVP）**：`timeline/laser_timeline.csv`、`model_events.csv`、`frame_timeline.csv`（至少 `frame_id,timestamp_ms,width,height`）、`camera_params.csv`（有源则报）、最小 `manifest.json`。`frames/*.i420bin` 与 `offset_bytes/length_bytes` 当前 **Not Supported**，勿作 App 必达项。

---

## 6. 脏污检测（det）— 规则与 UI

规则在 **`lensinspector` native** 计算（`rknn_stain_detect_pp.cpp`、`main.cpp`、`config.yaml`），App **不重算**等级。

### 6.1 回调语义

`NativeBridge.NativeListener.onCheckResult(int level, String status, String message)`

| level | status | App 展示建议 |
|-------|--------|----------------|
| 0 | `CLEAN` | 正常 / 隐藏提示 |
| 1 | `MILD` | 轻度污染，建议擦拭 |
| 2 | `HEAVY` | 重度污染，立即清洗/更换 |

优先显示 **`message`**（如「建议擦拭」「立即更换 (核心区域命中)」）；`status` 作调试标签。**`level >= 2`** 视为脏污；native `isLensDirty()` 为 true，且可进入 **LOCKED**。

### 6.2 native 规则摘要

**单帧**：烧蚀类 → HEAVY；大面积 / mask 内缺陷 / core 命中 + 面积 / 帧总面积超阈值 → HEAVY 或 MILD。  
**窗口**：`any_core_hit` 或 level2 帧数 / 连续帧 / level1 帧数达阈值 → 聚合为 HEAVY 或 MILD。

默认阈值见 `config.yaml`（如 `stain_conf_thresh: 0.25`、`total_area_ratio_heavy: 0.05`、`level2_min_frames: 2` 等）。

### 6.3 App 落点

- **`LensGuardManager`**：`onCheckResult` → `LensCheckResultEvent`（EventBus），不在 Java 重算。  
- **`AiVisionFragment#onLensCheckResult`**（`MAIN`）：更新 **`tvAiResult`** + **`DetectionOverlayView`**（`message` 内 JSON 可解析检测框）。  
- **AI Vision Tab**：**不**弹 `LensDirtyAlertDialogCoordinator` 阻断弹窗（预览/演示为主）；**告警音**仍以 `level>=2` 时 native `onAlert` → `GlobalSoundManager` 为准。协调器类保留供其它界面复用。

处理顺序：保存原始 `level/status/message` → 按 `level` 更新 UI → `message` 空则用默认文案 → `level>=2` 告警样式/音效。

---

## 7. 分类（cls）— 只读 JNI

App **只读** native 已算好的分类结果，不重算阈值 / TopK。

### 7.1 接口

```java
String nativeGetLastClsResult(long handle);  // JSON 快照；无效时 valid=false
// 可选：nativeClearLastClsResult(handle)
```

示例字段：`valid`、`classId`、`className`（native 表：`0=其他`，`1=金属`）、`score`、`topk[]`、`timestampMs`、`modelVersion`、`source`（如 `focus_cls`）。

### 7.2 App 接入

- 增加 **CLS DTO** + JSON 解析；**勿**用 `classId` 覆盖 native 已给的 `className`（除非兜底）。  
- 读取时机：每帧后 / 定时轮询 / 进入分类面板时之一。  
- **禁止**把 cls JSON 塞进 `onCheckResult` 的 `message`。  
- 推荐与 det 对称：**`LensGuardManager` pull JNI → `LensClsSnapshotEvent`（独立 Event）→ `@Subscribe(MAIN)`**，勿与 `LensCheckResultEvent` 混用。

| 环节 | det（污点） | cls（只读） |
|------|-------------|-------------|
| 口径 | `onCheckResult` push | `nativeGetLastClsResult` pull |
| 转发 | `LensCheckResultEvent` | 独立 cls Event |
| UI | `onLensCheckResult` | 独立订阅，勿进污点状态机 |

调度（焊中跑 cls 还是 det、LOCKED 门控）属 native **`cls-det-scheduling.md`**，不由 App JNI 替代。

**基线**：仓库需 YOLO 交付 `nativeGetLastClsResult` 后按上表补齐 DTO/Event/UI。

---

## 8. 职责边界

| App 负责 | App 不负责 |
|----------|------------|
| 放置 ZIP、加载 `.so`、解压 config | CMake/NDK、CI 打包、模型嵌入 |
| 推帧、激光/参数/meta、读监听与只读 cls | 拼 R2 路径、脏污/分类规则重算 |
| UI / EventBus / 日志 | native 调度与推理实现 |

---

## 9. 代码与配置索引

| 路径 |
|------|
| `app/src/main/java/com/lasercyber/lws/ai/NativeBridge.java` |
| `app/src/main/java/com/lasercyber/lws/ai/LensGuardManager.java` |
| `app/src/main/java/com/lasercyber/lws/ai/LensGuardInferenceResult.java` |
| `app/src/main/java/com/lasercyber/lws/ai/LensGuardInferenceResultMapper.java` |
| `app/src/main/java/com/lasercyber/lws/ai/AssetDeployer.java` |
| `app/src/main/java/com/lasercyber/lws/ai/AiLibraryDirectory.java` |
| `app/src/main/java/com/lasercyber/lws/ui/activitys/device/monitor/fragment/AiVisionFragment.java` |
| `app/src/main/java/com/lasercyber/lws/ui/activitys/device/monitor/LensDirtyAlertDialogCoordinator.java` |
| `lensinspector/config.yaml`（引擎侧默认） |

---

## 10. AI Vision Tab（预览 + 离线单图）

完整契约：**[`AI_VISION_NATIVE_OFFLINE_INFERENCE_CONTRACT.md`](AI_VISION_NATIVE_OFFLINE_INFERENCE_CONTRACT.md)**。以下为 App 必做摘要。

### 10.1 与生产路径的区别

| | 生产（焊接/停机） | AI Vision 预览 |
|--|------------------|----------------|
| 分类 | 激光 **ON**，走聚焦状态机 | 激光 **OFF** + `setAiVisionPreviewClassificationEnabled(true)` → **只**更新 cls 缓存 |
| 污点 | 激光 **OFF**，焊后/周期检测，可 **LOCKED** | 激光 **OFF** + `setAiVisionPreviewDetectionEnabled(true)` → 约 2s 预览 det，**不** LOCKED、**不**改 `isLensDirty` |
| cls 结果 | 焊中同样更新快照（可选读） | **`guardedGetLastClsResult`** pull JSON |
| det 结果 | `onCheckResult` 纯文本/生产语义 | `message` 含 **`"source":"preview_det"`** 的 JSON + `boxes` |

### 10.2 Tab 生命周期（`LensGuardManager`）

1. 引擎已 **`nativeStart`** 且持续 **`nativePushFrame`**（与生产相同）。
2. **进入 AI Vision Tab**：按需 `setAiVisionPreviewClassificationEnabled(true)` / `setAiVisionPreviewDetectionEnabled(true)`。
3. **离开 Tab**：两项均 `false`。
4. **`nativeSetLaserOn`** 始终反映**真实**激光；新 lib 下勿长期依赖 legacy「假激光 ON」覆盖（仅旧 so 无 preview 符号时）。

### 10.3 分类 UI

- 轮询或节流调用 **`guardedGetLastClsResult`** → 独立 Event（如 `LensClsSnapshotEvent`）→ Fragment 更新文案。
- **`valid:false` 且 `timestampMs==0`**：尚未有过成功推理；确认 preview cls 已开且已推流。
- **禁止**从 `onCheckResult.message` 解析 cls。

### 10.4 预览污点 UI

- `LensGuardManager` 已提供 **`isPreviewDetMessage(message)`**；解析 `boxes` 画 overlay。
- 预览结果**不**走 `LensDirtyAlertDialogCoordinator` 生产阻断逻辑（§6.3）。

### 10.5 离线单张 JPG（遗留）

- **`inferJpgAndSaveResult(imagePath)`** → `guardedInferImageAndSave`（仍图文件路径）。
- **`inferFromJpg(path)`** 仅用于磁盘上已有的 JPG/相册/仪器测试；**工艺视频与 AI Vision 离线时间轴不再写临时 JPEG**。
- **`nativeCode == 0`** 仅表示管线成功；**CLEAN/HEAVY** 在 **`onCheckResult`** 或统一结果字段；App 还须校验输出文件非空。

### 10.6 统一推理 API（首选 `inferFromI420`）

| API | 用途 | 并发策略 |
|-----|------|----------|
| **`inferFromI420(data,w,h)`** | 生产 PR1、AI Vision live、工艺视频 `ProcessVideoAiSession`、离线 MP4 逐帧 fallback | 全局 in-flight：忙时 `code=CODE_INFER_BUSY`；等待 `onCheckResult`（超时约 8s） |
| `inferFromJpg(path)` | 遗留：磁盘 JPG 单帧 | 同上 |

- **I420 来源**：RTSP 解码器 `onI420Data` 直推；`TextureView` / `ProcessVideoAiSession`（`MediaMetadataRetriever`）抽帧经 **`I420FrameUtil.fromBitmap`**（ARGB→I420，无 JPEG 落盘）。
- **工艺录像 UX**：仅 **`ProcessVideoAiSession` + `ProcessVideoAiCompositedPreview`**（边播边推理边合成）；已删除未接线的批量 `analyzeSelectedVideoOffline` / `nativeInferVideoAndSave` App fallback。
- **Hold-forward**：录制视频与 live 预览在 infer 未完成时继续用上一次 `LensGuardInferenceResult` 合成画面；encode/显示 tick **不得**阻塞等待 infer。
- **生产 PR1**：`ProductionInferenceStreamCoordinator` 在激光 **OFF** 时 `stop("laser_off")` → 停止 RTSP、重置 `PRODUCTION_WELD` 采样门、清空 hold-forward 位图；激光 **ON** 再 `start`。
- **弃用**：`onI420Frame`、`inferJpgToJson` 仍保留兼容；新功能代码请 **`inferFromI420`**。
- **回滚**：`LensGuardManager.setUseUnifiedInference(false)` 时 `inferFromJpg` 回退解析 legacy JSON 字符串。

---

## 11. 常见问题

| 现象 | 可能原因 |
|------|----------|
| 有分数但不判 suspected FN | 未过 min_area / ROI / 时序 / 参数门控 |
| 疑似样本未保存 | `observe_only=true` |
| dynamic 不增长 | freeze 或双门控未通过 |
| `pm path` 为 `/data/app/...` | 被 Studio Run 普通安装覆盖，应 priv-app 或 Attach Debugger |
| RKNN 崩溃 | `librknnrt` 与 BSP 不匹配，换 `ai.library.variant` |
