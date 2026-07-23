## Context

- **现状**：`lens_det` OpenCV 推理通过 `nativeOpencvStainDetectFrom*` 实现，JNI 用 RKNN engine `handle` 经 `lens_app_config_from_handle` 读取 `config.yaml` → `lens_det:`。`AiManager.inferLensDetFromI420` 要求 `handle != 0`；`ProcessVideoAiSession` lens_det-only 时要求 `isRunning()`。
- **模拟器**：`AiManager.start()` 在 `blocksRknnSession()` 时仅 `ensureLoaded` 并返回，**不** deploy config、**不** 建 handle。AI Vision 工艺视频 Detect 报 `OFFLINE_JNI_UNAVAILABLE` / `ENGINE_NOT_RUNNING`。
- **参照**：`zero_point` 使用 `nativeCreateOpencvZeroPointDetector(roiJsonPath, tolerance)` → 独立 `zpHandle`，`ZeroPointDetectCoordinator` attach 时 `AssetDeployer.deploy` + create，与 RKNN 无关。
- **用户场景**：开发者在 **arm64 模拟器** 本地上传工艺视频，在 AI Vision 启动 Detect，验收 lens_det 500ms 离线推理、timeline / overlay / logcat。

## Goals / Non-Goals

**Goals:**

- lens_det 拥有与 zero_point 对称的 **独立 native session**（`ldHandle`），配置来自 deployed `config.yaml`。
- 模拟器上 `ENABLE_LENS_DET_APP=true` 时，`isLensDetAvailable() == true`，工艺视频 `ProcessVideoAiSession` 可创建并执行 `inferLensDetFromI420`。
- 真机 RK3566 行为保持：RKNN engine 与 lens_det session 可并存；lens_det 不再借用 RKNN handle。
- 更新 JNI 契约、文档与 `verify_libai_jni.sh`。

**Non-Goals:**

- 模拟器上启用 RKNN 污点推理（仍不可用，无 NPU）。
- lens_det OpenCV 算法或 `target.json` 输出格式变更。
- 工艺视频 zero_point 离线（仍仅生产 `ZeroPointDetectCoordinator`）。
- x86 模拟器 ABI（工程仅 arm64 JNI）。
- Mock JSON 注入 lens_det（可选后续；本变更做真实 OpenCV 推理）。

## Decisions

### 1. 独立 session API（对齐 zero_point）

**Decision:** 新增：

```text
nativeCreateOpencvLensDetSession(String configYamlPath, String projectRoot) → long ldHandle
nativeDestroyOpencvLensDetSession(long ldHandle)
```

C++ 侧 `lens_det::Session` 构造时 `load_config(config_path, project_root)` → `lensDetOptionsFromAppConfig`，detect JNI 仅接受有效 `ldHandle`。

**Rationale:** 与 `zero_point::Context` 一致；模拟器无需 RKNN `nativeCreate` 即可持有配置与 Options。

**Alternative:** 模拟器传 `handle=0` 且 native 用硬编码默认 Options — 配置与真机不一致，否决。

**Alternative:** 在 detect JNI 增加 `configYamlPath` 参数、去掉 handle — 每次推理重复读盘，否决。

### 2. `AiManager` 生命周期

**Decision:**

- 字段 `long lensDetHandle`；`ensureLensDetSession(Context)` 在 `start()` 成功路径调用（含模拟器分支）。
- 模拟器分支：`ensureLoaded` → `AssetDeployer.deploy` → `nativeCreateOpencvLensDetSession`；`handle` 仍为 0。
- 真机分支：RKNN `nativeCreate` 成功后同样 `ensureLensDetSession`（lens_det 配置与 engine 同源 deploy 路径）。
- `stop()`：`nativeDestroyOpencvLensDetSession` + `lensDetHandle = 0`。
- `isLensDetAvailable()`：`BuildConfig.ENABLE_LENS_DET_APP && lensDetHandle != 0`。

**Rationale:** 单一入口管理 session；模拟器与真机共用 deploy 逻辑。

### 3. 推理与 gate 条件

**Decision:** 以下从 `handle != 0` / `isRunning()` 改为 `isLensDetAvailable()`：

- `inferLensDetFromI420` / `inferLensDetFromJpg`
- `tryAcceptLensDetProductionInferSample` / `Live` / `ProcessVideo`
- `ProcessVideoAiSession.isProcessVideoOfflineInferenceAvailable`（lens_det-only）
- `ProcessVideoAiSession.tryCreate`（lens_det-only 时替代 `ENGINE_NOT_RUNNING` 检查）

`AiVisionFragment.runLiveInferSampleOnce`：RKNN 块仍 `isRunning()`；lens_det 块用 `isLensDetAvailable()`（整体入口可放宽为「RKNN 或 lens_det 任一可用」）。

**Rationale:** lens_det 与 RKNN 解耦；模拟器仅 lens_det 时不应被 RKNN gate 挡住。

### 4. JNI 参数 **BREAKING** 迁移

**Decision:** `nativeOpencvStainDetectFromJpg/Rgb/I420` 第一个 `long` 改为 `ldHandle`；`AiManager` 传 `lensDetHandle`。移除 `validHandle` 对 RKNN handle 的依赖；`ldHandle == 0` 返回 `invalid native handle`。

**Rationale:** 语义清晰；避免误传 RKNN handle。

### 5. `isStainInferBusy` 与模拟器

**Decision:** 模拟器无 RKNN 时 `isStainInferBusy()` 恒 false；lens_det 不因 RKNN busy defer。

**Rationale:** 无 RKNN 并发风险。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| JNI BREAKING 漏改调用点 | `verify_libai_jni.sh` + `verify-opencv-detect-integration.sh`；全仓 grep `nativeOpencvStainDetect` |
| 模拟器 OpenCV 性能慢 | 500ms 网格 + 单线程 executor 已有；可接受开发验收 |
| 双 session 内存 | lens_det Session 仅持 Options 结构，开销可忽略 |
| 真机 deploy 失败导致 lens_det 不可用 | `ensureLensDetSession` 打 error log；`isLensDetAvailable()` false，与现 engine 失败模式一致 |
| 用户用 x86 AVD | 文档明确 arm64-v8a 要求 |

## Migration Plan

1. **PR1 Native**：session create/destroy + JNI 参数迁移 + `make ai` + verify script。
2. **PR2 App**：`AiManager` + `ProcessVideoAiSession` + `NativeBridge`。
3. **PR3**：`AiVisionFragment` live + `LensDetDetectCoordinator` + 文档。
4. **验收**：arm64 AVD，`-PENABLE_LENS_DET_APP=true`，`make sync`，本地上传工艺视频 → AI Vision Detect → logcat `process_video_lens_det`。
5. **Rollback**：关闭 `ENABLE_LENS_DET_APP`；或 revert JNI（需同步 App）。

## Open Questions

- 是否将 `ENABLE_LENS_DET_APP` 默认改为 `true` for debug 构建 flavor？（默认仍 false，验收显式 `-P`。）
- 真机是否保留「lens_det 从 RKNN handle 读配置」的兼容路径？（本设计统一 ldHandle，不保留双路径。）
