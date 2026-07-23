## Why

AI Vision 工艺视频离线 lens_det 已接入 `ProcessVideoAiSession` + `inferLensDetFromI420`，但 **lens_det 仍绑定 RKNN 引擎 `handle`**。Android 模拟器上 `AiNativeRuntime.blocksRknnSession()` 会跳过 `nativeCreate`，导致 `handle == 0`、`isRunning() == false`，离线 session 无法创建、推理无法执行。开发者在模拟器上上传本地工艺视频后无法验收 lens_det 离线链路，只能依赖真机。

`zero_point` 已采用 **独立 `zpHandle`** + `AssetDeployer`，模拟器可加载 `libai.so` 并跑 OpenCV CPU 推理。应将 lens_det 对齐同一模式，使 **arm64 模拟器 + `ENABLE_LENS_DET_APP=true`** 可完成 AI Vision 离线推理（用户本地上传工艺视频）。

## What Changes

- **Native**：新增 `nativeCreateOpencvLensDetSession` / `nativeDestroyOpencvLensDetSession`；`nativeOpencvStainDetectFrom*` 第一个参数改为 **lens_det session handle**（`ldHandle`），从 deployed `config.yaml` 加载 `lens_det:` 配置，**不再**依赖 RKNN `AppConfig` handle。
- **Java `AiManager`**：维护独立 `lensDetHandle`；模拟器 `start()` 时 `AssetDeployer.deploy` + 创建 lens_det session；新增 `isLensDetAvailable()`；`inferLensDetFrom*` / 采样 gate 改用 `isLensDetAvailable()` 而非 `isRunning()`。
- **`ProcessVideoAiSession`**：lens_det-only 离线可用性与 `tryCreate` 检查 `isLensDetAvailable()`，不再要求 RKNN `isRunning()`。
- **`AiVisionFragment`**（可选 live）：lens_det live 采样 gate 使用 `isLensDetAvailable()`；RKNN live 仍要求 `isRunning()`。
- **`LensDetDetectCoordinator`**：产线 PR1 lens_det 采样 gate 同步改用 `isLensDetAvailable()`。
- **文档 / CI**：更新 `LENS_DET_NATIVE_API.md`、`OPENCV_DETECT_APP_INTEGRATION.md`、`verify_libai_jni.sh`；说明模拟器验收步骤（arm64 AVD、`ENABLE_LENS_DET_APP=true`、`make sync`、本地上传工艺视频）。
- **BREAKING**（JNI）：`nativeOpencvStainDetectFromJpg/Rgb/I420` 第一个 `long` 参数语义从 RKNN engine handle 改为 `ldHandle`；App 内所有调用点随 `AiManager` 迁移。

## Capabilities

### New Capabilities

- `lens-det-emulator-session`: 独立 OpenCV lens_det session 生命周期、模拟器离线可用性、与 zero_point 对齐的 deploy + create/destroy 契约。

### Modified Capabilities

- `lens-det-app-inference`: lens_det 推理与采样 gate 的可用性条件从 `AiManager.isRunning()` 改为 `isLensDetAvailable()`；JNI 使用独立 `ldHandle`。
- `lens-guard-capability-profile`: 模拟器 libs-only 启动下，在 `ENABLE_LENS_DET_APP=true` 时 lens_det 能力可为 true，且不要求 RKNN session。

## Impact

- **Native**: `lens_det_jni.cpp`（新建 session 类型）、`lens_det_options.*`、`verify_libai_jni.sh`、`LENS_DET_NATIVE_API.md`
- **Java**: `NativeBridge.java`, `AiManager.java`, `ProcessVideoAiSession.java`, `AiVisionFragment.java`, `LensDetDetectCoordinator.java`
- **构建**: `-PENABLE_LENS_DET_APP=true`；arm64-v8a AVD
- **部署**: JNI 签名变更 → **`make sync`**（不可仅 `sync-native`）
- **真机**: RKNN + lens_det 并存时行为不变（lens_det 走独立 session，RKNN 仍走 engine handle）
