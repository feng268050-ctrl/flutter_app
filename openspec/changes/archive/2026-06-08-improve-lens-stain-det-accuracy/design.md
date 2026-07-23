## Context

`ProcessVideoAiSession` 在工艺视频 Detect 期间按 200 ms 间隔对每一帧调用 `opencvStainDetectFromI420`，将结果写入 `ProcessVideoAiTimeline` 并通过 `AiInferenceSseHub.publishRunning` 推送 SSE。当前 `OpencvStainDetectResult.hasTarget()` 与 timeline frame 的 `boxes` / `stainDetect` 在任意单帧非空时即视为「有脏污」，overlay 采用 hold-forward 保留最近一次有框样本。

这导致单帧噪声（反光、压缩块、瞬时误检）会被 hold-forward 放大，并在 replay 时被当作真实脏污展示。产线 live weld 路径不受影响（逐帧独立、无 session 汇总）；本设计仅针对 **工艺视频 offline Detect / HTTP SSE** 路径。

相关代码：`ProcessVideoAiSession.runInferSample`、`finalizeOnWorker`、`onPlaybackEnded`、`ProcessVideoAiTimeline.Frame`、`AiVisionFragment` overlay 逻辑。

## Goals / Non-Goals

**Goals:**

- 在 session 结束（EOF 或 `stop`）前，对所有已采样帧的 pixel-space boxes 做时序归约，过滤偶发误检。
- 将归约结果作为 **最终 authoritative 帧** 追加到 timeline，经 SSE `running` 推送（在 `stop` 之前），并用于脏污判定与 AI Vision 告警。
- 容差 **10 px** 与最小出现次数 **≥ 3** 定义为 reducer 类常量，便于日后调参。
- **去掉 AI Vision overlay hold-forward**：Detect / Live 只显示当前完成样本的 boxes；完成态与 replay 以汇总帧为准。
- 保持检测进行中逐帧 SSE 推送不变。

**Non-Goals:**

- 不修改 native OpenCV stain detect 算法或 JNI 契约。
- 不改变产线 live weld（`OpencvStainDetectCoordinator`）采样与告警路径。
- 不改变 `GET /v1/videos/:video_id/ai` 路由或 SSE event 名称。
- 不触发生产焊接 deferred L001（offline source 仍被 `StainDetectAlertMapper.isOfflineStainDetectMessage` 排除）。

## Decisions

### 1. 新增纯函数 reducer 类 `LensStainBoxTemporalReducer`

**选择**：独立工具类，无 Android 依赖，便于单元测试。

**常量**（public static final，类级文档说明调参意图）：

| 常量 | 值 | 含义 |
|------|-----|------|
| `BOX_CLUSTER_TOLERANCE_PX` | `10` | 判定两框「相同/相邻」时，各边向外扩展的 pixel 容差（±10 px） |
| `MIN_PERSISTENT_OCCURRENCE_COUNT` | `3` | 保留簇所需的 **最小** distinct frame 出现次数；保留条件为 `count >= MIN_PERSISTENT_OCCURRENCE_COUNT` |

### 2. Box 输入与坐标空间

**选择**：从 timeline 每帧收集 pixel xyxy boxes：
- 优先 `Frame.boxes`（`ProcessVideoAiTimeline.Box` 的 x1,y1,x2,y2）
- 若 boxes 为空但 `stainDetect.hasTarget()`，由 `OpencvStainDetectResult.toOverlayBoxes` 反推 pixel bbox（与现有 overlay 路径一致）

所有聚类在 **detect frame pixel 空间** 进行（使用该帧的 `imageWidth`/`imageHeight`；若跨帧尺寸一致则直接比较；若不一致则按各自帧尺寸归一化到 [0,1] 再比较，或统一缩放到 max 尺寸 — **决策：假设 process video 采样尺寸一致**，若某帧尺寸不同则先 `AiDetectOverlayGeometry.toNormalizedRect` 归一化后比较，输出时再映射回汇总帧的 reference 尺寸（取 timeline 首帧或众数尺寸）。

**简化实现**：process video 采样均来自同一 retriever 路径，尺寸一致；reducer 直接使用 pixel coords，reference 尺寸 = 最后一帧或首帧 `imageWidth`/`imageHeight`。

### 3. 聚类/合并算法

**选择**：基于 **expanded-rectangle intersection** 的单遍 union-find 聚类（O(n²) 可接受，每帧 ≤32 boxes，帧数 ~ duration/200ms）。

算法：

1. 输入：`List<ObservedBox>`，每项含 `(frameIndex, timeMs, x1, y1, x2, y2, label)`。
2. 对每个 box 扩展 `T = BOX_CLUSTER_TOLERANCE_PX`：`[x1-T, y1-T, x2+T, y2+T]`。
3. 两 box 若扩展矩形相交（axis-aligned overlap），则 union 到同一 cluster。
4. 每 cluster 统计 **distinct frame 出现次数**（同一帧内多个 box 落入同一 cluster 只计 1 次）。
5. 保留 `distinctFrameCount >= MIN_PERSISTENT_OCCURRENCE_COUNT` 的 cluster。
6. 输出 canonical box：cluster 内所有原始 box 的 **坐标中位数**（或 union bbox 收紧为中位数，避免 outlier 拉伸）→ 推荐 **component-wise median of x1,y1,x2,y2**。

**备选（未采用）**：DBSCAN / center-distance-only — 对 elongated box 不稳定；expanded intersection 更符合「±10 px 容差」语义。

### 4. 汇总帧写入与 SSE 顺序

**选择**：在 `ProcessVideoAiSession` 的 worker 线程、**所有 infer 任务 drain 之后**、`publishSessionStop` **之前**：

```
1. reduced = LensStainBoxTemporalReducer.reduce(timeline.snapshotFrames())
2. summaryFrame = buildSummaryFrame(reduced, summaryTimeMs = durationMs or lastSampleMs)
3. timeline.addFrame(summaryFrame)
4. AiStainDetectResult mapped = mapSummaryToAiStainDetectResult(summaryFrame)
5. sseHub.publishRunning(mapped, summaryTimeMs, sseSessionId)
6. publishLensAlertIfNeeded(mapped)  // AI Vision only, main thread
7. persistTimelineForReplay()        // includes summary frame
8. publishSessionStop(...)
```

`summaryFrame` 标记：可通过 `timeMs == SUMMARY_FRAME_MARKER` 或 dedicated flag `isTemporalSummary = true`（推荐在 `Frame` 增加 package-private 或 status 字段 `TEMPORAL_SUMMARY`，避免 replay 中与普通帧混淆 hold-forward 逻辑）。

**Hold-forward 移除（AI Vision）**：与时序归约配套，去掉「无框时保留上一帧 boxes」的展示逻辑，避免单帧误检在 UI 上被拉长。

| 表面 | 现行 | 目标 |
|------|------|------|
| 工艺视频 Detect 进行中 | `findLastFrameWithDetectionAt` + stain 样本 hold-forward | `findFrameAt(P)`：仅当该样本自身含 boxes 时绘制，否则清空 |
| 工艺视频 Replay / 完成态 | 汇总帧优先（已实现） | 不变；无汇总帧的旧 cache 亦 **不** hold-forward |
| Live RTSP | `OpencvStainDetectHoldForwardStore` / `AiHoldForwardStore` | 仅用最新完成样本；无框则清空 overlay |

**实现要点**（`AiVisionFragment`）：
- `resolveRecordedVideoBoxFrame`：active Detect 与 Replay（无 summary）均改为 `findFrameAt` + `frame.hasDetection()`，不再调用 `findLastFrameWithDetectionAt` / `findLastStainDetectWithTargetAt`。
- `updateLiveInferenceOverlay`：移除 `OpencvStainDetectHoldForwardStore` 与 `lastLiveInferenceResult` hold-forward 合并；每次刷新仅反映最近一次 **已完成** 且 **含 boxes** 的样本。
- `runLiveInferSampleOnce`：有框时更新 overlay 状态；无框时清除 stain overlay（仍可通过 RKNN `lastLiveInferenceResult` 展示非 stain 层，若存在）。
- `ProcessVideoAiTimeline.findLastFrameWithDetectionAt`：AI Vision 不再使用；方法可保留供文档/遗留或标记 `@Deprecated`，无其他调用方则后续删除。
- `OpencvStainDetectHoldForwardStore`：若仅 AI Vision 使用，可在 AI Vision detach 时 `clear()` 后逐步移除写入路径；类本身可保留至产线无引用再删。

**备选（未采用）**：Detect 进行中仍 hold-forward、仅 Replay 用汇总 — 无法消除检测过程误检框残留，与归约目标冲突。

### 5. 脏污判定与告警

**选择**：

- `hasContamination = !reducedBoxes.isEmpty()`
- 汇总 `OpencvStainDetectResult`：`hasTarget()` 等价于 `hasContamination`；target 取第一个 persistent box 中心或最大面积 box。
- AI Vision：session 结束时 `EventBus.post(LensCheckResultEvent)`：
  - dirty → `level=2`, `status=STAIN_HEAVY`, message JSON `source=offline_stain_detect`, 可选 `temporalSummary=true`
  - clean → `level=0`, `status=CLEAN`
- `StainDetectAlertPublisher` / production weld：**不**改变 offline 排除逻辑；仅 AI Vision `LensDirtyAlertDialogCoordinator` 消费。

Detect **进行中**不发布 per-frame 告警（现状已如此）；仅汇总后一次判定。

### 6. Timeline 持久化

汇总帧写入 JSON replay 文件，字段与普通 frame 相同，增加 `temporalSummary: true`（可选 JSON 字段）供 replay UI 识别。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 真实脏污仅出现 1–2 帧被过滤 | 常量可调低；日志输出 cluster 计数供 field 调参 |
| infer 未完成就 EOF，汇总时样本不足 | 汇总前 `inferExecutor.awaitTermination` 或 drain gate；若 0 帧则 skip summary，emit clean |
| hold-forward 与 summary 帧竞争 | 已移除 AI Vision hold-forward；完成态仅 summary |
| overlay 逐帧闪烁（无 hold-forward） | 可接受；归约后 summary 给出稳定终态；busy 跳帧时短暂无框 |
| SSE 客户端多一条 running | 文档说明最后一条为汇总；timestamp = EOF |
| O(n²) 聚类随 box 数增长 | 每帧 MAX_DISPLAY_BOXES=32，可接受 |

## Migration Plan

1. 部署 app 更新；无服务端 / native 迁移。
2. 旧 timeline cache 无 summary 帧 — replay 不 hold-forward，无框即空；re-detect 生成 summary。
3. 回滚：移除 reducer 调用，恢复单帧 hasTarget 判定。

## Open Questions

- 汇总帧 timestamp 用 `durationMs` 还是 `lastSampleMs + 1`？**暂定 `durationMs`**，与 SSE stop `mediaTimestampMs` 对齐。
- 是否需要将 cluster 计数暴露到 SSE JSON 供调试？**可选** `meta.persistentBoxCount` — 首版可省略，日志即可。
