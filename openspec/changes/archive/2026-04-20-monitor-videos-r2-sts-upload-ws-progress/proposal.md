## Why

Monitor → Videos **列表里的「上传」** 仍把工艺视频推到旧链路（预签名 PUT / OSS），且未把 `t_params_process_video` 的上传态与进度写全，也没有经 WebSocket 向服务端推送实时进度。本变更把该列表上传迁到 R2 **STS S3**，补齐 DB 字段与 `video.uploading` 推送，并统一 **R2 对象 key**（含修正错误的封面 presign 路径）。若行 **`syncStatus` 仍为 `0`（元数据未成功）**，用户点击上传时应 **先** 走与 `device-video-metadata` 一致的 **封面 + 元数据上传**，成功后再进行视频 STS 上传；若已为 **`METADATA_UPLOADED` (1)**，则 **仅** 进行视频 STS 上传。

## What Changes

- **范围**：仅 **Monitor → Videos 列表中的「上传」**（例如 `ProcessVideoFragment` 触发的上传）。按行状态分支：**`syncStatus == 0`** 时，该操作 **先** 触发封面（含修正后的 presign key）与 **`POST .../videos/metadata`**，与录制后元数据能力对齐，成功后再 **STS 上传视频**；**`syncStatus >= 1`（元数据已成功）** 时，**不重复** 元数据，仅 **STS 上传视频** 并更新进度/WS。
- **视频对象 key**：`uploads/devices/{sn}/videos/{yyyy-MM-dd}/{video_id}.mp4`（`video_id` 为行上业务 UUID；`mp4` 为常规扩展名）。
- **封面 presign key（若仍有 presign 封面上传）**：与视频同目录、同 `video_id`，扩展名为 **`jpg`**：`uploads/devices/{sn}/videos/{yyyy-MM-dd}/{video_id}.jpg`。禁止再使用 `uploads/devices/{sn}/{date}/covers/...` 这类错误前缀。
- **上传实现**：该列表上传的视频字节使用 **`DeviceR2StsS3Client`** + S3 兼容 API 写入上述 key；更新 **`ProcessParamsVideo` / `t_params_process_video`** 的 `syncStatus`、`uploadProgress`、`videoUrl`（与 `VideoSyncStatus` 一致）。
- **WebSocket**：发送 **`video.uploading`**，payload 含 `video_id`、`sync_status`、`upload_progress`、`video_url`（snake_case），带节流与首尾必发。

## Capabilities

### New Capabilities

- `device-ws-video-uploading`: 定义 **`video.uploading`** 的触发时机、payload、节流与信封约定。

### Modified Capabilities

- `device-video-metadata`: 列表上传触发的 **视频文件** 字节上传阶段对 `syncStatus` / `uploadProgress` / `videoUrl` 的驱动（与录制后元数据阶段区分）。
- `device-r2-presigned-upload`: **对象 key** 改为 `uploads/devices/{sn}/videos/{date}/{video_id}.{ext}`；封面为同 `video_id` 的 `.jpg`；并写明 Monitor 列表视频走 STS、与旧 `covers/` 路径脱钩。

## Impact

- **UI**：`ProcessVideoFragment`（及任何调用同一「列表上传」的入口）；实现统一「列表上传」编排（按 `syncStatus` 分支），可复用元数据客户端/Worker 与 STS 上传模块，避免与旧「整段 Handler 不调 DB 行状态」逻辑脱节。
- **数据**：`ProcessProcessVideoDao` 局部更新 `syncStatus` / `uploadProgress` / `videoUrl`；依赖行上已有 **`videoId`**。
- **网络**：`DeviceR2StsS3Client`；若某处仍 presign 封面，仅改 **key** 生成，不改 Worker 合同其他部分。
- **WebSocket**：`DeviceWebSocketConnectionManager`（或等价）发送 `video.uploading`。
- **服务端**：需识别新 key 布局与 `video.uploading`；历史已写入旧 key 的对象与迁移策略不在本变更范围，可由运维单独处理。
