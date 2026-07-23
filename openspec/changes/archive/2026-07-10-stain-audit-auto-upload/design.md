## Context

- 产品方案：`docs/Automated saving and uploading.md` 描述完整审计状态机（`StainAuditStatus`）、簇一致性校验（`clusterGuard`）、三类上传状态，以及 `ai_upload` → `POST /v1/devices/{sn}/ai-report` 流程。
- 仓库现状：
  - **上传基础设施已存在**：`AiUploadCoordinator`、`AiUploadDrainWorker`、`DeviceWorkerAiReportClient`，规格见 `openspec/specs/ai-report-device-pipeline/spec.md`。
  - **生产 Live 检测**：`StreamDetectPipeline` → `runLensDetIfEnabled` → `StreamDetectResultBus` → `OpencvStainDetectCoordinator`。
  - **缺口**：协调器仅处理连续 OK 门控与 L001 告警，未在 `DETECT_FAILED` 时调用 `AiUploadCoordinator`；native 成功时写 `target.json`，**失败时不写 `input_frame.jpg`**。
- **已确认范围（用户决策）**：
  - 仅 **Live 生产焊接**（`OpencvStainDetectCoordinator` / `StreamDetectPipeline`）。
  - **复用** `AiUploadCoordinator`，审计字段写入 **`stat.json`**。
  - **V1 仅 `DETECT_FAILED` 入队**；漏检/误检簇审计后续迭代。

## Goals / Non-Goals

**Goals:**

- Live weld 采样帧在 native `lens_det` 返回 `code == -3`（`OpencvDetectCodes.DETECT_FAILED`）时，自动将输入图像 + 审计 `stat` 入队 `AiUploadCoordinator`（`model=lens`, `type=0`）。
- `stat.json` 携带可机读的审计状态（V1：`status=DETECT_FAILED`、`reason`、`primary_result`、`source`、`frame_id`、`timestamp_ms` 等）。
- 与现有 L001 告警、连续 OK 门控、`FRAME_REJECTED` burst 采样 **互不破坏**。
- 为后续 `clusterGuard` / `AUTO_SUSPECTED_*` 预留 Java API（枚举与 stat 字段），但 V1 不实现簇判定逻辑。

**Non-Goals:**

- Process Video 离线 Detect、AI Vision Live native 并行流、`zero_point`、metal 模型。
- 实现 `AUTO_SUSPECTED_MISS`、`AUTO_SUSPECTED_FALSE_POSITIVE`、`INTERNAL_FILTERED` 判定与入队（仅枚举/字段预留）。
- 新建 `task.json` 或替换 `metadata.json`/`state.json` 布局。
- 修改 Worker / R2 路径生成逻辑。
- `AUTO_SUSPECTED_MISS_BY_FILTER` 状态。

## Decisions

### 1. 审计层放在 Java，`OpencvStainDetectCoordinator` 为 Live 唯一入口

**选择**：在 `OpencvStainDetectCoordinator.applyLiveWeldResult` 中，于连续 OK 门控之前/并行地调用 `StainAuditCoordinator`（或等价 helper），根据 `OpencvStainDetectResult.code` 映射 `StainAuditStatus` 并决定是否入队。

**理由**：方案要求主检测与簇追踪分离；V1 无簇追踪，但协调器已是 Live 结果汇聚点，与 `lens-det-app-inference` spec 一致。

**备选**：在 `StreamDetectResultBus` 全局监听——会耦合 AI Vision holder，违反 Live-only 范围。

### 2. `DETECT_FAILED` 判定：`code == -3` 且非 deferred/busy

**选择**：仅当 `result.code == OpencvDetectCodes.DETECT_FAILED.code()`（`-3`）且非 `CODE_OPENCV_STAIN_DETECT_DEFERRED` / `CODE_INFER_BUSY` 时映射为 `StainAuditStatus.DETECT_FAILED` 并入队。

**理由**：与 `docs/Automated saving and uploading.md` §7 及 `OpencvDetectCodes` 对齐；`code == -5`（`FRAME_REJECTED`：过曝、非红帧、strict invert 等）属于内部过滤，**不上传**。

### 3. 失败图像来源：Native 在 `kDetectFailed` 路径写 `input_frame.jpg`

**选择**：扩展 `analyzeOpencvStainDetectBgr`：当返回 `kDetectFailed`（`-3`）时，在已有 `output_dir`（每帧由 stream detect 传入的会话子目录，见决策 4）写入 `input_frame.jpg`，并将路径加入 `written_files`；Java 从 `OpencvStainDetectJson` / summary 解析绝对路径后传给 `AiUploadCoordinator.enqueue`。

**理由**：方案 §8 指定 `{output}/input_frame.jpg`；当前 BGR 仅在 native 持有，Java bus 事件无像素数据。

**备选**：Java 侧从 PR1 再抓帧——重复解码、与 native ROI 不一致，弃用。

### 4. Per-frame `output_dir` 子目录

**选择**：`detect_runner::runLensDetIfEnabled` 为每次采样创建 `output_dir/<frame_id>/`（或 `live_stain_detect_<timestampMs>/`）子目录，避免多帧覆盖同一 `target.json` / `input_frame.jpg`。

**理由**：当前 `getOpencvStainDetectLiveOutputDir()` 在 pipeline 启动时创建 **一个** 会话目录，多帧共写会互相覆盖；失败上传需要 **每帧独立** 源文件路径（`source_image_absolute_path` 供上传成功后可选清理）。

### 5. `stat.json` 结构（V1 子集）

**选择**：新增 `StainAuditStat`（Java POJO → Gson），写入 `AiUploadCoordinator.enqueue` 的 `statJson` 参数。V1 字段：

| 字段 | V1 | 说明 |
|------|-----|------|
| `status` | 必填 | `DETECT_FAILED` |
| `reason` | 必填 | native `message` / reason token |
| `source` | 必填 | `live_stain_detect` |
| `primary_result` | 必填 | `DETECT_FAILED`（V1 与 status 相同） |
| `created_at` | 必填 | epoch ms |
| `frame_id` | 推荐 | StreamDetect `frameId` |
| `code` | 推荐 | native code |
| `cluster_*` | 省略 | 后续簇审计迭代填充 |

设备快照（`DeviceStatusPut`）**不**与审计字段混写；V1 `stat` 仅承载审计载荷（与方案文档 `task.json` 示例对齐的子集，而非设备遥测）。

**理由**：用户选择复用 `AiUploadCoordinator`；`metadata.json` 保持现有 `sn/model/type` 契约不变。

### 6. 入队门控

**选择**：入队需同时满足：

1. `AiAssistanceSettings.isLensContaminationDetectionEnabled()`
2. `LiveInferGraceCoordinator.isLiveInferActive()`
3. `StainDetectSource.LIVE`
4. `code == DETECT_FAILED`
5. 解析到可读 `input_frame.jpg`

**理由**：镜片检测关闭时不应上传；grace 外不应上传；过滤帧与成功检出不入队。

### 7. 上传执行：不新增周期扫描

**选择**：继续依赖 `AiUploadCoordinator.scheduleDrain` → `AiUploadDrainWorker`；不在 V1 新增 15–30 分钟 AlarmManager。

**理由**：现有 WorkManager 已在 enqueue 时调度 drain；方案 §10 的周期扫描可由后续「离线积压保活」迭代补充。

## Risks / Trade-offs

- **[Risk] 失败帧磁盘占用** → 仅 `DETECT_FAILED` 入队；上传成功后按 `ai-report-device-pipeline` 删除 task 目录；源图在 `app_owned` 根下可随 `source_image_absolute_path` 清理。
- **[Risk] 高频 `-3` 导致队列膨胀** → V1 接受；后续可加采样去重或每 laser-on round 上限。
- **[Risk] `output_dir` 子目录变更影响调试工具** → 文档化新布局；CLI `opencv_stain_detect_infer` 不变。
- **[Trade-off] 簇审计延后** → V1 无法自动上传漏检/误检；枚举预留，避免二次改 `stat` schema。

## Migration Plan

1. Native：per-frame 子目录 + `input_frame.jpg` on `-3`。
2. Java：审计 helper + `OpencvStainDetectCoordinator` 接线。
3. 单元测试：状态映射、入队条件、`-5` 不入队。
4. 仪器/设备测试：模拟 `-3` 路径，验证 `files/ai_upload/.../tasks/<uuid>/` 与 Worker drain（可选 mock API base）。

回滚：feature flag 或移除 coordinator 入队调用即可；不影响现有 L001 与 overlay。

## Open Questions

- **每 laser-on 会话 `-3` 入队上限**：V1 是否不做限制？（当前设计：不限制，待现场数据后再加。）
- **`stat.json` 是否合并设备快照**：V1 仅审计载荷；若 Worker 需要设备状态，后续在 `metadata` 或 stat 增加可选 `device` 块。
- **簇审计迭代命名**：建议 follow-up change `stain-cluster-audit-upload`（`AUTO_SUSPECTED_MISS` / `AUTO_SUSPECTED_FALSE_POSITIVE`）。
