## Context

- 录制落盘与入库：`EasyPlayerClientManger` 写 MP4；`CameraController.saveVideoAndProcess` 插入 `t_params_process_video`，其中 **`createTime` 已为 `System.currentTimeMillis()`**（`Long`，毫秒 Unix 时间戳）。
- Worker HTTPS：`DeviceApiOriginConfig.getPinnedBase()` + OkHttp `MultipartBody.FORM`（参考 `DeviceWorkerAiReportClient`）。
- 网络可用与选主：`ConnectivityManager.NetworkCallback` 与 API base 探测成功后应用内持有 pinned base（见 `device-api-origin-selection` spec）。

## Goals / Non-Goals

**Goals:**

- 表字段：`videoId`、`resolution`、`syncStatus`、`uploadProgress`；入库时生成 `videoId`，`syncStatus=0`，`uploadProgress=0`。
- 静默元数据 POST；`create_time` 与行上 `createTime` 同一时刻，**接口接受秒或毫秒两种十进制字符串**；封面 JPEG，失败则整单不上传成功态。
- pinned 可用后扫描 `syncStatus=0`，用 **WorkManager** 排队补传（一条 Worker 一次元数据；顺序降低并发压力）。
- **本次不实现** 视频文件本体的 Worker 上传；`syncStatus` 的 `2`/`3` 仅占位，供后续衔接。

**Non-Goals:**

- 实现 `VideoUploading` / `VideoUploaded` 状态迁移（仅预留枚举与列）。

## Decisions

1. **`syncStatus`（`int`，与现有 `status` 列独立）**

   | 值 | 名称 | 含义 |
   |---|------|------|
   | 0 | NotInitiated | 初始；元数据尚未成功上报（含从未上传、断网、封面失败、HTTP 失败）。 |
   | 1 | MetadataUploaded | 元数据 multipart 成功（`ApiResult` 成功且 `data == null`）。 |
   | 2 | VideoUploading | 预留给视频文件上传中。 |
   | 3 | VideoUploaded | 预留给视频文件已上传。 |

   本变更实现范围：**仅保证录制入库后为 `0`，成功元数据后为 `1`**。失败保持或回到 **`0`** 以便 WorkManager 重试（若需区分「永久失败」可后续加新值或错误列）。

2. **`uploadProgress`**  
   入库与元数据任务中恒为 **`0`**；不在元数据成功时写入 100（与「预留字段」对齐）。

3. **`videoId` / `resolution`**  
   在 **`insert` 前** 写入实体：`UUID.randomUUID().toString()`；`resolution` 例如 `CameraConfig.VIDEO_RESOLUTION_WIDTH + "x" + CameraConfig.VIDEO_RESOLUTION_HEIGHT`。

4. **`create_time`（multipart）**  
   **服务端**对 `create_time` 接受两种等价表示：Unix 时间的 **秒** 或 **毫秒**，均为 **十进制数字字符串**（无小数、无时区后缀）。**设备默认**传 **`String.valueOf(createTime)`**（毫秒，与 Room 中 `createTime` 一致）。若某环境要求秒，可传 **`String.valueOf(createTime / 1000)`**（整秒截断；与后端约定一致即可）。解析歧义由服务端规则解决（常见规则：数值 ≥ 1e12 视为毫秒，否则视为秒——若后端采用此规则，两种字符串在合理日期内不会冲突）。

5. **`cover`**  
   `MediaMetadataRetriever` + JPEG；失败则 **不调用** metadata POST（或调用前短路），`syncStatus` 保持 **`0`**，打日志；可选 Toast 仅调试版。

6. **鉴权**  
   不添加 Token 等 Header；仅 URL 路径中的 `:sn`。无效 SN（unknown / 空）不请求，行保持 `syncStatus=0`。

7. **即时上传路径**  
   主流程：`insert` 后若 pinned base 已存在且 SN 合法，可 **enqueue 同一 WorkManager 任务**（与补传共用 Worker），避免重复实现两套 HTTP。

8. **WorkManager 与 NetworkCallback**  
   - 在「选定 pinned 服务器地址」的成功回调中（与现有 probe 成功处对齐，避免重复注册）：查询 DAO **`WHERE syncStatus = 0`**（且可选 `videoId IS NOT NULL` 排除脏历史），对每条记录 **enqueue 唯一 work**（`videoId` 或 `id` 作为 tag/输入，避免重复 enqueue 可用 `enqueueUniqueWork` + `KEEP`/`REPLACE` 策略按产品定）。  
   - Worker 内：读行 → 提取 JPEG（失败则 abort，仍为 0）→ POST → 成功则 `syncStatus=1`。  
   - 约束：`NetworkType.CONNECTED`，重试/backoff 按 WorkManager 默认或轻度自定义。

9. **Room 迁移**  
   新增四列；默认值：`syncStatus=0`，`uploadProgress=0`，`videoId`/`resolution` 对旧行可 NULL；新插入行必填 `videoId`/`resolution`。

## Risks / Trade-offs

- **WorkManager 与即时上传双入口**：需去重，避免同一 `videoId` 并发双 POST。  
- **仅元数据**：用户可能看到 `syncStatus=1` 但 OSS 仍未传；与列 `status` 并存，文档说明。

## Migration Plan

Room 版本 + `Migration`；旧数据 `syncStatus=0` 会在下次网络就绪时补传（若 `videoId` 等必填缺失则跳过并日志）。

## Open Questions

- **`syncStatus=0` 且多次 HTTP 失败**：是否引入退避上限或「死信」状态（当前未要求）。
