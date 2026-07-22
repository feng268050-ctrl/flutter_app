## Context

当前 LWS 产品：IPC ↔ 板载 `eth0` 直连，`wlan0` 走客户 Wi‑Fi（lws-ui `camera-eth0-topology.md`）。这是 **产品拓扑**，不是「IP Camera」设备的固有定义。未来产品可能改用交换机同网段、USB 网卡、或其它 path，HAL 仍应能描述同一类 IP 相机。

`cyber_hal` 已有边界：`input` = 本机输入设备（键盘/鼠标；将来经 **串口/USB** 连接、不走网络的摄像头也归这里，连接模型与其它输入设备相同）；网络 = `network`。IP 摄像头也是输入源，但 **依赖网络栈才能工作**，不能在缺少 `network` 的前提下单独成立，因此是特殊场景，**独立为顶层 `ip_camera`**，既不塞进 `input`，也不建泛化 `camera` 包。

## Goals / Non-Goals

**Goals:**

- Portable HAL `ip_camera`：主机身份、上游 RTSP 端点、健康观察（ICMP + 可扩展）、change-only Streams。
- Portable HAL 录像：输入 RTSP 候选、目标文件和编码类型；HAL 等到 muxer 首帧实际写入后才进入 recording，stop 完成封装后返回文件结果。
- 本产品 App 编排：dedicated eth0、事件驱动重配、尝试预算 UI 状态、MediaMTX on-demand、Home 图标、Settings 预览。
- 自检去 Camera Comm；Common Settings 去 Ethernet。

**Non-Goals:**

- 把 eth0 planner / MediaMTX 生命周期塞进 `IpCameraController` 公共 API。
- 泛化 `hal/camera` 包名（避免把 USB/串口摄像头与 IP 摄像头糊成一类）。
- Monitor 全页录像 / AI 叠框 / C002 弹窗完整流水线。
- 快速模式/工程师模式的业务录像、工艺参数关联、视频数据库、封面与文件管理。

## Decisions

### 1. 命名与模块位置

**Choice:** `package:cyber_hal/ip_camera.dart` → `IpCameraController` + models。  
**Not:** `hal/camera`、`hal/input/ip_camera`。

| 域 | 含义 |
|----|------|
| `ip_camera` | 经网络的 IP 摄像头（RTSP/HTTP）；输入场景，但硬依赖 network |
| `input` | 本机输入（键鼠；将来串口/USB 摄像头等同连接模型设备） |
| 产品 App | LWS eth0 专链、MediaMTX、状态栏语义（拓扑，非设备类定义） |

### 2. 两层抽象（可复用 vs 本产品）

```text
┌─────────────────────────────────────────────────────────┐
│ App product session (LWS-only)                          │
│  IpCameraProductSession                                 │
│   - DedicatedEth0Path (planner + Ethernet HAL)          │
│   - MediaMtxRelay (render + systemctl)                  │
│   - UI status: connecting | connected | failed          │
│   - GStreamer/MPP texture ← localhost MediaMTX          │
└───────────────┬───────────────────────────┬─────────────┘
                │ uses                      │ uses
                ▼                           ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│ HAL ip_camera (portable) │    │ network HAL (existing)   │
│  host, upstream streams  │    │  eth link / wifi conn    │
│  health Stream (ICMP…)   │    │  D-Bus callbacks         │
└──────────────────────────┘    └──────────────────────────┘
```

未来产品：可换掉 `DedicatedEth0Path`（例如 noop / 其它网卡），仍复用同一 `IpCameraController`；也可不用 MediaMTX，预览直接订 `camera.streams.pr0`（单消费者场景）。

### 3. HAL `IpCameraController` API（portable）

只回答：「这台 IP 相机是谁、流在哪、通不通，以及如何把指定 RTSP 流可靠录到文件」。

```dart
abstract class IpCameraController {
  /// Logical id from product config (e.g. product.ini camera_ip).
  String get cameraHost;

  /// Native streams on the camera (not local relay).
  IpCameraStreams get streams;

  Stream<IpCameraHealth> get health;
  IpCameraHealth get currentHealth;

  IpCameraRecordingController get recording;

  /// Start HAL-owned health observation. Does not configure host L3 path.
  Future<void> startMonitoring();

  /// One-shot probe (tests / ensure). Coalesced with in-flight.
  Future<IpCameraHealth> probeOnce();

  Future<void> dispose();
}

class IpCameraStreams {
  final Uri pr0; // e.g. rtsp://192.168.1.100/PR0
  final Uri pr1;
}

enum IpCameraHealthPhase { unknown, healthy, unhealthy }

class IpCameraHealth {
  final IpCameraHealthPhase phase;
  final int consecutiveOk;
  final int consecutiveFail;
  final String? detail;
  final DateTime updatedAt;
}

abstract class IpCameraRecordingController {
  Stream<IpCameraRecordingStatus> get status;
  IpCameraRecordingStatus get currentStatus;

  /// Resolves only after the muxer has received/written its first media data.
  Future<IpCameraRecordingStatus> start(IpCameraRecordingRequest request);

  /// Sends EOS, finalizes the container, and returns the saved file.
  Future<IpCameraRecordingResult?> stop();
}

enum IpCameraRecordingPhase {
  idle, preparing, recording, stopping, completed, failed
}
```

健康策略（quiet window、恢复与掉线均需连续 N 次一致结果、in-flight 合并）留在 HAL——这是对 **设备可达性** 的通用防抖，与「怎么连上网」无关。单次 ICMP 丢包不得触发 MediaMTX teardown。  
可选扩展（本切片可不暴露）：`suspendProbes()` / `resumeProbes()` 供产品在 path 重配时调用（等价 lws-ui `beginEth0Configure`），避免把 eth0 知识写进 HAL。

**构造（host 注入，与到达路径无关）：**

```dart
IpCameraController({
  required String cameraHost,           // IP 或可解析主机名
  IpCameraStreamPaths paths = const IpCameraStreamPaths.pr01(),
  IpCameraProbe? probe,                 // 可注入；默认 ICMP
});
```

- HAL **不**假设 host 经 eth0、wlan0 还是互联网可达；只对给定 `cameraHost` 做健康观察与拼上游 URI。
- **允许多实例并存**（不同 host 各一个 controller）；互不共享状态。
- **本产品 App** 只构造 **一个** 实例：`cameraHost` = `ProductInfo.cameraIp()`（`product.ini`），缺省则固定默认（如 `192.168.1.100`）。专链/MediaMTX 仍由产品 Session 负责，与「HAL 可多实例」不冲突。

**Alternatives:** 从全局单例读死配置 — 拒绝（妨碍多 IPC / 其它产品复用）。

录像同样不假设 eth0 或 MediaMTX。`IpCameraRecordingRequest` 显式携带一个或多个
RTSP 候选 URI；调用方可传相机原生 `streams.pr0`，本产品设置页则传本机
MediaMTX `previewPr0`，避免新增直连消费者。每个 controller 同时最多一个录像，
不同相机实例互不互斥。

### 4. 产品 Session API（LWS App，非 HAL）

```dart
/// Product façade — eth0 dedicated link + MediaMTX + UI phases.
abstract class IpCameraProductSession {
  IpCameraController get camera; // HAL

  Stream<IpCameraUiStatus> get status;
  IpCameraUiStatus get currentStatus;

  /// Local fan-out when relay running; null if not applicable yet.
  Uri? get previewPr0;
  Uri? get previewPr1;

  Future<void> start();           // Home first frame
  Future<void> ensureReady();     // Settings open
  Future<void> retryNow();
  Future<void> dispose();
}

enum IpCameraUiPhase { connecting, connected, failed }

class IpCameraUiStatus {
  final IpCameraUiPhase phase;
  final int attempt;
  final String? detail;
}
```

内部：

1. 订 `ethernet.link` / `wifi.connection` → debounce → **Ethernet HAL** `setInterfaceEnabled` + `setIpv4Config`（产品侧 AddressPlanner 选址；**不**另写配网 shell）
2. path 重配期间 `camera` suspend/resume probes
3. `camera.health == healthy` 且 path ok → start MediaMTX（upstream = `camera.streams`）
4. 尝试预算耗尽 → `failed`；慢重试 / 事件 → 再 `connecting`
5. 预览只绑 `previewPr*`（本产品强制经 MediaMTX，避免抢 IPC 连接）

### 5. MediaMTX 归属

**Choice:** 编排在 **产品 session**；overlay helper 通用。不放进 `IpCameraController`。  
若其它产品也要本地 fan-out，可日后再抽 `package:cyber_hal` 旁路小模块 `mediamtx`——本切片不把「必须有 MediaMTX」写进 `ip_camera` 语义。

### 6. 其余产品行为（不变）

- 自检去掉 Camera Comm；Home 图标订 `IpCameraProductSession.status`
- Settings Input → IP Camera 订 session 预览 URL，并用真实视频纹理渲染
- Network 去掉 Ethernet；`EthernetController` 仍供专链脚本/Demo

### 7. GStreamer/MPP 实时预览是本切片完成条件

**Choice:** Buildroot 启用 `lws_hmi_gst_rtsp.config`（或构建后自动选择的 `lws_hmi_gst_prebuilt.config`），其中必须包含：

- GStreamer core + RTSP/RTP/UDP/TCP、video parser
- Rockchip MPP / `gstreamer1-rockchip` 硬解路径
- flutter-pi GStreamer video player plugin
- Weston 镜像所用 flutter-embedded-linux client 链接的 Sony eLinux GStreamer `video_player` plugin 及 `libvideo_player_plugin.so`

App 使用与 flutter-pi 插件匹配的 Flutter `video_player` API（若实际插件 API 不兼容，则封装薄适配器），输入固定为产品 session 发布的本地 PR1 URL：

```text
rtsp://127.0.0.1:8554/camera/pr1
```

页面生命周期：

1. Settings 页先渲染，不等待 RTSP 首帧。
2. session `connected` 且 MediaMTX `running` 后创建并初始化 player。
3. 初始化完成后显示真实 `Texture` / 视频帧；保持宽高比。
4. relay 暂不可用、player 初始化中或重连时显示临时 establishing 占位。
5. 离开页面必须暂停并 dispose player；重新进入可重建。
6. decoder / RTSP 错误进入可重试错误状态，不允许永久停留在“ready URL”占位。

Linux 启动注册按显示栈分流：无 `WAYLAND_DISPLAY` 的默认镜像注册
`FlutterpiVideoPlayer`；Weston 环境不得覆盖 `VideoPlayerPlatform`，由
flutter-embedded-linux client 原生注册 Sony eLinux plugin。两套 embedder
共享同一 Dart `VideoPlayerController` 和预览 widget。

**Rejected:** 只显示 RTSP URL、`GStreamer surface pending` 或静态播放图标——这不是实时预览，不符合本变更规范。

### 8. 录像 readiness 闭环与设置页演示边界

Linux HAL 使用独立的编码直通 GStreamer pipeline（不为录像重复解码）：

```text
rtspsrc protocols=tcp
  → rtph264depay/rtph265depay
  → h264parse/h265parse
  → qtmux
  → filesink
```

- `start()` 先发 `preparing`，创建父目录并轮询候选 RTSP pipeline。
- 只有 GStreamer bus 的 `ASYNC_DONE`（pipeline 已 preroll、muxer 已获得媒体）
  到达后，Future 才成功并发 `recording`；仅进程启动成功不算录像开始。
- 候选流提前退出时清理残缺文件并重试，整个过程受 `readyTimeout` 约束。
- `stop()` 对 `gst-launch-1.0 -e` 发送 SIGINT/EOS，等待 MP4 trailer 完成；
  文件存在且非空才发 `completed` 并返回路径，否则发 `failed`。
- preparing 阶段也可 stop/cancel，不留下伪成功文件；dispose 必须回收进程。

设置页演示使用 PR0 本地 relay，路径沿用 lws-ui 的 `movie/日期/时间.mp4`
结构，产品根目录固定为：

```text
/userdata/storage/Videos/movie/<yyyy-MM-dd>/<yy-MM-dd_HH-mm-ss>.mp4
```

页面只显示 Record/Stop、preparing/recording 状态及停止后的保存路径提示。
它不写业务数据库、不关联工艺参数、不生成封面，也不承担快速模式/工程师模式
将来的录像协调器职责。

## Risks / Trade-offs

- **[Risk] App session 变「第二个 HAL」** → Mitigation：session 只组合；设备语义只在 `ip_camera`；单测可分别测 HAL health 与 session 状态机。
- **[Risk] 忘记 suspend probes 导致重配闪断** → Mitigation：session 在 configure 路径强制 suspend/resume；HAL 提供显式 API。
- **[Risk] 其它产品误用 LWS session** → Mitigation：session 放 `app/hmi`，不进 `cyber_hal`。
- **[Risk] host Flutter 与板端 flutter-pi 插件注册不一致** → Mitigation：播放器封装提供 host stub；Linux 真机必须验证 texture plugin 已注册、首帧可见。
- **[Risk] 软件解码导致 RK3566 负载过高** → Mitigation：优先 Rockchip MPP；真机记录 decoder/pipeline 与连续预览稳定性。
- **[Risk] UI 把进程启动误判成录像开始** → Mitigation：HAL 以 GStreamer `ASYNC_DONE`/首个可写媒体为唯一 ready 门槛，start Future 与状态 Stream 同步。
- **[Risk] 强杀导致 MP4 不可播放** → Mitigation：`gst-launch -e` + SIGINT/EOS + 有界 finalize wait；失败不返回 completed。

## Migration Plan

1. HAL `ip_camera` + tests  
2. Overlay render mediamtx + GStreamer/MPP/plugin runtime  
3. App `IpCameraProductSession` + Home/Settings/自检/Ethernet 清理  
4. App 真实 RTSP texture 预览 + 真机首帧/稳定性验收  
5. 未来产品：新 path provider，复用同一 `IpCameraController`

## Open Questions

- `suspendProbes` 是否进 v1 公共 API：建议 **要**（产品重配需要）。
- 设置页默认 `previewPr1` vs `pr0`：建议 pr1。
