## Why

当前设备已提供 `GET /v1/videos/:video_id/ai` 的 SSE 推理流，但对“已完成推理的完整结果（JSON）”缺少一个简单、一次性拉取的接口。对于调试、对账、离线回放、以及上层系统需要拿到最终推理结构化结果的场景，SSE 并不合适（需要保持长连接、消费全量事件、且结果聚合由客户端承担）。

## What Changes

- 新增 **`GET /v1/videos/:video_id/ai/replay`**：返回该视频 **已存在的完整推理结果 JSON**（一次性响应）。
- **不影响** 现有 **`GET /v1/videos/:video_id/ai`** 的 SSE 行为与响应格式。
- 当不存在现成结果时，`GET /v1/videos/:video_id/ai/replay` 返回 **404**（不触发推理、不启动后台任务）。

## Capabilities

### New Capabilities
- `device-local-http-video-ai-replay`: 在本地 HTTP 服务上提供 `GET /v1/videos/:video_id/ai/replay`，用于回放/拉取已完成推理的完整结果 JSON；无结果返回 404 且不启动推理。

### Modified Capabilities
<!-- none -->

## Impact

- **API**: 新增本地 HTTP 路由 `GET /v1/videos/:video_id/ai/replay`（JSON 响应）。
- **存储/数据模型**: 需要有“推理已完成结果”的可定位存储（例如 DB 字段/文件缓存）；并定义“完整结果 JSON”的返回结构与版本策略。
- **错误语义**: 无现成结果返回 404（与“video 不存在”/“推理失败”/“结果未生成”需清晰区分）。
