# 视频流检测架构优化方案

## 一、方案背景

### 1. 当前项目的实时视频处理架构

当前项目中，实时视频流处理主要由 Java 和 C++ 分工完成：

- **Java 侧负责流媒体管线**
  - 拉流
  - 解码
  - 播放（或虚拟 Surface 后台解码）
  - 按策略抽帧
  - 将抽取到的图像帧通过 JNI 传给 C++
- **C++ 侧负责重计算任务**
  - 色彩转换
  - OpenCV 图像检测
  - 可选 RKNN 推理
  - 后处理逻辑

当前设计中，**native/C++ 不直接访问摄像头**，而是依赖 Java 侧完成拉流、解码和抽帧。

产线焊接路径上，检测已收敛到 C++ `StreamDetectPipeline`（独立 PR1 + **MPP → NV12**）；AI Vision 预览则通过 `EasyPlayerClient` + **Android MediaCodec 硬解** 播放，检测结果经 `StreamDetectResultBus` 订阅叠加。**I420 / Java 推帧检测已遗弃。**

---

### 2. 当前实时流来源

App 消费的“原始”实时视频流，默认并不是由 EasyPlayerClient 直接拉取 IPC 摄像头 RTSP，而是先经过本机 **MediaMTX** 中继转发。

实时流链路如下：

```text
IPC 摄像头
  ├─ rtsp://<camera_ip>/PR0   主流，主要用于录制
  └─ rtsp://<camera_ip>/PR1   子流，主要用于预览 / 推理
         ↓
MediaMTX 上游拉流 sourceOnDemand
         ↓
本机 MediaMTX (:8554)
  ├─ rtsp://127.0.0.1:8554/camera/pr0
  └─ rtsp://127.0.0.1:8554/camera/pr1
         ↓
EasyPlayerClient / ffplay / 局域网客户端
```

因此，App 侧真正消费的是本机 MediaMTX 中继后的本地 RTSP 地址，例如：

```text
rtsp://127.0.0.1:8554/camera/pr1
```

---

### 3. 当前实时检测链路

当前实时检测流程可以概括为：

```text
IPC 摄像头
  ↓
MediaMTX 本机中继
  ↓
Java 拉流 / 解码
  ↓
Java 按策略抽帧
  ↓
JNI 传帧给 C++
  ↓
C++ 色彩转换 / OpenCV 检测 / RKNN 推理
  ↓
C++ 返回检测结果
  ↓
Java 可视化展示
```

该方案的核心特点是：

> Java 管流媒体与抽帧，C++ 管重计算；检测链路通过 JNI 图像帧与 Java 解码耦合。

---

### 4. 当前方案存在的问题

#### 问题一：检测链路依赖 Java 解码与抽帧

检测任务必须等 Java 解码回调、抽帧 gate 放行后，才能通过 JNI 进入 C++。

C++ 无法独立控制接流、解码节奏、断流重连和抽帧策略，检测与 Java 流媒体管线强耦合。

#### 问题二：历史上 Java 到 C++ 存在 YUV 跨语言传输（已遗弃）

旧方案经 JNI 传递 **I420**（约 3MB/帧拷贝 + 线程调度）。当前架构 **禁止** live 路径 YUV JNI；C++ 侧 **MPP 硬解 → NV12 → BGR** 进程内完成检测，Java 仅订阅 JSON 结果。

在 500ms 抽帧下单次开销通常为个位数毫秒，但链路仍比 native 内直连 `libai.so` 更长。

#### 问题三：检测专用解码与播放/录制解码职责混杂

- 焊接检测：`LivePr1InferenceStreamClient` 单独维护一套 Java RTSP + 解码（无 UI）
- 录制：`EasyPlayerClientManger` 消费 PR0
- AI Vision：`EasyPlayerClient` 播放 + `TextureView.getBitmap` 抽帧（路径效率低于 I420 回调）

多套 Java 解码客户端并存，职责边界不清晰。

#### 问题四：播放策略变更会牵连检测

Java 播放、解码、抽帧策略（硬解/软解回退、Surface 模式、采样间隔）变化时，检测链路需同步适配。

---

### 5. 离线 MP4 场景说明

离线场景与实时 RTSP 场景不同。

对于已经录制好的 MP4 文件，当前仍然走：

```text
ExoPlayer 播放
  ↓
文件路径 / 逐帧 JNI 单帧推理
  ↓
C++ 检测
  ↓
Java 展示结果
```

该流程不经过实时 RTSP 管线，也不经过 MediaMTX 实时中继。

因此，本次优化主要针对：

> 实时 RTSP 视频流检测场景。

离线 MP4 场景暂时保持现有方案。

---

## 二、架构原则（核心）

### 1. 双链路分离：播放解码 ≠ 检测解码

本方案的**根本原则**是：

> **不是用 C++ 替代 Java 的播放解码能力，而是将「播放解码」和「检测解码」拆成两条独立链路。**

| 链路 | 负责方 | 用途 | 解码方式 |
|------|--------|------|----------|
| **播放链路** | Java / `EasyPlayerClient` | UI 预览、用户可见画面 | **Android 系统 `MediaCodec` 硬解** → Surface/TextureView |
| **检测链路** | C++ / `libai.so` | OpenCV / RKNN 实时检测 | **Rockchip MPP 硬解 → NV12**（**不**使用 OS MediaCodec / NdkMediaCodec） |

两条链路**并行消费** MediaMTX 本地子流 `rtsp://127.0.0.1:8554/camera/pr1`，各自独立拉流、独立解码、互不传图像帧。

```text
IPC 摄像头 PR1
  ↓
本机 MediaMTX 中继 (:8554/camera/pr1)
  ├─【播放链路】Java EasyPlayerClient
  │     → Android MediaCodec 硬解
  │     → Surface / TextureView 渲染
  │     → UI 流畅播放
  │
  └─【检测链路】C++ StreamDetectPipeline
        → MPP 硬解（H.264/H.265 → NV12）
        → NV12 → BGR/RGB（进程内，无 JNI 图像传输）
        → OpenCV / RKNN（现有 libai.so 检测逻辑）
        → 发布检测结果（Pub）→ Java 订阅（Sub）→ 叠加 / 告警 / SSE
```

### 2. C++ 检测像素格式：MPP → NV12 → BGR/RGB

检测链路在 C++ 内约定**单一 YUV 契约 NV12**（**I420 已遗弃**）：

| 阶段 | 格式 | 说明 |
|------|------|------|
| **MPP 硬解输出** | **NV12** | Rockchip MPP；stride-aware，不依赖 Android/Linux OS 解码 API |
| **检测输入** | **BGR 或 RGB** | `NV12 → BGR`（OpenCV，`cv::COLOR_YUV2BGR_NV12`）或 adapter 内 BGR→RGB（RKNN） |

```text
H.264 Access Unit
  ↓
MPP Decoder → NV12（Y + 交错 UV）
  ↓
BGR 或 RGB（cv::Mat，进程内）
  ↓
OpenCV / RKNN detect
```

**要点：**

- C++ 检测 **必须** 使用 **MPP** 输出 NV12；**不得**用 `NdkMediaCodec` 或 Java 解码回调替代检测解码。
- Java 播放 **可以** 使用 Android `MediaCodec`（`EasyPlayerClient`），与检测链路无关。
- 全栈（live / offline JNI）YUV 契约为 **NV12**；legacy planar 输入仅在 ingress 一次性转换，不作为主路径。

### 3. Java ↔ C++ 通信：发布-订阅（Pub-Sub）

检测链路与 UI/业务之间采用 **发布-订阅** 模式，**不传图像帧**，只传轻量事件与结果：

```text
【Publisher · C++】StreamDetectPipeline
  发布：detect_result / pipeline_state / session_start|stop / error
        （JSON 或结构化字段：timestampMs、frame_id、code、boxes…）
        ↓ JNI 事件桥（native → Java 单入口）
【Event Bus · Java】StreamDetectResultBus（或等价 Facade）
  订阅者（Subscribers）各自消费，互不阻塞检测线程：
    · DetectionOverlayView / AiVisionFragment     → 叠加框绘制
    · OpencvStainDetectCoordinator 等 Coordinator  → 告警、burst 状态机
    · CameraAiHttpPublisher                       → SSE `/v1/camera/ai`
    · EventBus / 日志 / 可观测性                   → 调试与埋点
```

| 角色 | 职责 |
|------|------|
| **Publisher（C++）** | 抽帧、检测完成后发布结果；管线状态变化时发布 `running` / `idle` / `error` |
| **Subscriber（Java）** | 注册监听；按 `timestampMs` / `frame_id` 缓存最近一次结果并驱动可视化 |
| **控制面（Java → C++）** | 非 Pub-Sub 内容：会话 `start/stop`、激光 ON/OFF、burst 模式、模块开关、ROI 路径（命令式 JNI） |

**原则：** C++ 只负责**发布**；Java 侧**订阅**后自行决定如何展示、是否上报告警或写 SSE。播放链路（`EasyPlayerClient`）与订阅链路解耦，检测异常时播放继续，订阅方显示「检测中断」或隐藏 overlay。

### 4. 明确非目标

- **不**用 C++ 接管 UI 播放解码，**不**替换 `EasyPlayerClient` 的播放能力
- **不**绕过 MediaMTX 直连 IPC 摄像头（检测仍消费 `127.0.0.1:8554/camera/pr1`）
- **不**在 Java 与 C++ 之间传输图像帧（仅传输轻量检测结果与状态）
- **不**改造离线 MP4（ExoPlayer + 文件/逐帧 JNI）路径

### 5. 与「C++ 独占解码」方案的区别

若将检测解码迁到 C++ 的同时**取消** Java 播放解码，会影响 AI Vision 等需要屏幕预览的场景。

本方案保留 Java 播放硬解，仅将**检测专用**解码从 Java 迁出，是**增量拆分**而非整体替换。

---

## 三、优化目标

本次优化的核心目标是：

> **播放继续由 Java 负责（Android MediaCodec）；检测由 C++ 独立接入 MediaMTX 本地 PR1，MPP 硬解 → NV12 → BGR/RGB 进入 OpenCV / RKNN，不再经过 Java 抽帧与 YUV JNI；C++ 以发布-订阅模式推送检测结果，Java 订阅后完成可视化与业务。**

C++ 推荐接入地址：

```text
rtsp://127.0.0.1:8554/camera/pr1
```

---

## 四、优化后的实时链路

### 4.1 总体架构

```text
                    ┌─────────────────────────────────────┐
                    │     MediaMTX  :8554/camera/pr1      │
                    └──────────────┬──────────────────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              │                                         │
    【播放链路 · Java】                      【检测链路 · C++】
    EasyPlayerClient                         StreamDetectPipeline
    Android MediaCodec 硬解 → Surface        MPP 硬解 → NV12 → BGR/RGB → OpenCV / RKNN
    不负责检测、不传帧
              │                                         │
              │              Pub：检测结果 / 管线状态       │
              └──────────────────┬──────────────────────┘
                                 ↓ JNI 事件桥
                    Sub：Overlay / Coordinator / SSE / 告警
```

### 4.2 按业务场景

#### 场景 A：AI Vision 实时预览（播放 + 检测叠加）

- Java：`EasyPlayerClient` + `TextureView`，**硬解播放** PR1
- C++：并行拉同一条 `camera/pr1`，**MPP 硬解 + 检测**
- 存在双路解码；需 RK3566 实测 CPU/温升/卡顿（见第七节）

#### 场景 B：Quick / Engineer 焊接检测（无 UI 播放）

- Java：**不再**需要 `LivePr1InferenceStreamClient` 做检测解码
- C++：独占 PR1 检测链路（**MPP → NV12** → 检测）
- 录制仍走 PR0 + `EasyPlayerClientManger`，与检测无关
- 此场景为**替换**现有 Java 检测解码，**不增加**播放侧解码

#### 场景 C：手动零点 / 临时 PR1 采样

- 逐步收敛到统一 C++ 检测管线，避免再创建独立 `LivePr1InferenceStreamClient` 实例

---

## 五、核心变化

### 原方案

```text
Java 拉流 → Java 解码 → Java 抽帧 → JNI 传帧 → C++ 检测 → Java 展示
```

### 新方案

```text
【播放】Java 拉流 → Java 硬解 → 播放 / UI
【检测】C++ 拉流 → **MPP 硬解** → NV12 → BGR/RGB → 抽帧 → OpenCV/RKNN → Pub 结果 → Java Sub 展示
```

核心变化：

| 项目 | 原方案 | 新方案 |
|------|--------|--------|
| UI 播放解码 | Java | **仍 Java**（硬解优先） |
| 检测解码 | Java（`LivePr1InferenceStreamClient` 等，已移除） | **C++ MPP → NV12** |
| 检测帧格式 | Java 侧 I420 再 JNI（已遗弃） | **C++ MPP → NV12 → BGR/RGB** |
| 图像帧 JNI | 每帧 YUV 传入（已遗弃） | **取消** |
| 检测触发 | Java 抽帧 gate | **C++ 内部调度** |
| Java ↔ C++ 结果通道 | Coordinator 持帧 + JNI 同步调用 | **发布-订阅**（C++ Pub，Java Sub） |
| Java 职责 | 流 + 帧 + UI | **播放 + 订阅结果 + 可视化 + 业务** |

---

## 六、推荐实现方案

### 1. Java 侧（播放链路）

继续使用 `EasyPlayerClient` 播放 MediaMTX 本地流：

```text
rtsp://127.0.0.1:8554/camera/pr1
```

**负责：**

- RTSP 拉流与 **Android MediaCodec 硬解**（与现有播放器一致）
- `TextureView` / `Surface` 渲染，保证 UI 流畅
- **订阅** C++ 发布的检测事件（`StreamDetectResultBus` 或等价 Listener 注册）
- 作为 Subscriber 驱动 `DetectionOverlayView` 叠加、`CameraAiHttpPublisher` SSE、告警与业务状态机
- 激光 ON/OFF、burst 等**控制命令**经 JNI 下发 C++（命令面，非 Pub-Sub）

**不再负责（检测相关）：**

- 为检测目的维护 `LivePr1InferenceStreamClient` 或 `I420DataCallback`
- `TextureView.getBitmap` 抽帧喂检测
- 检测专用 YUV JNI（**I420 已遗弃**）

**焊接路径注意：** 无 UI 播放时，Java 侧**无需**为检测再拉 PR1；仅 C++ 检测链路消费 PR1。

---

### 2. C++ 侧（检测链路）

在 `libai.so` 内新增 **StreamDetectPipeline**（名称待定），独立接入：

```text
rtsp://127.0.0.1:8554/camera/pr1
```

**负责：**

- RTSP 拉流（便携 RTSP/TCP + RTP/H.264 AU）
- **视频硬解：Rockchip MPP**（H.264/H.265 → **NV12**）；**不**使用 Android `NdkMediaCodec` / Java `MediaCodec`
- **像素格式**：MPP 输出 **NV12**，再转 **BGR**（OpenCV）或 **RGB**（RKNN 需要时）
- 按检测频率抽帧（500ms 常态 / 100ms burst，与现有 `AiFrameSamplingInterval` 对齐）
- 进程内直接进入现有检测入口（`analyzeBgr` / detector，不经过 JNI 图像）：
  - `opencv_stain_detect::Session`（lens_det）
  - `zero_point` / `edgedrawing` 检测器
  - 可选 RKNN 流式路径（产品开关打开时；输入为 BGR/RGB `cv::Mat`）
- 断流重连、解码异常恢复、资源释放
- **发布（Pub）** 轻量检测结果与管线状态，经 JNI 事件桥交给 Java 订阅方

**不负责：**

- UI 播放与 Surface 渲染
- 替代 Java `EasyPlayerClient` 的播放解码

**与现有 libai.so 对接：**

检测算法**复用**现有 `analyzeBgr` / detector 实现；新管线外壳为「拉流 + **MPP** + NV12 + 色彩转换 + 调度 + **结果发布**」。详见 [`MPP.md`](MPP.md)。

---

### 3. Java 与 C++ 通信（发布-订阅）

**不传输图像帧**；结果与状态走 **Pub-Sub**，控制走 **命令式 JNI**。

#### 3.1 发布-订阅（结果与状态）

| 事件类型（Publisher →） | 载荷要点 | 典型 Subscriber |
|-------------------------|----------|-----------------|
| `detect_result` | 检测 JSON、`timestampMs`、`frame_id`、`code`、`boxes`… | `DetectionOverlayView`、`OpencvStainDetectCoordinator` |
| `pipeline_state` | `running` / `idle` / `error`、断流/重连原因 | UI 状态文案、可观测性 |
| `session_start` / `session_stop` | `sessionId`、`source`、采样间隔 | `CameraAiHttpPublisher`（SSE `start`/`stop`） |
| `error` | `code`、`message` | SSE `error`、日志 |

- **Publisher**：C++ `StreamDetectPipeline` 在检测线程完成一帧后发布；JNI 层提供**单一上行回调**（或少量按模块分 topic），避免每个 Subscriber 各绑一套 native 回调。
- **Subscriber**：Java 侧 `StreamDetectResultBus`（或 Facade）注册监听；Overlay、SSE、告警等**只订阅、不回调进 C++**。
- 检测结果的 JSON 字段与返回码由算法侧统一规定（参见 `OPENCV_STAIN_DETECT_NATIVE_API.md`、`ZERO_POINT_NATIVE_API.md` 等），本文档不重复定义。

#### 3.2 控制面（Java → C++，非 Pub-Sub）

| 命令 | 说明 |
|------|------|
| `start` / `stop` | 检测管线会话启停 |
| `setLaserOn` | 激光状态同步 |
| `setBurstMode` | burst 采样（如 `code=-5` 后 100ms） |
| 模块开关 / ROI 路径 | lens_det、zero_point、edgedrawing 启用与配置 |

#### 3.3 Coordinator 角色调整

沿用现有 Coordinator 时，其职责**降级为 Subscriber + 业务编排**（激光事件、告警、Modbus 校正、转发 SSE），**不再持有 YUV 帧**，也不再在检测热路径上同步调用 JNI 传图。

---

## 七、方案收益

### 1. 检测喂帧路径更短

C++ **MPP → NV12 → BGR/RGB**，帧直达 OpenCV / RKNN，省去：

- Java YUV 拷贝与 JNI（**I420 路径已遗弃**）
- Java 检测线程池调度

检测算法本身耗时不变；**进 libai.so 的前置链路**更短，burst 100ms 场景收益相对更明显。

### 2. 播放与检测解耦

- Java 播放策略（硬解/软解回退、Surface 生命周期）变更**不影响** C++ 检测解码
- C++ 断流重连、抽帧频率调整**不影响** UI 播放流畅性

### 3. Java 播放链路保持成熟能力

继续使用已验证的 `EasyPlayerClient` + Android 硬解，**不冒险**用 native 播放替代 UI 管线。

### 4. 焊接场景可减掉一套 Java 检测解码

移除 `LivePr1InferenceStreamClient` 后，产线路径不再维护「无 UI 的 Java 检测解码器」，检测资源集中在 C++ 一侧。

---

## 八、需要注意的问题

### 1. 双路解码与 MediaMTX 多读者

AI Vision 等**同时播放 + 检测**的场景下，Java 与 C++ 各解码一路 PR1：

- MediaMTX **设计上支持**多下游读者；上游 IPC 仍只拉一路（`sourceOnDemand`）
- 需在 **RK3566** 上实测：双路 1080p 硬解 + OpenCV 的 CPU、内存、温升
- C++ 检测失败**不得**影响 Java 播放（独立 RTSP 会话）

焊接场景（场景 B）仅 C++ 解码 PR1，**无**播放侧双解码问题。

### 2. 播放画面与检测结果可能不同步

两条独立解码链路存在缓冲差异。

建议：

- 检测结果携带 `timestampMs` / `frame_id`
- Java 维护最近一次结果缓存，允许 **100ms～300ms** 可视化容忍
- 结果超时后显示「检测中」或隐藏 overlay
- **不**因检测延迟而阻塞或暂停播放

### 3. C++ 流媒体栈需从零建设

当前 `libai.so` 已具备 `StreamDetectPipeline` + RTSP/TCP；检测解码 backend 目标为 **MPP → NV12**（过渡态可能仍含 `MediaCodecDecoder`，见 [`MPP.md`](MPP.md) §4）。

需持续验收：

- RTSP 客户端 + demux / RTP
- **MPP** 实时硬解 + **NV12** + BGR/RGB 转换
- 与现有 `opencv_stain_detect` / `zero_point` / `edgedrawing` 的进程内衔接
- JNI **发布-订阅**事件桥（`StreamDetectResultBus`）与 Java 订阅方对接
- 断流重连、线程退出、与 Java 生命周期联动

### 4. 业务状态机迁移

以下逻辑目前在 Java，迁移时需明确归属：

| 逻辑 | 建议 |
|------|------|
| `LaserDetectSamplingCoordinator` burst（`code=-5` → 100ms） | C++ 调度器实现，或 Java 发控制信号、C++ 执行 |
| 激光 ON/OFF 启停检测 | Java 监听 `DeviceStatus`，调用 native `start/stop` |
| `CameraAiHttpPublisher` SSE | 仍 Java，作为 **Subscriber** 消费 C++ 发布的事件 |
| OpenSpec 中 PR1 Java YUV 推帧 / `LatestI420FrameHolder` | **已遗弃**；规格以 NV12 + MPP 为准 |

### 5. C++ 异常时的用户体验

C++ 拉流/解码/检测异常时：

- Java 播放**继续**
- UI 显示「检测异常 / 检测中断」
- 日志与 SSE `error` / `stop` 事件上报

---

## 九、分阶段落地建议

### 第零阶段：收敛现状（可选，低风险）

- 统一 PR1 消费者，避免多处创建 `LivePr1InferenceStreamClient`
- AI Vision：播放仍 Java 硬解；检测侧先不双开 C++，仅去掉 `getBitmap` 等低效路径（若尚未迁移到 C++）
- 在 RK3566 上 profile 当前 Java 检测路径基线

### 第一阶段：焊接路径 — C++ 独占 PR1 检测解码

**目标（场景 B，无 UI 播放）：**

- 下线 `LivePr1InferenceStreamClient` 检测解码
- C++ `StreamDetectPipeline` 拉 `rtsp://127.0.0.1:8554/camera/pr1`，native 硬解稳定取帧
- Java 播放/录制（PR0）不受影响
- MediaMTX 负载正常

此阶段**不涉及** Java 播放双解码，风险最低，建议优先。

### 第二阶段：接入检测算法与 Java 回调

- C++ 内 NV12 → BGR/RGB、抽帧 → 复用 OpenCV lens_det / zero_point / edgedrawing
- 实现 JNI 发布-订阅事件桥；Java `StreamDetectResultBus` + Coordinator 改为 Subscriber / 业务层
- 对齐 500ms / 100ms burst 行为
- 可选 RKNN `pushFrame` 流式路径（产品开关）

### 第三阶段：AI Vision 双链路验收（场景 A）

- Java `EasyPlayerClient` 硬解播放 PR1
- C++ 并行检测同一条 `camera/pr1`
- 验证 UI 流畅 + overlay 同步 + 双路硬解资源预算
- 若不通过：保留 Java 播放，检测仍仅 C++ 单链路（焊接模式），AI Vision 暂维持过渡方案

### 第四阶段：稳定性与可观测性

- `timestamp` / `frame_id`、结果超时、断流重连
- 性能统计（解码 ms、检测 ms、端到端 ms）
- 更新 OpenSpec / `OPENCV_DETECT_APP_INTEGRATION.md` 六层 checklist

---

## 十、最终结论

本方案的核心是：

> **播放解码与检测解码分离：Java / EasyPlayerClient 继续用 Android 硬解负责 UI 播放；C++ 独立接入 MediaMTX 本地 PR1，native 硬解后统一 NV12 并转 BGR/RGB 送入 OpenCV / RKNN，以发布-订阅模式向 Java 推送检测结果，由 Java 订阅方完成可视化。**

需要明确：

1. **不是** C++ 替代 Java 播放，而是**两条独立解码链路**并行工作。
2. 检测链路**取消** Java 抽帧与 JNI 图像帧传输；C++ 内 **NV12 → BGR/RGB** 为统一色彩入口。
3. Java 与 C++ 之间对检测结果采用 **发布-订阅**（C++ Pub，Java Sub），控制命令仍走 JNI 命令面。
4. C++ 检测异常**不影响** Java 视频播放。
5. 焊接场景可先落地「C++ 独占 PR1 检测」；AI Vision「播放 + 检测」双解码需单独压测。
6. 离线 MP4 保持 ExoPlayer + 文件/逐帧 JNI，不纳入本次改造。

推荐落地顺序：

```text
Phase 1  焊接：C++ 替换 LivePr1 检测解码（单链路，风险低）
Phase 2  接入 OpenCV/RKNN + Java 结果回调
Phase 3  AI Vision：Java 播放 + C++ 检测双链路压测
Phase 4  同步、重连、规格与文档
```

---

## 十一、实现状态（2026-07）

| Phase | 状态 | 说明 |
|-------|------|------|
| 0 | ✅ | PR1 消费者收敛；AI Vision bitmap 默认关 |
| 1–2 | ✅ | `StreamDetectPipeline` + bus + Coordinator 订阅 |
| 3 | ✅ 代码 / ⏳ RK3566 | 双链路已实现；压测见 OpenSpec checklist；FAIL → 4.4 fallback（默认 flag off） |
| 4 | ✅ | 重连 backoff 常量化、stale overlay、perf 日志、5.6b 移除 Java PR1 回退 |

**文档：** [`OPENCV_DETECT_APP_INTEGRATION.md`](OPENCV_DETECT_APP_INTEGRATION.md) §9 · [`STREAM_DETECT_NATIVE_API.md`](../native/lensinspector/docs/STREAM_DETECT_NATIVE_API.md)

**待 RK3566 sign-off：** tasks 2.8、6.1–6.2、6.4（无法测试期间跳过）。
