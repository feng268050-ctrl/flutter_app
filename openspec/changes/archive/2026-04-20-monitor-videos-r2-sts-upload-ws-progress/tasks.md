## 1. 列表上传编排（按 `syncStatus` 分支）

- [x] 1.1 在 `ProcessVideoFragment` / `ProcessVideoViewModel`（或专用 UseCase）实现统一入口：读取 `ProcessParamsVideo`，要求 **`videoId` 非空**、本地 **`videoPath`** 有效。
- [x] 1.2 **若 `syncStatus == 0`**：先执行与 `ProcessVideoMetadataWorker` / `DeviceWorkerVideoMetadataClient` 等价的 **封面提取 + presign 封面上传（新 key `.../videos/{date}/{video_id}.jpg`）+ `POST .../videos/metadata`**，成功后将行置为 **`METADATA_UPLOADED` (1)**（及 `coverUrl` 等按现有规格）；**失败则中止**，不开始 STS 视频。
- [x] 1.3 **若 `syncStatus == 1`（或元数据段刚成功）**：调用 `DeviceR2StsS3Client` → 上传至 **`uploads/devices/{sn}/videos/{yyyy-MM-dd}/{video_id}.mp4`**；更新 **`syncStatus` 2→3**、`uploadProgress`、`videoUrl`；发送 **`video.uploading`**（节流）。处理 **2 卡住重试** 可与产品另定，至少保证 **1** 能再次点上传。
- [x] 1.4 与 WorkManager 元数据任务 **串行或去重**（同一 `rowId` 避免双跑），避免竞态写 `syncStatus`。

## 2. R2 key 修正（封面与其它仍 presign 的路径）

- [x] 2.1 元数据前封面上传：`uploads/devices/{sn}/videos/{yyyy-MM-dd}/{video_id}.jpg`；全仓替换旧 `covers/` 拼 key。
- [x] 2.2 搜索 `uploads/devices`、`covers/`、`VideoAndProcessParamsHandler` 等，Dev 入口一并核对。

## 3. WebSocket `video.uploading`

- [x] 3.1 在 **STS 视频上传** 阶段组装并发送 payload（`video_id`、`sync_status`、`upload_progress`、`video_url`），节流与首尾必发；元数据阶段是否上报由产品决定，本任务默认 **仅视频阶段**。

## 4. UI

- [x] 4.1 Loading：**两阶段**（先元数据/再视频）或映射为总进度时，文案与百分比需与用户感知一致；`syncStatus` 已为 `1` 时仅展示视频进度。

## 5. 验证

- [x] 5.1 单测：`syncStatus` 0 vs 1 分支、key 生成、WS payload。
- [x] 5.2 联调：`0`→先元数据再 STS；`1`→仅 STS；R2 key 与 WS 与后端一致。
