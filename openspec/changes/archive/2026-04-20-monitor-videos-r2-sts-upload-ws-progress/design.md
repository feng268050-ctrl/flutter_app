## Context

- **录制落库后**：`ProcessVideoMetadataWorker` 等通常会尽快把 **`syncStatus`** 推到 **`METADATA_UPLOADED` (1)**，但网络/调度下仍可能长时间停在 **`0`**。
- **Monitor → Videos 列表「上传」**：用户希望一条入口完成「上云」：若元数据尚未成功（**`syncStatus == 0`**），点击上传应 **先** 完成 **封面 + `POST .../videos/metadata`**（与 `device-video-metadata` 语义一致，使用修正后的封面 **R2 key**）；若已是 **`1`**，则 **只** 做 **STS 视频** 上传。全程需更新 **`uploadProgress` / `syncStatus` / `videoUrl`**（视频阶段）并发送 **`video.uploading`**。
- **对象 key**：视频 `uploads/devices/{sn}/videos/{yyyy-MM-dd}/{video_id}.mp4`；封面 presign（若用）`.../{video_id}.jpg`。
- **STS**：列表路径上视频字节用 `DeviceR2StsS3Client`，一般不对视频调 presign。

## Goals / Non-Goals

**Goals:**

- 列表上传编排器：读 `ProcessParamsVideo` → **`syncStatus == 0`** → 跑封面 + 元数据 → 成功后再 STS 视频；**`syncStatus == 1`**（且未在视频上传中途失败需特殊处理时）→ 直接 STS 视频。
- 元数据阶段成功后 **`syncStatus`** 必须为 **`1`**、`uploadProgress` 在 **进入视频字节前** 按既有元数据边界置 **`0`**；视频阶段再进入 **`2`/`3`** 与进度百分比（可与 UI 分段展示）。
- 全仓封面 presign **key** 使用 `.../videos/{date}/{video_id}.jpg`。

**Non-Goals:**

- 不改变元数据 multipart 字段合同（除非 Worker 要求）。
- 不做过往旧 key 对象迁移。

## Decisions

1. **分支条件**  
   - 以 **`syncStatus == 0`** 作为「需先元数据」的单一判据（与 `VideoSyncStatus.NOT_INITIATED` 一致）。**`1`**：跳过元数据，仅 STS 视频。若未来 **`2` 卡住** 的重试策略单独迭代。

2. **复用实现**  
   - 元数据段优先 **复用** `ProcessVideoMetadataWorker` 使用的同一套 HTTP/封面逻辑（或抽共享方法），避免与 WorkManager 行为漂移；列表上传可在前台线程池直接调用该共享实现，成功后再接 STS（注意 **勿在主线程** 做网络/读文件）。

3. **Key 与日期**  
   - 仍默认 **上传动作当日** `yyyy-MM-dd`（Open Question 未关闭前可在实现里写死并注释）。

4. **WS**  
   - `video.uploading` 仍以 **视频文件上传阶段** 为主（`sync_status` 反映行状态）；元数据阶段是否额外发 WS 不在本变更强制（可选）。

## Risks / Trade-offs

- **前台触发元数据** 可能较慢 — loading 需覆盖两阶段文案或统一百分比映射。  
- **与 WorkManager 并发**：若用户点上传的同时 Worker 也在跑同一行，需 **去重或串行**（例如按 row id 锁或跳过若已在飞）。

## Migration Plan

- 客户端先发版；服务端识别新 key 与 `video.uploading`。

## Open Questions

- `{date}` 用上传日还是 `createTime` 日。
