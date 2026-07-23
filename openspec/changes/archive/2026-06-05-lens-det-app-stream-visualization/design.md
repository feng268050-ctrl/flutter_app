## Context

- **lens_det native**（`lens_det_core` + `lens_det_jni.cpp`）已实现 OpenCV 有效带亮斑检测；JNI：`nativeOpencvStainDetectFromJpg/Rgb/I420(handle, …, outputDir)`。
- **返回契约**：JNI 返回 **summary JSON**；目标坐标在 **`outputDir/target.json`**（`{"name":"target","x":…,"y":…}`）。见 `LENS_DET_NATIVE_API.md`。
- **Handle**：复用 RKNN engine `handle`（`AiManager.getHandle()`），从 `AppConfig` 读 `lens_det:` 参数；需 `AiManager.isRunning()`。
- **RKNN 对照**（现有 `AiManager`）：
  - **流式实时（生产）**：PR1 decode → `PRODUCTION_WELD` gate → `guardedRknnStainDetectFromStream`（持续 push，回调 `onCheckResult`）。
  - **一次性实时（AI Vision live）**：TextureView 500ms 采样 → `inferFromI420` → `StainInferOutcome` → `AiStainDetectResult` → hold-forward compositor。
  - **离线单图**：`inferFromJpg` → typed outcome。
  - **工艺视频**：`ProcessVideoAiSession` 500ms 网格 → `inferFromI420` per sample。
- **lens_det 无 stream JNI**：实时只能采用 **「抽帧 + 一次性 JNI」**，与 RKNN 的 `FromStream` 不同，与 RKNN 的 `inferFromI420` **同形**。

## Goals / Non-Goals

**Goals:**

- 建立 lens_det **实时 + 离线** App 链路，帧源与采样 interval **对齐 RKNN** 路径。
- Native 负责检测 + JSON；App 负责解析、`LensDetDetectResult`、overlay 可视化。
- 支持 Quick/Engineer PR1（2000ms）、AI Vision live（500ms）、离线 JPG、工艺视频（500ms）四类入口。
- 与 RKNN 并发时：**独立 executor + 互斥或 busy-drop**，不阻塞 Modbus/UI。

**Non-Goals:**

- 用 lens_det **替代** RKNN 生产污渍告警 / Modbus / `LensCheckResultEvent` 主路径（除非产品后续单独立项）。
- App 端 Java 实现 OpenCV 亮斑算法。
- lens_det 输出 HEAVY/LIGHT/CLEAN level（native 仅给点坐标；可视化用 neutral 样式）。
- v1 必须改 native summary 内联坐标（可后续优化）。

## Decisions

### 1. 推理 API 形状：mirror `AiManager` one-shot，不是 stream push

**Decision:** 新增 `AiManager.inferLensDetFromI420` / `inferLensDetFromJpg`（或独立 `LensDetDetectService`），内部调 `nativeOpencvStainDetectFrom*`，解析 JSON，返回 `LensDetDetectResult`。

**Rationale:** lens_det JNI 为 **单帧调用**；与 `inferFromI420`/`inferFromJpg` 一致，便于 AI Vision / ProcessVideo 复用 hold-forward 模式。

**Alternative:** 在 decode 回调直接调 native — 与 RKNN stream 形似，但 native 无 push 语义，每次仍是一次 JNI + 写文件。

### 2. 实时帧源与采样（对照 RKNN）

| 场景 | RKNN  today | lens_det v1 |
|------|-------------|---------------|
| Quick/Engineer 激光 ON | PR1 → 2000ms gate → `FromStream` | PR1 → **同一 2000ms gate** → snapshot I420 → `FromI420` |
| AI Vision live | TextureView 500ms → `inferFromI420` | TextureView 500ms → `inferLensDetFromI420` |
| 离线 JPG | `inferFromJpg` | `inferLensDetFromJpg` |
| 工艺视频 | `ProcessVideoAiSession` 500ms → `inferFromI420` | 同网格 → `inferLensDetFromI420` |

**Decision:** 复用现有 `AiFrameSamplingGate` 实例类型（不新增 interval 常量除非文档需要）；lens_det **独立 gate 实例**，避免与 RKNN gate 共享 last-accept 时间戳。

### 3. JSON 解析与结果类型

**Decision:**

1. 解析 summary：`ok`, `code`, `reason`, `files[]`。
2. 若 `ok && files[0]` 存在，读 `target.json`，解析 `x`,`y`。
3. `LensDetDetectResult` 字段：`success`, `code`, `message`, `imageWidth`, `imageHeight`, `targetX`, `targetY`, `source`（`production_lens_det` / `live_lens_det` / `offline_lens_det` / `process_video_lens_det`）, `timestampMs`。
4. 提供 `toOverlayMarker()` 或转为单点 `AiStainDetectResult.Box`（退化小框）供 compositor 复用。

**Rationale:** native 契约已是 JSON；App 不重算。v1 接受二次读文件；outputDir 用 `files/lens_guard/lens_det/<sessionId>/`。

**Alternative (follow-up):** native summary 内联 `target` 对象，省 IO。

### 4. Coordinator vs AiManager 方法

**Decision:** **扩展 `AiManager`** 暴露 `inferLensDetFrom*`，**新建 `LensDetDetectCoordinator`** 负责：

- Quick/Engineer：监听 laser ON，在 PR1 采样 tick 调 `inferLensDetFromI420`（可选 feature flag）。
- 发布结果到 `LensDetHoldForwardStore` 或 EventBus `LensDetDetectResultEvent`。

AI Vision / ProcessVideo 在各自 Fragment/Session 内直接调 `AiManager.inferLensDetFrom*`，与 RKNN unified 路径并列。

**Rationale:** 与 zero_point（Coordinator + AiManager 分工）和 RKNN（AiManager + Fragment）一致。

### 5. 并发与 handle

**Decision:**

- lens_det 使用 **独立单线程 executor**（`lens-det-infer`）。
- 与 RKNN `AiStainDetectCoordinator`：**不共用** in-flight 锁（不同 JNI 入口）；若实测 native 共享 handle 非线程安全，则 **串行化**（lens_det 等待 RKNN 或 skip）。
- `handle == 0` 或 `!isRunning()` → `LensDetDetectResult` app error。

### 6. 可视化

**Decision:**

- AI Vision live / process video：**hold-forward** 最近完成的 `LensDetDetectResult`；compositor 画 **十字/圆点 + 可选 label**（`target @ x,y`），不用 RKNN 的 level 色阶 unless 固定 accent 色。
- 生产 Quick/Engineer：v1 **log + 可选 debug overlay**；完整 UI overlay 可 follow-up。
- HTTP SSE：可选扩展 `AiInferenceSseJson` 增加 `lens_det` 字段（Non-Goal v1 可只做 UI）。

### 7. Feature flag

**Decision:** `BuildConfig` 或 AdvancedSetting 开关 **`ENABLE_LENS_DET_APP`**（默认 false 直至验收），与 RKNN 路径可并存。

## Risks / Trade-offs

- **[Risk] 每帧写 `target.json` IO** → v1 可接受；follow-up 内联 JSON 或内存返回。
- **[Risk] handle 线程安全未知** → 单线程 executor + 与 RKNN 错开采样 tick；集成测试验证。
- **[Risk] 双路径 CPU**（RKNN + lens_det 同时开）→ feature flag；生产默认仅 RKNN。
- **[Risk] 无 level，UI 与 RKNN overlay 语义不同** → 独立 visual style；文档说明。

## Migration Plan

1. 合入 Parser + `AiManager.inferLensDetFrom*` + 单元测试（无 UI）。
2. AI Vision live 可选 lens_det overlay（flag on）。
3. Process video / offline JPG。
4. Quick/Engineer PR1 coordinator（flag on）。
5. `make sync` 部署；logcat `LensDetDetect` + `make verify-opencv-detect`.

## Open Questions

- 产品与 RKNN **同时显示**还是 **模式切换**（AI Vision tab 二选一）？
- 生产模式是否需要 operator-facing overlay，还是仅 AI Vision？
- native 是否在本 change 内联 `target` 到 summary JSON？
