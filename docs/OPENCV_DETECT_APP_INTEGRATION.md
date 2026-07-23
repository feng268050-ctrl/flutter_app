# OpenCV Detect — App 完整集成流程

本文定义 **OpenCV detect**（`nativeOpencv*` JNI）从 native 到 App 业务层的通用六层 checklist。  
除非 PR 明确标注 **「仅 native」**，OpenCV detect 相关改动默认需要走 **六层全检** 并用 **`make sync`** 部署。

**相关**

- RKNN 污渍检测（生产路径）：[`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md) — `AiManager` + `nativeRknnStainDetectFrom*`
- Native API：`native/lensinspector/docs/OPENCV_STAIN_DETECT_NATIVE_API.md`、`native/lensinspector/docs/ZERO_POINT_NATIVE_API.md`
- 参考实现（全链路）：`ZeroPointDetectCoordinator`（激光 ON 零点检测）
- 反例（仅 Layer 1–2）：`nativeOpencvStainDetectFrom*`（OpenCV stain detect，JNI 已声明、无 Coordinator）

---

## 1. 为何 `make ai` + `make sync-ai` 不够改 Java

| 命令 | 更新内容 | 是否更新 APK/DEX |
|------|----------|------------------|
| `make ai` | 编译 `lws_ai_daemon` → `jniLibs/liblws_ai_daemon.so`（+ 运行时 so） | 否 |
| `make sync-ai` | push AI `.so` 到设备 `nativeLibraryDir` 并重启 App（daemon `+x`） | **否**（不 reinstall APK） |
| **`make sync`** | Gradle 编译 Java/assets + 安装 APK + 启动 | **是** |

半集成典型症状：设备 daemon 已是新二进制，但 DEX 仍是旧 IPC/API → 行为对不上。

**默认规则：涉及 Java / 协议 / assets → `make sync`。**  
仅当 **只改 C++ daemon/算法且 App 接口不变** 时，才用 `make ai && make sync-ai` 快速迭代。

> 旧名 `make sync-native` 已 deprecated，会转发到 `make sync-ai`。

---

## 2. 模块现状

| 模块 | Native + JNI | `NativeBridge` | Parser | Coordinator | 部署 |
|------|-------------|----------------|--------|-------------|------|
| **zero_point** | ✅ | ✅ | `ZeroPointDetectJson` | `ZeroPointDetectCoordinator` | `make sync` |
| **lens_det** | ✅ | ✅ | `LensDetDetectJson` / `LensDetDetectResult` | `LensDetDetectCoordinator` | `make sync`（`ENABLE_LENS_DET_APP=true` 启用） |

**工艺视频离线 Detect**（200ms 网格）：走 `ProcessVideoAiSession` + `opencvStainDetectFromNv12`（`source=offline_stain_detect` / process video），采样帧经 `Nv12FrameUtil.fromBitmap` → `nativeOpencvStainDetectFromNv12`（与 live `StreamDetectPipeline` 同色 `nv12ToBgr` 路径）。结果写入 timeline `lensDet` 与 SSE `running.lensDet`。**不**在工艺视频路径调用 `zero_point`。

| **RKNN 污点** | `ENABLE_RKNN_STAIN_APP`（**默认 false**） | `rknnStainDetectFromNv12` / `FromRgb` / `FromJpg`；产线/污点需 `-PENABLE_RKNN_STAIN_APP=true` |

验收（仅 lens_det）：`-PENABLE_LENS_DET_APP=true`（RKNN 默认关）。验收（RKNN+污点）：再加 `-PENABLE_RKNN_STAIN_APP=true`。

| 能力 | Handle | 配置 |
|------|--------|------|
| opencv_stain_detect | 独立 `opencvStainDetectHandle`（`nativeCreateOpencvStainDetectSession`） | `config.yaml` → `opencv_stain_detect:`（`fixed_roi` + `preprocess`；**无蓝线有效带**） |
| zero_point | 独立 `zpHandle` | `assets/zero_point_roi.json` → `files/lens_guard/` |

### 模拟器验收（lens_det 离线）

- **ABI**：arm64-v8a AVD（如 `sdk_phone_arm64`）
- **构建**：`-PENABLE_LENS_DET_APP=true`（RKNN 保持默认关）
- **部署**：`make sync`（JNI 变更须重装 APK）
- **启动**：`AiManager.start()` 在模拟器上 deploy `config.yaml` 并创建 `ldHandle`；`isRunning()==false`，`isLensDetAvailable()==true`
- **工艺视频**：本地上传工艺视频 → AI Vision **Detect** → logcat `process_video_lens_det sample_ok/sample_fail`

**OpenCV stain detect native 管线（2026-06）**：原图直接裁固定 ROI `650,100` 尺寸 `500×500`（不遮 OSD）→ 亮度增强 → 黑白反转 → 二值化 → 开运算去噪 → ROI 内全局 `9×9` 腐蚀 1 次 → 动态椭圆腐蚀（最多 5 次，连通域 ≥2 停止）。坐标写回全图。离线批测：`scripts/opencv_stain_detect_batch_images.sh`（`opencv_stain_detect_infer` CLI）。

---

## 3. 六层集成 checklist

新模块或改 OpenCV detect 时，在 OpenSpec `tasks.md` 中按层打勾。

### Layer 1 — Native 契约（C++ / JNI）

- [ ] 算法 + JSON 输出（成功/失败可区分：`ok` / `code`）
- [ ] `native/lensinspector/src/<module>/` + `*_jni.cpp`
- [ ] JNI 符号：`Java_com_lasercyber_lws_ai_NativeBridge_<methodName>`
- [ ] 更新 `native/lensinspector/docs/<MODULE>_NATIVE_API.md`
- [ ] 若增删 JNI 名：更新 `native/lensinspector/scripts/verify_libai_jni.sh` 的 `REQUIRED` 数组
- [ ] `make ai` 后运行：`bash native/lensinspector/scripts/verify_libai_jni.sh app/src/main/jniLibs/arm64-v8a/libai.so`

### Layer 2 — Java JNI 声明

- [ ] `app/src/main/java/com/lasercyber/lws/ai/NativeBridge.java` 增加/修改 `public static native ...`
- [ ] Java 方法名与 native 导出 **完全一致**
- [ ] 命名：OpenCV 路径用 `nativeOpencv*`；RKNN 用 `nativeRknnStainDetect*`
- [ ] 视需要增加 `guarded*`（线程、模拟器、trace）；zero_point 当前直接调 native

### Layer 3 — 返回解析与领域类型

- [ ] 新增 `*Json.java` 或 `*Result.java`（参考 `ZeroPointDetectJson`）
- [ ] lens_det：summary JSON 仅含文件路径；坐标在 `outputDir/target.json`，需二次读文件
- [ ] 单元测试：fixture JSON 纯 Java 解析（参考 `ZeroPointCorrectionMapperTest`）

### Layer 4 — Coordinator（业务编排）

- [ ] 单例或 app-scoped `*Coordinator`：`attach` / `detach`
- [ ] 触发：如 `MemoryCacheManager` + `DeviceStatus`（激光 OFF→ON）
- [ ] 调度：`Handler` deadline 或 `AiFrameSamplingGate`
- [ ] 帧源：**live native** → `StreamDetectResultBus`（`NativeStreamDetectCoordinator`）；Manual Auto → native holder + bus
- [ ] 专用单线程 executor；**禁止** Modbus/UI 线程调 native
- [ ] 与 RKNN 并发：`AiManager.isStainInferBusy()` 时 defer/skip
- [ ] 独立 log TAG（如 `ZeroPointDetect`）

PR1 前置：`AiManager.isRunning() && laserOn`，工程师/快速模式需 `ProductionInferenceStreamCoordinator.attach()`。

### Layer 5 — 副作用与 UI

- [ ] DB / Modbus / EventBus / 设置页（如 `ZeroPointCorrectionWriter`）
- [ ] 若无自动副作用：结构化日志 + 可选 debug 入口

### Layer 6 — 启动 wiring 与资源

- [ ] `LaserApplication.initSerialPort()` 或 Activity 内 `Coordinator.attach()`
- [ ] `AssetDeployer.deployAssetIfChanged` 部署 JSON/YAML
- [ ] `make ai` 同步 `config.yaml` → `app/src/main/assets/config.yaml`

---

## 4. 新模块落地模板（Layer 2–6 文件清单）

按模块名 `<Module>`（snake_case，如 `zero_point`、`lens_det`）：

| 层 | 建议文件 / 位置 |
|----|----------------|
| L2 | `NativeBridge.java` — `nativeOpencv<Module>...` |
| L3 | `<Module>PascalCase>Json.java` 或 `Result.java` |
| L3 | `app/src/test/java/.../<Module>JsonTest.java` |
| L4 | `<Module>PascalCase>Coordinator.java` |
| L4 | （可选）`<Module>PascalCase>TaskSchedule.java` |
| L5 | `<Module>PascalCase>Writer.java` 或 EventBus 订阅方 |
| L6 | `LaserApplication.java` — attach/detach |
| L6 | `app/src/main/assets/<config>.json` 或 `config.yaml` 段 |
| L6 | 工程师/快速模式：若依赖 PR1，确认 Activity 已 attach `ProductionInferenceStreamCoordinator` |

OpenSpec 建议目录：`openspec/changes/<change-name>/` — `proposal.md`（含 App+Native 范围）→ `design.md` → `tasks.md`（逐层 checkbox）。

---

## 5. 构建与部署决策

```
改了什么?
├─ 仅 C++ daemon/算法且 App 接口不变 → make ai && make sync-ai
├─ Java / IPC / Coordinator / assets → make sync（必须）
└─ 首次集成或不确定                 → make sync
```

本地验收（不装设备）：

```bash
make ai
# host/tests: verify optional libai build artifact (not packaged in product APK)
bash native/lensinspector/scripts/verify_libai_jni.sh native/lensinspector/build_android/libai.so
make build
bash scripts/ci/verify-opencv-detect-integration.sh app/build/outputs/apk/release/app-release.apk
```

设备部署：

```bash
make sync                  # 默认：Java + native + assets 一并安装
# 或
make ai && make sync-ai    # 仅 AI daemon / 运行时 .so 变更时
```

---

## 6. 验收清单

### 6.1 符号对齐

```bash
bash native/lensinspector/scripts/verify_libai_jni.sh app/src/main/jniLibs/arm64-v8a/libai.so
bash scripts/ci/verify-opencv-detect-integration.sh /path/to/app.apk
```

APK DEX 应含新 JNI 名，**不应**残留已废弃名（如 `nativeCreateZeroPointDetector`）。

### 6.2 启动 logcat

```bash
adb logcat -c
adb logcat -v time -s ZeroPointDetect:I ZeroPointCorrection:I AiManager:I application:I EasyPlayerClientManger:I
```

重启 App 期望：

- `ZeroPointDetect: attached roi=...`
- `AiManager: Engine started`
- `startup_phase=lens_guard, outcome=ok, reason=engine_started`

进入工程师模式：

- `Production inference coordinator attached`
- `INFER_RTSP ... engine=true`（激光 ON 时）

### 6.3 触发 logcat（zero_point 样板）

先关激光再开（PR1 子码流需已 attach）：

- `ZeroPointDetect: task_start eventId=... sampling=pr1_continuous`
- 首帧 PR1 后即可 `sample_ok`（不必等 500ms）；激光 ON 期间约每 **500ms** 持续采样
- `ZeroPointDetect: detect_result module=zero_point code=... reason=...`（失败；`code=-5` 触发 `LaserDetectSampling: mode=burst`）
- **激光 OFF** 时：`cluster_reduce` → `task_done`（聚类归约后决定是否弹窗）
- `LaserDetectSampling: mode=burst` / `mode=normal restored`（任一模块 `code=-5` 后 100ms 抽帧，双 `code=0` 恢复 500ms）
- 激光 OFF 后零点偏移弹窗出现；点击“去设置”进入设置页，再点 Zero Offset Auto 后出现 `ZeroPointManualAuto: manual_auto pending_json_apply ...`，随后 `ZeroPointCorrection: zero_point applied ...` 或 `skip_write ...`

### 6.4 触发 logcat（lens_det，需 `ENABLE_LENS_DET_APP=true` 构建）

工程师/快速模式，激光 ON，PR1 流已 attach：

```bash
adb logcat -v time -s LensDetDetect:I AiManager:I
```

期望：

- `LensDetDetect: attached enabled=true`
- 约每 **500ms**（`LIVE_WELD`）：`OpencvStainDetect: sample_ok x=... y=...` 或 `detect_result module=lens_det code=... reason=...`（饱和帧 `code=-5` 进入 burst 100ms）

AI Vision 直播（同 flag）：overlay 显示 `lens_det @ x,y` 标签；live 结果来自 `StreamDetectResultBus`（C++ **MPP → NV12** 检测链），非 Java 传帧。

部署：`./gradlew assembleDebug -PENABLE_LENS_DET_APP=true` 或 `make sync` 前在 `local.properties` 设 `ENABLE_LENS_DET_APP=true`。

### 6.5 测试

- 单元测试：JSON 解析、UI/Modbus 映射
- androidTest smoke：参考 `DetOnlyOpenSpecDeviceTest`

### 6.6 zero_point mock JSON（staging 联调）

**仅非 release channel**（`BuildConfig.RELEASE_CHANNEL=false`）生效；`make build RELEASE=1` 会忽略 mock 文件。

| 项 | 值 |
|----|-----|
| 路径 | `/sdcard/lws_debug/zero_point_mock.json` |
| 格式 | 与 native 一致：`{"ok":true,"code":0,"offset_x":-9.0,"offset_y":0.0}` |

```bash
adb shell mkdir -p /sdcard/lws_debug
adb push zero_point_mock.json /sdcard/lws_debug/zero_point_mock.json

adb logcat -v time -s ZeroPointMock:I ZeroPointDetect:I ZeroPointManualAuto:I ZeroPointCorrection:I
```

期望：`ZeroPointMock: mock_hit path=... offset_x=...`；产线检测阶段记录 `pending_manual_auto=true`，设置页 Auto 消费 pending JSON 后记录 `ZeroPointCorrection: zero_point applied ...` 或 `skip_write=within_tolerance`。

**产线零点偏移提醒**（`ZeroPointDetectCoordinator`）：快速/工程师 + 连续焊/点焊，激光关→开，mock 存在时可不依赖 PR1 native 解码帧；检测到超容差偏移时只缓存 `production_json` pending 结果并触发激光 OFF 后弹窗，不直接写 Zero Offset。

**Manual Auto 方法一**：弹窗“去设置”后，高级设置 → Zero Offset → Auto，优先消费 pending `production_json` 并按其中 `offset_x/offset_y` 自动校正。

**Manual Auto 方法一（跳过激光联调）**：push pending JSON 后，高级设置 → Zero Offset → Auto 会在点击时自动注入 pending 并走方法一（无需激光 OFF→ON→OFF、无需产线弹窗）。

| 项 | 值 |
|----|-----|
| 路径 | `/sdcard/lws_debug/zero_point_pending.json` |
| 格式 | `{"valid_samples":4,"offset_x":-9.0,"offset_y":0.0}`（`valid_samples` 可省略，默认 1） |

```bash
adb shell mkdir -p /sdcard/lws_debug
adb push zero_point_pending.json /sdcard/lws_debug/zero_point_pending.json

adb logcat -v time -s ZeroPointPending:I ZeroPointManualAuto:I ZeroPointCorrection:I
```

期望：`ZeroPointPending: pending_hydrated ...`；随后 `ZeroPointManualAuto: manual_auto pending_json_apply ...` 与 `ZeroPointCorrection: zero_point applied ...`。注入成功后文件会被删除，需重新 push 才能再测。

**Manual Auto 方法二**：没有 pending JSON 时，高级设置 → Zero Offset → Auto；用户在设置页将枪头对准安全区域并按住扳机后点击 Auto，App 先按最近一次连续焊/点焊上下文下发设备控制、工艺参数和高级设置（测试脉冲 **Zero Offset=0**），再录临时视频并通过 Modbus 写 `laserStatus=1` 临时开启激光使能。物理出光仍由扳机触发；**15 秒**使能窗口内没有检测到真实 `DeviceStatus.isLaserOn()`，本次 Auto 失败并删除临时视频，提示「校正失败请再次点击 Auto 或者手动校正」。检测到真实出光后，App 自动写同一控制上下文的 `laserStatus=0` 关闭使能，再用在线/离线阶段结果将 Zero Offset **设为** `round(-offset_x/3)`（零档位标定的绝对值，不在 DB 现值上再累加）。在线/离线均无有效样本时同样提示上述失败文案。mock 存在时在线/离线阶段均读同一文件。

测完删除 mock / pending：

```bash
adb shell rm -f /sdcard/lws_debug/zero_point_mock.json
adb shell rm -f /sdcard/lws_debug/zero_point_pending.json
```

---

## 7. 与 RKNN 路径的关系

- **生产污渍**：`AiManager` + `nativeRknnStainDetectFrom*`
- **OpenCV detect**：独立 JNI；不混入 RKNN session
- 配置目录共用 `files/lens_guard/`；handle 生命周期各自管理
- 并发：zero_point 在 `isStainInferBusy()` 时 skip 样本

---

## 8. 维护：新增 JNI 时同步改动的文件

1. `native/lensinspector/src/*_jni.cpp`
2. `native/lensinspector/docs/*_NATIVE_API.md`
3. `native/lensinspector/scripts/verify_libai_jni.sh` — `REQUIRED` 数组
4. `app/.../NativeBridge.java`
5. 本文档 §3 checklist + OpenSpec tasks
6. `scripts/ci/verify-opencv-detect-integration.sh` — `DEX_REQUIRED`（若 App 必须引用该符号）

---

## 9. Live RTSP — `StreamDetectPipeline`（Pub-Sub，非 YUV JNI）

自 **native-stream-detect-pipeline** change 起，**产线 live PR1** 检测默认走 C++ 独立拉流 + **Rockchip MPP 硬解 → NV12**，**不再**经 Java 解码回调或 YUV JNI。

| 层 | Live weld / AI Vision native 路径 |
|----|-----------------------------------|
| L1 Native | `native/lensinspector/src/stream_detect/` + `stream_detect_jni.cpp`；解码 backend 目标：**MPP → NV12**（见 [`MPP.md`](MPP.md)） |
| L2 JNI | `NativeBridge.nativeStartStreamDetect` / `nativeConfigureStreamDetect` / `nativeSetStreamDetectListener` |
| L3 解析 | `StreamDetectEvent.*` + `OpencvStainDetectResultMapper.fromNativeSummary` |
| L4 编排 | `NativeStreamDetectCoordinator`（holders: `weld`, `ai_vision`）；Coordinator **订阅** `StreamDetectResultBus`，不持帧 |
| L5 UI / SSE | `StreamDetectOverlayBridge` → overlay；`CameraAiHttpPublisher` → SSE |
| L6 启动 | `CameraConfig.isNativeWeldStreamDetectEnabled()` / `isNativeAiVisionStreamDetectEnabled()`；Quick/Engineer 激光 ON → weld holder；AI Vision `VIDEO_DISPLAYED` → ai_vision holder |

**播放（Java，独立链路）：** `EasyPlayerClient` + **Android `MediaCodec` 硬解** → Surface/TextureView；**不参与**检测解码。

**Feature flags**

| Flag | Default | Notes |
|------|---------|-------|
| `isNativeWeldStreamDetectEnabled()` | **true** (Phase 4) | Weld always native; Java PR1 client removed |
| `isNativeAiVisionStreamDetectEnabled()` | false | Dual-link; 4.4 fallback when false |

**与 §3 六层的关系：** 新 live 模块走 **Pub-Sub** checklist（上表），不是逐帧 YUV JNI。离线工艺视频（`ProcessVideoAiSession`）走 §3 六层 + **`opencvStainDetectFromNv12`**（`Nv12FrameUtil` → `nativeOpencvStainDetectFromNv12`）。**I420 已遗弃**，全栈 YUV 契约为 **NV12**。

**验收文档：**

- C++ PR1 验收：OpenSpec `notes/stream-detect-pipeline-acceptance.md`
- 双链路压测：`notes/ai-vision-dual-link-checklist.md`
- Live 路径审计：`notes/live-detect-path-audit.md`
- 架构：[`MPP.md`](MPP.md)、[`Native Stream Detection Pipeline.md`](Native%20Stream%20Detection%20Pipeline.md)

**部署：** JNI / Coordinator / flag 变更 → **`make sync`**（与 §1 相同）。
