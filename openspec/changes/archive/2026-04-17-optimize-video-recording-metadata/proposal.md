## Why

本地录制的工艺视频目前主要依赖 Room 存路径与工艺快照，缺少稳定的全局标识与与服务端元数据同步的状态；扩展表结构并在录制后向设备域 API 上报元数据（含封面帧），便于云端索引、检索与后续与对象存储大文件流程对齐。

## What Changes

- **Room 实体与表 `t_params_process_video` 扩充字段**（需数据库迁移与 DAO/查询更新）：
  - `videoId`：入库时生成的 UUID 字符串（TEXT）。
  - `resolution`：文本形式（如 `1280x720`）。
  - `syncStatus`：独立于既有 `status` 的整型状态机（见下表）。
  - `uploadProgress`：入库及创建元数据相关流程中为 `0`，预留给后续（如实际上传进度）。
- **录制结束后的网络行为**：系统静默向 `POST /v1/devices/:sn/videos/metadata` 使用 `multipart/form-data` 提交：`video_id`, `cover`（JPEG 首帧，失败则整单不上传且不标记成功）, `duration`, `resolution`, `file_size`, `create_time`, `process_type`, `process_data`（JSON）。`create_time` 与库中 `createTime` 表示同一时刻；**服务端接受十进制字符串形式的 Unix 秒或 Unix 毫秒**（见 design）。**无需鉴权 Header**；服务端校验 SN。
- **断网补传**：在 `NetworkCallback` 且已选定 pinned 服务器地址后，若存在 `syncStatus == 0` 的行，则调度 **WorkManager** 逐条补传元数据（仅元数据，非视频文件本体）。

## Capabilities

### New Capabilities

- `device-video-metadata`: 设备侧工艺视频行的扩展字段、`POST .../videos/metadata` 静默上传、JPEG 封面失败即整单失败、以及网络恢复后 WorkManager 补传 `syncStatus == 0` 的记录。

### Modified Capabilities

- （无）以新增 capability 为主。

## Impact

- **数据层**：`ProcessParamsVideo`、`ProcessParamsVideoVo`、`ProcessProcessVideoDao`、`AppDatabase` 与迁移。
- **录制**：`CameraController` 入库字段赋值；首帧 JPEG 提取失败则不调用元数据接口并保持/回写 `syncStatus` 为未成功上传元数据的状态（见设计）。
- **网络**：新 Worker multipart 客户端；与 `DeviceApiOriginConfig` / `ConnectivityManager.NetworkCallback` 探测成功路径集成。
- **后台任务**：WorkManager（依赖项、排程、与 DAO 查询 `syncStatus = 0`）。

## 已对齐结论（产品 / 工程）

| 主题 | 结论 |
|------|------|
| `videoId` | **在入库（insert）时生成** UUID。 |
| `resolution` | **文本**（如宽高拼接字符串）。 |
| `syncStatus` | **独立整型**：`0` NotInitiated（初始）；`1` MetadataUploaded；`2` VideoUploading；`3` VideoUploaded。（当前任务主要完成 `0→1`；`2`/`3` 预留给后续视频本体上传。） |
| `uploadProgress` | 创建元数据相关流程中为 **`0`**，字段预留给以后。 |
| `create_time` / `createTime` | DB **`createTime`** 为 **`System.currentTimeMillis()`**（毫秒 `Long`）。接口 **`create_time` 支持两种传输**：Unix **毫秒**或 Unix **秒的十进制字符串**；设备默认传 **毫秒字符串**（与 `createTime` 一致），秒格式由同一时刻换算即可。 |
| `cover` | **JPEG**；**提取失败则整单失败**（不 POST 或 POST 前中止，且不进入 MetadataUploaded）。 |
| 用户操作 | **无取消**；元数据上传 **系统静默**。 |
| 鉴权 | **无需额外鉴权**；服务端校验 SN。 |
| 断网录制 | pinned 地址可用后，检查 **`syncStatus == 0`**，**WorkManager** 顺序上传元数据。 |
