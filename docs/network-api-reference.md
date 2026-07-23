# 网络接口参考（HTTP / WebSocket）

本文档根据当前 Android 客户端源码整理，描述 **Retrofit 业务 HTTP**、**Cloudflare R2（S3 兼容 STS）工艺视频上传** 与 **设备 WebSocket** 的端点、请求头、数据模型及消息约定。  
**服务端实际校验规则、错误码扩展、字段必填性以联调与后端文档为准**；此处以代码为准。

**源码版本线索**：`BuildConfig.BASE_HTTP_URL`、`DeviceIdentity.getDeviceSnSafely()`（设备 SN）、`app/build.gradle.kts` 中的 `buildConfigField`。

---

## 1. 环境与基础 URL


| 配置项       | 来源                                                      | 当前工程典型值（debug/release 一致）           |
| --------- | ------------------------------------------------------- | ----------------------------------- |
| HTTP 基础地址 | `BuildConfig.BASE_HTTP_URL` → `RetrofitClient.BASE_URL` | `http://47.86.53.176:80/stage-api/` |


完整 HTTP URL = `BASE_URL` + 接口相对路径（Retrofit `@GET`/`@POST` 中的字符串）。

---

## 2. 全局 HTTP 约定

### 2.1 OkHttp 默认请求头

客户端：`com.lasercyber.lws.ui.common.config.OkHttpConfig`


| Header        | 值                          |
| ------------- | -------------------------- |
| `App-Version` | `BuildConfig.VERSION_NAME` |
| `Device-Type` | `Android`                  |


### 2.2 超时

连接 / 读 / 写均为 **10 秒**。

### 2.3 统一响应包装 `Result<T>`

类：`com.lasercyber.lws.ui.bean.result.Result`

JSON 字段（Gson `@SerializedName`）：


| 字段     | 类型     | 说明                                   |
| ------ | ------ | ------------------------------------ |
| `code` | int    | 客户端判断成功：`code == 200`（`isSuccess()`） |
| `msg`  | String | 提示信息                                 |
| `data` | T      | 业务数据                                 |


---

## 3. HTTP 接口清单（Retrofit）

### 3.1 工艺与视频元数据 — `ProcessVideoRemoteApi`


| 方法   | 相对路径                                         | 说明                                      |
| ---- | -------------------------------------------- | --------------------------------------- |
| POST | `videoMange/video/uploadVideoAndProcessData` | 提交工艺参数 + 视频基础信息（封面/视频 URL 等），返回业务侧视频 ID |


请求体：`ProcessParamsVideo`（JSON，见 §4.3）。  
响应 `data`：`Long`（代码中作为 `videoId`；元数据登记成功后客户端再经 **R2 STS + S3 PutObject** 上传本地视频文件，见 §4.2 与 `VideoAndProcessParamsHandler` / `MonitorProcessVideoListUploadRunner`）。

---

### 3.2 测试 / 环境配置 — `TestRemoteApi`


| 方法   | 相对路径                                                     | 说明                                        |
| ---- | -------------------------------------------------------- | ----------------------------------------- |
| POST | `environment/deviceConfigCycle/loadConfigByParendDevice` | 请求体为任意 `JsonObject`；响应 `Result<DataBean>` |


**说明**：当前仓库内未发现对该 API 的调用，具体 JSON 字段需与后端确认。

---

### 3.3 动态 URL — `UrlCheckApi`


| 方法   | 说明                                  |
| ---- | ----------------------------------- |
| HEAD | `@Url String url` — 仅请求头，用于探测资源是否可达 |
| GET  | `@Url String url` — 备用              |


典型用法：探测摄像头 HTTP API 根地址（见 `CameraUtils.checkCamera` → HEAD `CameraConfig.BASE_CAMERA_APP_URL`）。

---

### 3.4 动态 URL — `CameraRemoteApi`


| 方法  | 说明                                                                                    |
| --- | ------------------------------------------------------------------------------------- |
| PUT | `@Url String url`，Body：`CameraTime`，Header：`Authorization` = `CameraConfig.basicAuthorization()`（由 `CAMERA_USER_NAME` / `CAMERA_PASSWORD` 派生） |
| GET | `getDeviceInfo`：`Authorization` 同上；URL = `BASE_CAMERA_APP_URL + "System/deviceinfo"` |


典型完整 URL：`http://10.100.100.100:9000/System/time`（`CameraConfig.BASE_CAMERA_APP_URL + "System/time"`）。

`**CameraTime` JSON 字段**（Gson 序列化）：


| 字段     | 类型      | 备注                           |
| ------ | ------- | ---------------------------- |
| `year` | Integer |                              |
| `mon`  | Integer | 月份（`@SerializedName("mon")`） |
| `day`  | Integer |                              |
| `hour` | Integer |                              |
| `min`  | Integer | 分钟（`@SerializedName("min")`） |
| `sec`  | Integer |                              |


---

## 4. 主要 HTTP 数据模型

### 4.1（已移除）设备 MQTT 凭证接口

历史接口 `GET v1/device/account/mqtt` 与模型 `DeviceRabbitmqAuth` 已从客户端删除；设备侧连接与推送以 **WebSocket** 为准（见 §6）。

### 4.1.1（已移除）阿里云 OSS STS

历史接口 **`GET v1/device/account/ali/oss`**、模型 **`AliYunSTS`**、阿里云 OSS Android SDK 上传链（`OSSCredentialProviderManger`、`OssUploadFileRequestBuilder` 等）已从客户端删除。  
工艺视频封面与文件上传统一走 **R2 STS**（§4.2）。

### 4.2 R2 STS 凭证 `R2StsCredentialsData`

Worker 已 pin 的 API Origin 上 **`POST /v1/storage/r2/sts`**（见 `DeviceR2StsS3Client`）返回的 `data` 对象：


| 字段                  | 类型     | 说明 |
| ------------------- | ------ | --- |
| `access_key_id`     | String | 临时密钥 ID |
| `secret_access_key` | String | 临时密钥 |
| `session_token`     | String | Session token |
| `expires_at`        | Long   | 过期时间（Unix ms） |
| `endpoint_url`      | String | S3 兼容 Endpoint |
| `bucket`            | String | Bucket |
| `region`            | String | 区域（常为 `auto`） |
| `public_base_url`   | String | **必填**。对外读 URL 的 HTTPS 前缀（不含 object key）；工艺视频封面经 S3 `PutObject` 后，读 URL 为其与 object key 拼接（`ObjectStorageUrls.joinPublicBaseUrl`）；缺失时客户端报错。 |

**客户端上传流程（工艺视频）**

1. **`POST /v1/storage/r2/sts`**（Worker 已 pin 的 API Origin）→ 取得上表凭证与 `public_base_url`（`DeviceR2StsS3Client`）。
2. **封面**：S3 `PutObject`（JPEG）→ `coverUrl` = `joinPublicBaseUrl(public_base_url, objectKey)`（`ProcessVideoR2CoverUpload`）。
3. **元数据**：`POST videoMange/video/uploadVideoAndProcessData`（`ProcessVideoRemoteApi`）→ 返回 `videoId`。
4. **视频文件**：S3 `PutObject` 本地 MP4（`ProcessVideoR2StsVideoPut`）；`videoUrl` 由 `ProcessVideoR2PublicUrls` 从 `public_base_url` + object key 推导。

实现类：`DeviceR2StsS3Client`、`ProcessVideoR2CoverUpload`、`ProcessVideoR2StsVideoPut`、`ProcessVideoCoverR2Upload`、`VideoAndProcessParamsHandler`、`MonitorProcessVideoListUploadRunner`。

### 4.3 `ProcessParamsVideo`


| 字段                      | 类型                    | 说明                        |
| ----------------------- | --------------------- | ------------------------- |
| `processParametersData` | ProcessParametersData | 工艺参数（插入前会对 clone 清空 `id`） |
| `processVideo`          | ProcessVideo          | 视频元数据                     |
| `videoTitle`            | String                | 视频标题                      |


### 4.4 `ProcessVideo`


| 字段              | 类型      | 说明                      |
| --------------- | ------- | ----------------------- |
| `coverUrl`      | String  | 封面读 URL：`R2StsCredentialsData.public_base_url` + object key（`ObjectStorageUrls.joinPublicBaseUrl`） |
| `videoUrl`      | String  | 视频读 URL：同上，由 `ProcessVideoR2PublicUrls` 从封面 URL 前缀与视频 object key 拼接 |
| `videoDuration` | Long    | 时长                      |
| `videoName`     | String  | 文件名                     |
| `recordingTime` | Date    | 录制时间                    |
| `processType`   | Integer | 工艺类型（字典 `process_type`） |
| `deviceSn`      | String  | 设备 SN                   |


### 4.5 `ProcessParametersData`（概要）

实体类字段较多（激光功率、摆动、送丝、延时等），完整列表见源码  
`com.lasercyber.lws.ui.bean.entity.ProcessParametersData`。  
WebSocket `command.send_process_param` 等路径的 `payload` 可承载该对象的 JSON；Room 表名：`t_process_parameters_data`。

**`dataType`（`ProcessDataType`）**

| 值 | 含义 |
| --- | --- |
| `0` | 快速模式参数 |
| `1` | 工程师模式内置参数 |
| `2` | 工程师模式自定义参数 |
| `3` | 视频工艺参数（**废弃**，勿新写入） |

工程师模式工艺库远程 API（§5.1 / §6.2）仅暴露 **`dataType` 1、2**；远程删除仅允许 **`2`**（自定义）。

---

## 5. WebSocket 服务端推送 JSON 信封（Gson）

客户端经 **WebSocket** 接收 `command.send_process_param` / `command.send_process_lib`；`payload` 仍沿用历史 JSON 字段名（`data`、`msgType`、`msgId` 等），由 `bean/push/*` 与 `ServerPush*PayloadParser` 解析。

### 5.1 消息类型枚举 `ServerPushMsgType`

| 名称                 | `msgType` 值 | 说明       |
| ------------------ | ----------- | -------- |
| `ONE_PROCESS_DATA` | 1           | 单条工艺参数（`command.send_process_param`，见 §6） |
| `PROCESS_LIB`      | 2           | 整包工艺库（`command.send_process_lib`） |

> 历史值 `3`（设备信息）、`4`（回执载荷）对应的 Java 类型已删除；设备快照改走 WebSocket `device.online` / `command.stat_response`。

### 5.2 通用消息信封 `ServerPushEnvelope<T>`

JSON 序列化（Gson）时常见字段：

| 字段          | 类型     | 说明                                           |
| ----------- | ------ | -------------------------------------------- |
| `data`      | T      | 业务载荷                                         |
| `msgId`     | String | 消息 ID（如 `IdUtil.simpleUUID()`）               |
| `timestamp` | Long   | 毫秒时间戳                                        |
| `version`   | int    | 版本号，当前创建时常为 `1`                              |
| `msgType`   | int    | 见 §5.1；`jsonString()` 会写入 `getMsgType()` 返回值 |

具体子类：`ProcessParametersPushEnvelope`（`msgType=1`）、`ProcessLibraryPushEnvelope`（`msgType=2`）。

工厂方法：`ServerPushEnvelope.create(dataContent, envelopeInstance)` 会设置 `timestamp`、`msgId`、`version`；`jsonString()` 内会 `this.msgType = getMsgType()` 再序列化。

### 5.3 WebSocket `payload` 与工艺参数

单条工艺参数 **payload**：推荐使用与 §5.2 相同的对象形状，至少包含 **`data`**（`ProcessParametersData`）；可选 `msgId`、`timestamp`、`version`、`msgType`（缺省时客户端按 `1` 处理）。也支持 **无 `data` 包装**：`payload` 根级即为 `ProcessParametersData` 的字段。解析入口：`ServerPushProcessParamPayloadParser` → `ProcessParametersPushEnvelope`。

### 5.4 `ProcessLibrary`（工艺库包）


| 字段              | 类型                        | 说明                              |
| --------------- | ------------------------- | ------------------------------- |
| `versionCode`   | Integer                   | 版本号                             |
| `versionStatus` | Integer                   | 状态（字典 `process_version_status`） |
| `dataList`      | ListProcessParametersData | 工艺列表                            |


### 5.5 `DeviceInfoVo`（设备信息包）


| 字段                 | 类型              | 说明                             |
| ------------------ | --------------- | ------------------------------ |
| `device`           | Device          | `name`, `sn`, `type`, `status` |
| `staticData`       | StaticData      | 自定义布局等                         |
| `deviceInfo`       | DeviceInfo      | 设备基础信息                         |
| `commonSettings` | CommonSettings | 通用设置（`language`, `unit`, `soundEffect`, `showBootSelfCheck`） |

**`deviceInfo` 远程快照额外字段**（`@Ignore` 不写入 Room；`device.online` `payload.stat.deviceInfo` 与 `command.stat_response` `payload.data.deviceInfo` 组包时由 `DeviceStatusPut.getDeviceInfo` 填充）：

| 字段 | 类型 | 说明 |
| ---- | ---- | ---- |
| `cameraVersion` | string | 摄像头 `GET /System/deviceinfo` 的 `appVersion` 归一化值（去 `v` 前缀与 ` build…` 后缀）；不可达或未拉取时为 **`-`** |
| `cameraIp` | string | 当前生效的摄像头 IPv4（`/system/etc/model.properties` 的 `camera_ip`，否则出厂默认 `192.168.1.100`）；与 `CameraConfig.getCameraIp()` 一致 |
| `hostIp` | string | 开发宿主机 LAN IPv4（`model.properties` 的 `host_ip`；`make emulator` 自动注入）；无配置时为 `""` |
| `focusScaleRef` | int | 枪头对焦刻度参考值（`model.properties` 的 `focus_scale_ref`，由 `FOCUS_SCALE_REF` 写入）；无配置或非法时为 `0` |
| `deviceStatus`     | DeviceStatus    | 设备状态                           |
| `deviceData`       | DeviceData      | 运行数据                           |
| `warns`            | ListWarnTable   | 告警列表                           |

**`deviceStatus` 远程快照额外字段**（不来自下位机寄存器；用于对外监视/联调）：

| 字段 | 类型 | 说明 |
| ---- | ---- | ---- |
| `cameraStatus` | int | 摄像头通讯状态（HTTP 探测结果），取值：`1`=可通讯（healthy），`0`=不可通讯（fault）。与 HMI “Alarm Information / Machine Status” 中的摄像头通讯指示同源。 |

**`staticData` 快照额外字段**（`DeviceStatusPut.packVoData` 组包前填充；`@Ignore` 不写入 Room，仅出现在 JSON 序列化中）：

| 字段              | 类型     | 说明                                                                 |
| ----------------- | ------ | ------------------------------------------------------------------ |
| `commonUseText`   | string | 设备端解析后的主耗材展示文案（与 UI「常用材料」同源）；`commonUse` 为空或非法枚举时为字面量 **`unknown`**。 |

### 5.6 WebSocket ACK 响应码 `ServerPushAckCode`

`command.send_process_param_ack` / `command.send_process_lib_ack` 的 `payload.code`：

| 常量                         | 值   |
| -------------------------- | --- |
| `ServerPushAckCode.SUCCESS` | 200 |
| `ServerPushAckCode.FAIL`    | 500 |


---

## 5.1 设备本地 HTTP API（LAN）

设备在应用运行期间于 **`0.0.0.0:5580`** 提供嵌入式 HTTP 服务（`DeviceLocalHttpServer`），供手机 App 或局域网客户端在 **设备 LAN IP** 上直连（与 mDNS 发现配合）。基础 URL：

`http://<device-lan-ip>:5580`

> **废弃**：早期版本使用 **`:8080`**（`DeviceLocalHttpServer.DEPRECATED_PORT`），请迁移至 **`:5580`**。
>
> **模拟器**：`make emulator` 与 **`make install`（启动 App 之后、且 adb 目标为 `emulator-*`）** 会先执行 **`adb kill-server`** 与 **`adb -a server start`**（adb 监听 `0.0.0.0`，便于 LAN 访问 forward），再 **`adb forward tcp:5580 tcp:5580`**。宿主机用 **`http://127.0.0.1:5580/`** 访问（建议不用 `localhost`，避免先试 IPv6 `::1`）；同网段其他机器可用 **`http://<host-lan-ip>:5580/`**（防火墙允许时）。`make emulator` 每次启动还会将检测到的宿主机 LAN IP 写入 **`/system/etc/model.properties`** 的 **`host_ip`**（可通过 `.env` 的 **`HOST_IP`** 覆盖），并在 **`command.stat_response`** / **`device.online`** 的 **`deviceInfo.hostIp`** 中上报。`make install` 会 **reboot**，此前 forward 会失效，故 install 流程末尾会按需重建。仍失败时执行 **`make emulator-forward`**。

响应 JSON 使用与 Worker 一致的 **`ApiResult`** 信封（`success`、`code`、`message`、`data`），见 `com.lasercyber.lws.ui.bean.http.ApiResult`。逻辑成功以 **`success === true`** 为准。

### 探测

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| GET | `/lasercyber` | 健康检查；HTTP **200**，正文纯文本 **`Hello LaserCyber`**（非 `ApiResult`） |

### 摄像头实时流（RTSP 中继）

**BREAKING**：已移除 `GET /v1/camera/live`。PR0 由设备内置 **MediaMTX** 从摄像头拉一路流，向局域网提供 RTSP fan-out。

| 协议 | URL | 说明 |
| ---- | --- | ---- |
| RTSP | `rtsp://<device-lan-ip>:8554/camera/pr0` | 工业摄像头 **主流 `/PR0`** 的 LAN 中继（勿连 `rtsp://192.168.1.100/PR0` 作为设备代理） |

**播放示例（设备 Wi‑Fi IP）**

```bash
ffplay -rtsp_transport udp "rtsp://<device-lan-ip>:8554/camera/pr0"
# VLC：媒体 → 打开网络串流 → 上述 URL
```

**Flutter**：使用支持 RTSP 的播放器（如 **media_kit** / **flutter_vlc_player**）。

**性能说明**：摄像头侧仅 **一路** PR0 RTSP 上游（MediaMTX）。局域网多个 RTSP 客户端与 HMI **快速/工程师模式录像**、**`POST /v1/camera/record`** 均为下游读者（本机录制使用 `rtsp://127.0.0.1:8554/camera/pr0`）。

**现场验收（checklist）**

1. eth0 / 摄像头网段已配置（与录制相同前置条件）。
2. `ffplay` 或 VLC 可连续播放 `rtsp://<device-lan-ip>:8554/camera/pr0`。
3. logcat `MEDIA_MTX_RELAY`：`mediamtx start`；首个观众连接后上游连摄像头。
4. 快速模式开始录像且 ffplay 仍在播放时，摄像头仅一条 PR0 上游（MediaMTX）。

实现：`MediaMtxRelayCoordinator`、`MediaMtxBinary`；构建：`make mediamtx`（见 `tools/mediamtx/README.md`）。

**生命周期**：应用启动后后台调用 `startForLanPreview()`，MediaMTX 常驻监听 **8554**（与是否录像无关），等价于原 `/v1/camera/live` 的「随时可看」。logcat 关键字：`MEDIA_MTX_RELAY`、`startForLanPreview`、`mediamtx start`。

### 摄像头 AI 推理 SSE（与 live 视频配对）

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| GET | `/v1/camera/ai` | **Server-Sent Events** 推理结果流（`Content-Type: text/event-stream; charset=utf-8`）。**非** `ApiResult`，**不含**视频字节。 |

**视频**：客户端 MUST 使用 **`rtsp://<device-lan-ip>:8554/camera/pr0`** 播放 PR0 画面，在本 SSE 流上按时间戳自行绘制检测框/状态（类似字幕/弹幕）。

**SSE 事件**（`/v1/camera/ai` 与 `/v1/videos/:id/ai` 使用**相同事件名与 JSON 字段**；仅 `timestampMs` 含义不同，见下表）

| `event` | 说明 |
| ------- | ---- |
| `idle` | 连接建立后**立即**推送，之后约每 15s；`data`：`{"timestampMs":<n>,"inferenceActive":<bool>}` |
| `start` | 推理会话开始；`data`：`sessionId`、`timestampMs`、`source`、`samplingIntervalMs`，可选 `imageWidth`/`imageHeight` |
| `running` | 每次推理完成；`data`：`timestampMs`、`sessionId`（可选）、`success`、`code`、`level`、`status`、`message`、`imageWidth`、`imageHeight`、`boxes[]`、`source` |
| `stop` | 推理会话结束；`data`：`sessionId`、`timestampMs`、`reason` |
| `error` | 致命错误后关闭连接；`data`：`code`、`message` |

**`timestampMs` 语义**

| 路由 | `timestampMs` |
| ---- | ------------- |
| `/v1/camera/ai` | 自**该 SSE 连接建立**起的毫秒数（与同步开始的 RTSP 播放对齐） |
| `/v1/videos/:id/ai` | **源片媒体时间轴**毫秒（从 0 起，与同步开始的 `/stream` 播放进度对齐） |

**`start.source` / `stop.reason`（常见值）**

| 字段 | 直播 `/v1/camera/ai` | 工艺片 `/v1/videos/:id/ai` |
| ---- | -------------------- | -------------------------- |
| `start.source` | `production_weld`、`ai_vision_live` | `process_video` |
| `stop.reason` | `laser_off`、`preview_stopped`、`stream_error`、`release` | `session_complete`、`session_cancelled`、`force_restart`、`stream_error`、`release` |

**订阅示例**

```bash
curl -N "http://<device-lan-ip>:5580/v1/camera/ai"
ffplay -rtsp_transport udp "rtsp://<device-lan-ip>:8554/camera/pr0"
```

实现：`CameraAiHttpPublisher`、`AiInferenceSseHub`、`DeviceLocalHttpServer`。

### Monitor 机台状态 SSE

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| GET | `/v1/monitor/stat` | **Server-Sent Events** 机台监视流（`Content-Type: text/event-stream; charset=utf-8`）。**非** `ApiResult`。推送与 WebSocket `command.stat_response` 相同的 `deviceStatus` / `deviceData` / `processParameters` 子对象（含 `deviceStatus.cameraStatus` 0/1）。 |

**SSE 事件**

| `event` | 说明 |
| ------- | ---- |
| `stat` | 仅在 `deviceStatus`、`deviceData` 或 `processParameters` 相对上次推送发生变化时发送；`data` 为 `{"deviceStatus":<obj\|null>,"deviceData":<obj\|null>,"processParameters":<obj\|null>}` |
| `heartbeat` | 连接保持；至少每 15s 一次；`data` 为 `{"ok":true}` |

设备以 **100ms** 采样内存缓存中的最新 `DeviceStatus` / `DeviceData` 与 `ProcessParametersSnapshotStore` 中的 `processParameters`，仅在检测到变化时发送 `stat`。多个并发订阅者共享单路采样循环（fan-out）。

**字段含义（外部客户端）**：见 `openspec/changes/archive/2026-05-29-add-monitor-stat-sse/monitor-field-mapping.md`。

**订阅示例**

```bash
curl -N "http://<device-lan-ip>:5580/v1/monitor/stat"
```

实现：`MonitorStatHttpPublisher`、`MonitorStatSseHub`、`DeviceLocalHttpServer`。

### Monitor 告警 SSE

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| GET | `/v1/monitor/alerts` | **Server-Sent Events** 告警流（`Content-Type: text/event-stream; charset=utf-8`）。**非** `ApiResult`。告警对象与 WebSocket `command.stat_response` `payload.data.warns` 数组元素一致。 |

**SSE 事件**

| `event` | 说明 |
| ------- | ---- |
| `list` | 连接建立后**立即**推送；`data` 为 JSON **数组**（当前全部可见告警，与 stat `warns` 同源） |
| `new` | 新告警入库；`data` 为单个 warn 对象 |
| `clear` | 告警已清空（本地或云端 `command.clear_alerts`）；`data` 为 `{}` |
| `heartbeat` | 连接保持；至少每 15s 一次；`data` 为 `{"ok":true}` |

**订阅示例**

```bash
curl -N "http://<device-lan-ip>:5580/v1/monitor/alerts"
```

实现：`MonitorAlertsHttpPublisher`、`MonitorAlertsSseHub`、`WarnListLoader`、`DeviceLocalHttpServer`。

### 摄像头录制控制

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| POST | `/v1/camera/record` | 启停 **PR0 工艺录像**（与 Fast Mode / Engineer Mode 悬浮录制按钮同一套前置条件与 `EasyPlayerClientManger` 路径）。`ApiResult` 成功时 **`data`** = `{ "switch": "on" \| "off" }`（有效状态）。 |

**Body**（`Content-Type: application/json`）

```json
{ "switch": "on" }
```

| `switch` | 说明 |
| -------- | ---- |
| `on` | 开始录制（摄像头就绪、本地存储、 `CameraUtils.checkCamera` 等与 UI 一致；**HTTP 会阻塞至 muxer 首帧写入**，与屏上录制按钮进入计时态同步） |
| `off` | 停止录制并保存到本地视频库；当前版本不再在录制结束后弹出“确认上传”对话框，也不会立即上传（上传需通过列表/其他显式入口触发） |

**成功示例**

```json
{
  "success": true,
  "code": 200,
  "message": null,
  "data": { "switch": "on" }
}
```

**常见失败 `message`**

| message | 说明 |
| ------- | ---- |
| `invalid_switch` | body 缺少 `switch` 或值不是 `on` / `off` |
| `camera_not_ready` | 录制客户端未初始化（模拟器等） |
| `insufficient_storage` | 机载本地存储不足 |
| `camera_unavailable` | 摄像头检测失败 |
| `recording_failed` | RTSP 连接或 muxer 首帧写入失败（HTTP 在真正开始写文件前不会返回 `switch: "on"`） |
| `recording_in_progress` | 已有 PR0 录制会话时再 `switch: "on"`（HTTP **409**，`message` 为「另一个线程正在录制中」或当前语言等价文案） |
| `record_apply_timeout` | 异步前置检查超时 |

**curl**

```bash
curl -s -X POST "http://<device-lan-ip>:5580/v1/camera/record" \
  -H "Content-Type: application/json" \
  -d '{"switch":"on"}'

curl -s -X POST "http://<device-lan-ip>:5580/v1/camera/record" \
  -H "Content-Type: application/json" \
  -d '{"switch":"off"}'
```

**UI 同步**：Quick / Engineer 模式摄像头悬浮窗可见时，HTTP 启停会同步录制按钮与计时动画（`CameraRecordUiBridge`）。

**并发**：仅允许一路 PR0 录制。已录制时再 `on` 返回 **409** 与 `recording_in_progress`（见上表）；未录制时再 `off` 仍返回 `success: true` 与 `data.switch: "off"`（幂等停止）。

**现场验收（checklist）**

1. Fast Mode 或 Engineer Mode 下摄像头悬浮窗可见。
2. `curl` POST `{"switch":"on"}` → `data.switch` 为 `on`，屏上录制按钮/计时与手动点击一致。
3. POST `{"switch":"off"}` → 停止录制，工艺视频库出现新条目（与 UI 停止一致）。
4. 录制中再次 POST `on` → HTTP **409**，`success: false`，`message` 含「另一个线程正在录制中」，且不重复启停。
5. 未录制时重复 POST `off` → 仍成功且不重复停止。
6. （可选）`ffplay` 播放 `rtsp://<device-lan-ip>:8554/camera/pr0` 同时 HTTP 启停录制，画面仍可用（单路上游 MediaMTX）。

实现：`CameraRecordCoordinator`、`CameraRecordUiBridge`、`DeviceLocalHttpServer`。

### ADB 远程调试

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| POST | `/v1/adb` | 开启网络 ADB（`adb connect <device-ip>:5555`）。与 **设置 → 设备信息 → 连续点击 5 次 System Version** 隐藏入口调用同一套 `AdbRemoteDebugHelper`（开启 USB 调试、TCP 端口 **5555**、重启 `adbd`）。无请求体。 |

**成功示例**

```json
{
  "success": true,
  "code": 200,
  "message": null,
  "data": null
}
```

**常见失败 `message`**

| message | 说明 |
| ------- | ---- |
| `adb_enable_failed` | `Settings.Global` 写入或 root shell 步骤失败（HTTP **503**） |

**curl**

```bash
curl -s -X POST "http://<device-lan-ip>:5580/v1/adb"
adb connect <device-lan-ip>:5555
```

**幂等**：已开启时重复 `POST` 仍返回 `success: true` 与 `data: null`（重新应用相同配置）。

**现场验收（checklist）**

1. `curl -s -X POST "http://<device-lan-ip>:5580/v1/adb"` → `success: true`，`data: null`。
2. 同网段执行 `adb connect <device-lan-ip>:5555` 成功。
3. 重复 `POST` 仍为成功响应（幂等）。

实现：`AdbRemoteDebugHelper`、`DeviceLocalHttpServer`。

### 工艺视频

路径参数 **`:video_id`** 均为业务 UUID（`ProcessParamsVideo.videoId`），**不是** Room 自增 `id`。

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| GET | `/v1/videos` | 分页列表；Query：`page`、`pageSize`（默认 1 / 10，最大 100）、`processType`、`materialType`、`startDate`、`endDate`（**`yyyy-MM-dd`** 日历日，含首末日，按设备本地时区换算后过滤 `createTime`）、`order`（可选，`date_asc` \| `date_desc`，默认 **`date_desc`** 按 `createTime` 降序）、`uploadStatus`（可选整数，精确匹配 `t_params_process_video.uploadStatus`：`0` 未上传、`1` 封面已上传、`2` 视频上传中、`3` 视频已上传）。未传 `uploadStatus` 时默认仅返回 **`uploadStatus != 0`** 的行；传入时按该状态筛选（含 `0`）。`data` = `{ "list", "total" }`；`list[]` 与 `command.video_list_response` 元素同形（camelCase，含 `processParameters` 对象或 null）。 |
| POST | `/v1/videos` | 上传视频；`multipart/form-data` 字段：`file`（视频二进制）、`processType`、`materialType`、`processParameters`（JSON 文本，可选）。设备从落盘文件读取 `duration`（ms）、`resolution`（`宽x高`），并自动设置 `fileSize`、`createTime`、`videoId`（UUID）、`uploadStatus=0`、`uploadProgress=0`。无法解析时长或分辨率时返回 400 且不落库。成功 `data` 为列表项同形对象；随后后台执行封面上传（更新 `uploadStatus` / `coverUrl`）。 |
| GET | `/v1/videos/:video_id` | 单条元数据；`data` 为列表项同形对象 |
| GET | `/v1/videos/:video_id/stream` | 本地视频文件流（`video/mp4`）；无文件时 404 + `ApiResult` |
| GET | `/v1/videos/:video_id/ai` | **SSE** 推理生命周期流（`text/event-stream`），与 `/v1/camera/ai` **相同事件名**（`idle`/`start`/`running`/`stop`）；工艺片 **`timestampMs` 为源片时间轴位置（ms，从 0 起）**，与同步开始的 `/stream` 播放进度对齐。视频用 **`GET /v1/videos/:video_id/stream`**。`?force=1` 强制重新推理。不可用时 **503**。 |
| GET | `/v1/videos/:video_id/ai/replay` | **一次性 JSON** 拉取“已完成推理的完整结果”。返回 **标准 `ApiResult`**：命中时 **200** 且 `data` 为 replay JSON；无现成结果时 **404**（`ApiResult.failure`），且 **不触发推理**（只读查询）。 |
| DELETE | `/v1/videos/:video_id` | 删除本地文件与库行；`ApiResult` |

`GET /v1/videos/:video_id/ai` 订阅示例：

```bash
curl -N "http://<device-lan-ip>:5580/v1/videos/<video_id>/ai"
ffplay "http://<device-lan-ip>:5580/v1/videos/<video_id>/stream"
```

与 `/stream`（原片）、`/v1/camera/ai`（直播推理 SSE）配对使用；客户端按 **`timestampMs`** 与播放器进度对齐叠加。

`GET /v1/videos/:video_id/ai/replay` 示例（标准 `ApiResult`）：

```bash
# 命中（已存在缓存结果）→ 200 + ApiResult(data=replay JSON)
curl -s "http://<device-lan-ip>:5580/v1/videos/<video_id>/ai/replay" | jq .

# 未命中（无现成结果）→ 404 + ApiResult.failure
curl -i "http://<device-lan-ip>:5580/v1/videos/<video_id>/ai/replay"
```

`data.frames[]` 与 SSE `inference` 事件字段一致（含 `timestampMs`、`success`、`boxes` 等）；**`timestampMs` 为源片时间轴 ms**（无 `streamTimeMs`）。顶层另有 `version`、`videoId`、`generatedAtMs`（结果生成时刻）。

实现：`com.lasercyber.lws.ui.network.http.local.*`、`ProcessVideoQueryService`、`ProcessVideoDeleteHelper`。

### 工程师模式工艺库

路径参数 **`:id`** 为 Room 表 `t_process_parameters_data` 主键（HTTP 为数字；WebSocket 见 §6.2 字符串 `id` 约定）。

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| GET | `/v1/process-library` | Query **`processType`**（必填）。`data` 为摘要数组：`id`、`name`、`dataType`、`processType`、`materialType`、`materialName`（camelCase）。仅 **`dataType` 1（内置）/ 2（自定义）**。 |
| GET | `/v1/process-parameters/:id` | 单条完整工艺参数对象（camelCase，`id`/`originId` 为 JSON number） |
| POST | `/v1/process-parameters` | JSON body 创建自定义参数（`dataType` 固定为 **2**）；成功 `data` 含 `{ "id": <number> }` |
| PUT | `/v1/process-parameters/:id` | JSON body 更新；不允许改 `processType` |
| DELETE | `/v1/process-parameters/:id` | 仅可删除 **`dataType=2`（自定义）**；**`dataType=1`（内置）** 返回失败 |
| POST | `/v1/process-parameters/:id/set-default` | **无 body**；将该预设设为当前工艺类型的**激活项**（等同设备 UI 切换工艺，非“另存为常用”） |

实现：`ProcessParametersRemoteService`、`DeviceWsProcessParametersPayload`。

---

## 6. 设备 WebSocket

URL 形态（`DeviceWebSocketConfig.buildDeviceWsUrl`）：`wss://{apiHost}/ws/device?sn={urlEncode(deviceSn)}`，其中 `apiHost` 随 `BuildConfig.RELEASE_CHANNEL` 在测试/生产主机间切换。

### 6.1 统一信封（文本帧 JSON）

所有业务帧顶层字段：`v`（int，当前为 `1`）、`type`（string）、`id`（string）、`ts`（long，毫秒）、`payload`（object）。解析见 `DeviceWebSocketEnvelope`。

**会话就绪（与服务器约定，无 `connected`）**  
不再使用服务端下发的 **`connected`** 文本帧作为上线条件。WebSocket **传输层握手成功**（例如 OkHttp `onOpen`）后，连接即视为可发送业务帧；设备应尽快发送 **`device.online`**（统一信封，`payload.stat` 为远程快照 JSON 对象，与 `command.stat_response` 的 `payload.data` 相同），无需等待任何下行前置消息。对接说明见 `docs/device-websocket-migration.md`。其中 `staticData` 的 `commonUseText` 等字段约定见 **§5.5 `staticData` 快照额外字段**。

### 6.2 下行：云端命令

**单条工艺参数**

| `type`                      | 说明 |
| --------------------------- | ---- |
| `command.send_process_param` | 服务端下发；`payload` 形状见 §5.3（与 `ProcessParametersPushEnvelope` / `ProcessParametersData` 兼容）。 |

设备处理：校验信封 → `ServerPushProcessParamPayloadParser` → `ServerPushMessageHandler.saveProcessData`；并打 `DeviceChannelTelemetry`（`sourceProtocol` = WebSocket，`correlationId` = 入站帧顶层 `id`）。

**整包工艺库**

| `type` | 说明 |
| ------ | ---- |
| `command.send_process_lib` | 服务端下发；`payload` 需能映射为 **§5.4** 的 `ProcessLibrary`（版本元数据 + `dataList`），与历史 `msgType=2` 业务语义一致；可选相同信封字段（如 `data`、`msgId`、`timestamp`、`msgType`）。 |

设备处理：校验信封 → `ServerPushProcessLibPayloadParser` → `ServerPushMessageHandler.saveProcessLibrary`；`DeviceChannelTelemetry` 与 `DeviceWebSocketConnectionManager.sendProcessLibAck` 与 `command.send_process_param` 路径对齐。

**远程锁定 / 解锁**

| `type` | 说明 |
| ------ | ---- |
| `command.lock` | 服务端下发；`payload` 为空对象 `{}`。设备持久化锁定状态，禁止进入快速模式与工程师模式；若已在上述模式中则安全停机并回到首页；展示远程锁定提示与顶部锁图标。 |
| `command.unlock` | 服务端下发；`payload` 为空对象 `{}`。设备清除持久化锁定状态（唯一解锁路径，重启后仍保持锁定直至收到本命令）。 |

处理：`DeviceWebSocketConnectionManager` → `DeviceRemoteLockStore` / `DeviceRemoteLockPolicy`。

**告警清空（云端）**

| `type` | 说明 |
| ------ | ---- |
| `command.clear_alerts` | 服务端下发；`payload` 为空对象 `{}`。设备清空 Room `warn_table`（与 HMI 告警日志「清除」相同），并通知 LAN `GET /v1/monitor/alerts` 订阅方 `event: clear`。 |
| `command.clear_alerts_ack` | 设备上行；`payload` 同 `command.upload_video_ack`：`request_id` + `data.success` / `data.message` |

处理：`DeviceWebSocketConnectionManager` → `WarnListLoader.performClearAll`；发送：`sendClearAlertsAck`。

**远程快照字段 `isLocked`**

`device.online` 的 `payload.stat` 与 `command.stat_response` 的 `payload.data`（远程快照根对象）包含布尔字段 **`isLocked`**，表示当前持久化远程锁定状态，与 `command.lock` / `command.unlock` 一致。

**远程快照字段 `wifiInfo`（替代已移除的 `localIP`）**

`device.online` 的 `payload.stat` 与 `command.stat_response` 的 `payload.data`（远程快照根对象）包含对象字段 **`wifiInfo`**，表示当前已连接 Wi-Fi 的完整连接信息（与 **设置 → 网络 → 无线网络 → Wi-Fi 详情** 页同源，由 `WifiStatusUtils.getConnectedWifiInfo` 组包）。未连接 Wi-Fi、无可用 `WifiInfo` 或 `getIpAddress()` 为 0 时，`wifiInfo` 为 JSON `null`。

**BREAKING**：根级字段 **`localIP` 已移除**；请改用 `wifiInfo.ipAddress`。

**远程快照 `deviceInfo.cameraVersion`**

`device.online` 的 `payload.stat.deviceInfo` 与 `command.stat_response` 的 `payload.data.deviceInfo` 包含字符串 **`cameraVersion`**：工业摄像头固件/应用版本（与 **设置 → 设备信息 → 摄像头版本** 同源，来自 eth0 配网成功后的 `CameraDeviceInfoCache`）。摄像头离线或尚未拉取成功时为 **`-`**。

**远程快照 `deviceInfo.cameraIp`**

`device.online` 的 `payload.stat.deviceInfo` 与 `command.stat_response` 的 `payload.data.deviceInfo` 包含字符串 **`cameraIp`**：设备当前用于 HTTP/RTSP 的摄像头主机 IPv4（`model.properties` 的 `camera_ip` 或默认 IPC 地址）。云端 **`GET /v1/devices/:sn/stat`** 返回的 `deviceInfo` 与设备上报的远程快照一致（由 Worker 持久化/转发）。

**远程快照 `deviceInfo.hostIp`**

`device.online` / `command.stat_response` 的 `deviceInfo` 包含字符串 **`hostIp`**：开发宿主机 LAN IPv4（ROM `host_ip`；`make emulator` 写入，可用 `.env` **`HOST_IP`** 覆盖）。真机或未注入时为 **`""`**。

**远程快照 `deviceInfo.focusScaleRef`**

`device.online` / `command.stat_response` 的 `deviceInfo` 包含整数 **`focusScaleRef`**：枪头对焦刻度参考值（ROM `focus_scale_ref`；`make emulator` / `make prepare` 可通过 **`FOCUS_SCALE_REF`** 写入）。未配置、为空或非法时为 **`0`**，与 **设置 → 设备信息 → Focus Scale Reference** 同源。

`wifiInfo` 对象字段（camelCase；不可用标量为 JSON `null`）：

| 字段 | 类型 | 说明 |
| ---- | ---- | ---- |
| `ssid` | string | 网络名称 |
| `bssid` | string | BSSID |
| `capabilities` | string | 扫描结果原始 capabilities |
| `ipAddress` | string | IPv4 点分十进制 |
| `subnetMask` | string | 子网掩码 |
| `router` | string | 默认网关 |
| `dns` | string | 主 DNS |
| `rssi` | int | 信号强度（dBm） |
| `linkSpeed` | int | 链路速率（Mbps） |
| `frequency` | int | 中心频率（MHz） |
| `securityType` | string | `WPA3` / `WPA2` / `WPA` / `WEP` / `Open` |
| `macAddress` | string | 本机 MAC（不可用时为 `null`） |

**工程师模式工艺库远程管理**

Room 主键在 WS 中 **`id` / `originId` 建议用 JSON 字符串**（避免 JS 超过 `Number.MAX_SAFE_INTEGER`）；设备同时接受 number。上行列表/详情/创建 ack 中的 `id`、`originId` 为 **string**。

| `type` | 说明 |
| ------ | ---- |
| `command.process_library_request` | 入站；`payload.process_type`（必填） |
| `command.process_library_response` | 上行；`payload.request_id` + `payload.data` = **数组**（摘要对象，string `id`） |
| `command.process_parameters_request` | 入站；`payload.id`（string 或 number） |
| `command.process_parameters_response` | 上行；`payload.request_id` + `payload.data` = 完整对象或 `null` |
| `command.process_parameters_create` | 入站；`payload` 含 `process_type` 及工艺字段（snake_case 可选：`material_type`、`material_name`） |
| `command.process_parameters_create_ack` | 上行；`data.success` / `data.message`；成功时可选 `data.id`（**string**） |
| `command.process_parameters_update` | 入站；`payload.id` + 可更新字段 |
| `command.process_parameters_update_ack` | 上行；同 `command.upload_video_ack` 的 `data` 形状 |
| `command.process_parameters_delete` | 入站；`payload.id`；仅删 `dataType=2` |
| `command.process_parameters_delete_ack` | 上行；同上 |
| `command.process_parameters_set_default` | 入站；**仅** `payload.id`；切换该 `processType` 的激活预设 |
| `command.process_parameters_set_default_ack` | 上行；同上 |

**语义**：`set_default` = 切换当前激活工艺；持久化新自定义预设用 **create** / **update**（对应设备 UI「保存为常用」类操作）。

**工艺视频列表 / 删除**

| `type` | 说明 |
| ------ | ---- |
| `command.video_list_request` | 服务端下发；`payload` 含 `page`、`page_size`；可选 `process_type`、`material_type`、`start_date`、`end_date`（**`yyyy-MM-dd`** 字符串，与 §5.1 及云端 **`GET /v1/devices/:sn/videos`** 的 `start_date` / `end_date` 一致）、`order`（可选，`date_asc` \| `date_desc`，默认 **`date_desc`**）、`upload_status`（可选整数，语义同 HTTP `uploadStatus`；未传时默认 **`uploadStatus != 0`**） |
| `command.video_list_response` | 设备上行；`payload.request_id` = 入站顶层 `id`；`payload.data` = `{ "list", "total" }` |
| `command.delete_video` | 服务端下发；`payload.video_id` = 业务 UUID |
| `command.delete_video_ack` | 设备上行；`payload` 同 `command.upload_video_ack`：`request_id` + `data.success` / `data.message` |

### 6.3 上行：处理确认

| `type`                           | 顶层 `id` | `payload` |
| -------------------------------- | --------- | --------- |
| `command.send_process_param_ack` | **新建**（设备生成的 UUID） | `{"request_id":"<入站 command.send_process_param 的顶层 id>","code":200/500,"message":"结果说明"}` |
| `command.send_process_lib_ack`   | **新建**（设备生成的 UUID） | `{"request_id":"<入站 command.send_process_lib 的顶层 id>","code":200/500,"message":"结果说明"}` |
| `command.upload_video_ack`       | **新建** | `{"request_id":"<入站 id>","data":{"success":true/false,"message":"..."}}` |
| `command.delete_video_ack`       | **新建** | 同 `command.upload_video_ack` |
| `command.clear_alerts_ack`       | **新建** | 同 `command.upload_video_ack` |
| `command.process_parameters_*_ack` | **新建** | 变更类同 `command.upload_video_ack`；`create_ack` 成功时可带 string `data.id` |
| `command.process_library_response` / `command.process_parameters_response` | **新建** | `request_id` + `data`（库列表为数组，单条为对象） |

发送：`DeviceWebSocketConnectionManager.sendProcessParamAck`；OTA 整包工艺库：`sendProcessLibAck`；工程师库远程：`sendProcessLibraryResponse` / `sendProcessParametersResponse` 及 `sendProcessParametersMutationAck`；视频：`sendUploadVideoAck` / `sendDeleteVideoAck`；告警：`sendClearAlertsAck`。

---

## 7. 文档维护

- 修改 `app/build.gradle.kts` 中 `BASE_HTTP_URL` 后，应同步更新本文档 §1。
- 新增 Retrofit 方法：在 `com.lasercyber.lws.ui.network.http.api` 与本文档 §3 增补。
- R2 STS / 工艺视频上传行为变更：同步 §4.2 与 `DeviceR2StsS3Client`、`*R2*` handler 源码索引（§8）。
- 新增 `msgType` 或 Gson 载荷类型：更新 §5；WebSocket 消息更新 §6。

---

## 8. 源码索引（便于跳转）


| 模块                    | 路径                                                                                                                         |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Retrofit 基础 URL / 客户端 | `app/src/main/java/com/lasercyber/lws/ui/common/config/RetrofitClient.java`                                                |
| API 门面                | `app/src/main/java/com/lasercyber/lws/ui/network/http/RequestApi.java`                                                     |
| 接口定义                  | `app/src/main/java/com/lasercyber/lws/ui/network/http/api/*.java`                                                          |
| R2 STS + S3 上传        | `DeviceR2StsS3Client.java`、`ProcessVideoR2CoverUpload.java`、`ProcessVideoR2StsVideoPut.java`                               |
| 对象存储 URL 工具         | `app/src/main/java/com/lasercyber/lws/ui/common/oss/ObjectStorageUrls.java`（`joinPublicBaseUrl`、`checkVideoSize`）                 |
| 设备 SN（HTTP / R2 共用）  | `app/src/main/java/com/lasercyber/lws/ui/common/device/DeviceIdentity.java`                                                    |
| 服务端推送落库              | `app/src/main/java/com/lasercyber/lws/ui/network/channel/ServerPushMessageHandler.java`                                     |
| WS 连接与工艺参数命令        | `app/src/main/java/com/lasercyber/lws/ui/network/ws/DeviceWebSocketConnectionManager.java`                                   |
| 设备本地 HTTP（:5580，`:8080` 已废弃） | `app/src/main/java/com/lasercyber/lws/ui/network/http/local/DeviceLocalHttpServer.java`                                      |
| 网络可用时触发 WS 连接       | `app/src/main/java/com/lasercyber/lws/ui/common/call/NetworkCallback.java`                                                 |


