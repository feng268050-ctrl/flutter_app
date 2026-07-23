# Implementation map (workspace snapshot)

| Concern | Classes |
| --- | --- |
| Worker `multipart` `POST /v1/devices/:sn/ai-report` | `DeviceWorkerAiReportClient`, `AiReportApiResult` |
| Pinned API base (staging vs release via probe) | `DeviceApiOriginConfig` + `joinUnderBase` / path segments for `sn` |
| Local `files/ai_upload/` tree, pending queue, cleanup | `AiUploadPaths`, `AiUploadQueueJson`, `AiUploadCoordinator`, `AiUploadMetadata` |
| Inference hook (caller supplies image file) | `AiUploadFailureSampleHook` (`lens` / `metal`) |

工艺视频 R2 presign 仍为独立链路：`DeviceWorkerPresignedVideoClient`, `VideoAndProcessParamsHandler`.
