## Context

设备侧已存在本地 HTTP AI 能力：

- `GET /v1/videos/:video_id/ai`：以 `text/event-stream` 输出过程视频推理的 SSE 事件（见 `device-local-http-video-ai` 与 `device-local-http-ai-inference-sse`）。

当前缺口是：对于“推理已完成后的最终聚合结果”，缺少一个一次性拉取接口。现有 SSE 需要客户端维持长连接并自行聚合/缓存推理事件，导致调试、验收、以及上层系统集成成本高。

本变更新增 `GET /v1/videos/:video_id/ai/replay`，仅在**存在现成结果**时返回完整 JSON；若不存在则 404，且**绝不触发推理**，以避免改变设备算力/耗电/时序行为，也避免影响已有 SSE 路由的语义。

约束与依赖：

- 复用现有“统一推理结果”数据结构（`LensGuardInferenceResult` / unified JSON）与离线过程视频推理产物（例如 timeline/缓存文件/DB 字段）。
- 与 SSE 路由解耦：新增路由不能改变 `ProcessVideoAiSession` 生命周期、SSE 事件顺序或心跳/错误语义。

## Goals / Non-Goals

**Goals:**

- 为指定 `video_id` 提供 `GET /v1/videos/:video_id/ai/replay`：
  - 若存在可用的“完整推理结果 JSON”，返回 HTTP 200 + JSON。
  - 若不存在现成结果，返回 HTTP 404。
- 清晰的错误语义区分：
  - `video_id` 不存在（DB 无行） vs “存在视频但无结果”（未推理/未产出/已清理）。
- 在实现上**不启动**推理任务，不创建/重启 `ProcessVideoAiSession`，不写入新推理缓存。
- 响应体为“完整结果”，可用于离线回放/对账，且便于未来版本化。

**Non-Goals:**

- 不提供“触发推理并等待结果”的同步接口（避免与 SSE / 任务调度耦合）。
- 不改变 `GET /v1/videos/:video_id/ai` 的 SSE 协议、事件字段、或连接生命周期。
- 不承诺跨版本/跨设备的结果文件路径稳定；只定义对外 HTTP 行为与 JSON 结构契约。

## Decisions

### 1) 新增独立路由，不复用 SSE handler

选择新增 `GET /v1/videos/:video_id/ai/replay` 独立 handler，原因：

- SSE handler 的核心职责是连接管理与事件推送，强行复用会引入“订阅即触发计算/缓存”的风险。
- replay 的语义是“只读查询现有产物”，需要明确的 404 行为；与 SSE 的“可能 emit error event 后关闭”不同。

备选方案：

- 在 SSE 路由增加 `?replay=1` 或 `Accept: application/json`：会混淆路由语义与缓存策略，且容易产生兼容性风险（客户端/代理层）。

### 2) 结果来源：只读读取“最终聚合产物”

replay 接口必须依赖一个“现成最终产物”。优先选择读取现有离线/过程视频 AI 管线已经生成的聚合结果，例如：

- 数据库字段（如 `inference_result_json` / `ai_result_path`）；
- 或文件缓存（如 `*.json` / `*.mp4` 旁路元数据），由 DB 保存路径或可推导键。

关键约束：若找不到该产物，直接 404，绝不触发“从原始视频重新推理”。

#### 当前实现选择（lookup keys）

本仓库当前的“完整结果”来源为 **过程视频 AI 推理时间线文件**（timeline JSON），由 `ProcessVideoAiSession` 在会话结束时落盘：

- **计算 key**：`cacheKey = ProcessVideoAiInferencePaths.cacheKey(processVideoVo, sourceVideoFile)`
- **结果文件**：`timelineFile = ProcessVideoAiInferencePaths.inferenceTimelineJson(context, processVideoVo, cacheKey)`
- **读取方式**：`ProcessVideoAiTimelinePersistence.load(timelineFile)`

对外的 replay 路由仅做上述读取；当 `timelineFile` 不存在或内容无有效 frames 时，视为 “无现成结果”。

备选方案：

- 读取并聚合历史 SSE 事件日志：当前系统未必持久化 SSE 流，且会引入更多存储与一致性问题。

### 3) JSON 结构：以“统一推理结果 + 时间线”作为完整结果

为避免与单帧 `LensGuardInferenceResult` 混淆，replay 返回的“完整结果”建议是一个包裹对象，包含：

- `videoId`
- `version`（用于未来演进）
- `generatedAtMs`
- `frames[]`：每个元素包含 `streamTimeMs`/`timestampMs` 以及统一结果字段（`success/code/level/status/message/imageWidth/imageHeight/boxes/source`）

这样能兼容 SSE 的 `inference` 事件语义，同时提供可离线回放的聚合结构。

### 4) 状态码策略：404 覆盖“无现成结果”

为了符合“只读查询”的 API 直觉：

- DB 无 video 行：404（video not found）
- DB 有 video 行但无结果产物：404（result not found）

实现上可在 JSON 里不区分两类 404（避免信息泄漏），但服务器日志需要区分原因，便于定位。

#### 当前实现的 404 语义拆分（日志/指标维度）

对外统一返回 404，但内部使用不同的事件码便于定位：

- `event=replay_video_not_found`：DB 无 video 行或源视频文件不可用
- `event=replay_miss`：video 存在，但无 timeline 结果文件 / 无 frames

另外，读取/解析异常使用：

- `event=replay_read_error`

## Risks / Trade-offs

- **[风险] 结果产物的定义不一致（不同机型/版本写入位置不同）** → **缓解**：在实现层做“多来源探测”（优先 DB 指针，其次约定路径），并在 spec 中只承诺对外行为，不承诺内部路径。
- **[风险] 404 语义与客户端期望不一致（有些客户端希望 204/200 空数组）** → **缓解**：明确 404 代表“无现成结果”，客户端据此决定是否走 SSE 或提示“请先生成推理”。
- **[风险] 大 JSON 体积导致内存峰值/响应慢** → **缓解**：实现使用流式输出（若框架支持）或分页/压缩留作后续扩展；本变更先保持一次性返回，后续可通过 `?format=` 或分页扩展（本次不做）。

