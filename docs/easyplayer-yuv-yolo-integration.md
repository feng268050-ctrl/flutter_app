# EasyPlayerClient 解码输出格式与 YOLO 接入说明

本文档说明 `library` 模块中 `EasyPlayerClient` 的视频解码路径、回调中可获得的像素格式、C++/OpenCV 侧 `cv::cvtColor` 的选择依据，以及启用 `I420DataCallback` 后预览渲染的同步策略分析。

---

## 目录

- [1. MQTT 与视频帧无关](#1-mqtt-与视频帧无关)
- [2. EasyPlayerClient 的两条解码路径](#2-easyplayerclient-的两条解码路径)
- [3. 子分支 B1：硬解 + 读 OutputBuffer](#3-子分支-b1硬解--读-outputbuffer)
- [4. 子分支 B2：软解（FFmpeg JNI）](#4-子分支-b2软解ffmpeg-jni)
- [5. 像素格式结论表](#5-像素格式结论表)
- [6. OpenCV（C++）侧转换建议](#6-opencvc侧转换建议)
- [7. 预览渲染与 CPU 帧同步策略分析](#7-预览渲染与-cpu-帧同步策略分析)
- [8. 三种接入方案对比](#8-三种接入方案对比)
- [9. 接入 YOLO 时在 Java 侧需要做的事](#9-接入-yolo-时在-java-侧需要做的事)
- [10. 相关源码索引](#10-相关源码索引)

---

## 1. MQTT 与视频帧无关

视频帧**不是**从 `MQTTManager` 的 `messageArrived` 等 MQTT 回调里拿到的。视频数据来自 RTSP 拉流，在 `EasyPlayerClient` 内部解码。

---

## 2. EasyPlayerClient 的两条解码路径

源码位置：`vendor/easydarwin/src/main/java/org/easydarwin/video/EasyPlayerClient.java`。

### 2.1 路径 A：MediaCodec 硬解码 → 直出 Surface（当前 App 默认）

- 构造时若 **`I420DataCallback` 为 `null`**（例如 `EasyPlayerClientManger` 中 `new EasyPlayerClient(..., null)`），则：
  - `MediaCodec.configure(..., surface, ...)` 将解码结果直接送到 **Surface**。
  - `releaseOutputBuffer(..., render=true)`，**拿不到**可供 CPU 处理的 `byte[]` / `ByteBuffer` 帧数据。

**结论：在现有集成方式下，没有"解码后的 YUV byte[]"可供 YOLO 直接使用。**

### 2.2 路径 B：传入 `I420DataCallback` 时

接口定义：

```java
public static interface I420DataCallback {
    void onI420Data(ByteBuffer buffer);
}
```

此时存在两个子分支，但最终进入 `onI420Data` 的缓冲区在设计上均为 **I420（YUV420P）**。

---

## 3. 子分支 B1：硬解 + 读 OutputBuffer

- `MediaCodec` 配置为 `COLOR_FormatYUV420Flexible`，实际输出颜色格式由 `CodecSpecificDataUtil.selectColorFormat()` 在运行时从解码器能力中选取。
- 当 `mColorFormat` 为 **SemiPlanar**（如 `COLOR_FormatYUV420SemiPlanar` 等）时，代码将 OutputBuffer 拷到 `byte[]`，再调用：

  `JNIUtil.yuvConvert(in, width, height, 4)`

- `JNIUtil`（`vendor/easydarwin/.../JNIUtil.java`）中 mode 含义：`4` = **yuvuv_to_yuv**，即从 **NV12 类交错 UV** 转为 **I420 三平面**。
- 若解码器直接给出 **Planar** 格式，则不会走上述 SemiPlanar 分支，OutputBuffer 本身即接近 **I420** 布局。

**结论：`onI420Data` 收到的是 I420，不是 NV21。**

---

## 4. 子分支 B2：软解（FFmpeg JNI）

硬解初始化失败时会回退到 `VideoCodec.VideoDecoderLite.decodeFrameYUV()`，经 native `decodeYUV`（`libproffmpeg` / `libVideoCodecer`）输出；FFmpeg 侧典型为 **YUV420P（I420）**，同样通过 `onI420Data` 传出。

---

## 5. 像素格式结论表

| 问题 | 答案 |
|------|------|
| `onI420Data` 里是 NV21 吗？ | **否** |
| 实际格式 | **I420（YUV420P）**：Y 平面 + U 平面 + V 平面 |
| 典型大小 | `width * height * 3 / 2` 字节 |
| 当前工程是否启用该回调？ | **否**（构造时 callback 为 `null`） |

---

## 6. OpenCV（C++）侧转换建议

将 **I420** 转为 BGR 再送 YOLO：

```cpp
// buffer: I420 连续内存，高为 height * 3/2，宽为 width，单通道
cv::Mat yuv(height * 3 / 2, width, CV_8UC1, bufferPtr);
cv::Mat bgr;
cv::cvtColor(yuv, bgr, cv::COLOR_YUV2BGR_I420);
// 或使用 RGB：
// cv::cvtColor(yuv, bgr, cv::COLOR_YUV2RGB_I420);
```

**不建议**使用 `COLOR_YUV2BGR_NV21` / `COLOR_YUV2BGR_NV12`，除非已确认缓冲区实为 NV21/NV12，否则颜色会错乱。

---

## 7. 预览渲染与 CPU 帧同步策略分析

> 核心问题：启用 `I420DataCallback`（路径 B）后，渲染路径从"MediaCodec 直出 Surface"变成了"二次渲染"，
> 原有的预览行为会改变。App 侧目前有没有处理方案？

### 7.1 当前现状：App 侧没有实时预览需求

经过源码审计，**现有 App 实际上不存在实时 RTSP 预览画面**。证据如下：

| 调用位置 | 传入的 Surface | 是否渲染到屏幕 |
|----------|---------------|---------------|
| `EasyPlayerClientManger` 构造 | `createVirtualSurface()` → 匿名 `SurfaceTexture(0)` | **否**，是脱屏的虚拟 Surface |
| `BackgroundLoopRecorder.start()` | 同上，`createVirtualSurface()` | **否**，纯后台录制 |

两处构造的 Surface 都是 `new SurfaceTexture(0)` 创建的**虚拟 Surface**，没有关联任何 `TextureView` / `SurfaceView`。它们只是用来满足 `MediaCodec.configure()` 需要一个 Surface 参数的要求，实际帧不会显示在屏幕上。

App 内唯一的"视频播放"出现在 `ProcessVideoDetailsActivity`，那里使用的是 **ExoPlayer (Media3)** 播放已录制好的本地 MP4 文件，完全不涉及 `EasyPlayerClient`。

**结论：当前 App 根本没有"实时预览"功能，不存在预览丢失的问题。**

### 7.2 `EasyPlayerClient` 内部已经有的二次渲染机制

即便未来需要加预览，`EasyPlayerClient` 已内置了二次渲染通路。当 `i420callback != null` 时：

#### 硬解路径（子分支 B1）

```
MediaCodec 解码（Surface=null, OutputBuffer 模式）
    ↓ 读取 OutputBuffer
    ↓ SemiPlanar→I420 转换（如需要）
    ↓
    ├→ i420callback.onI420Data(tmp)       // 送 YOLO
    └→ displayer.decoder_decodeBuffer(tmp, w, h)  // 二次渲染到 Surface
```

关键代码（第 1185-1188 行）：

```java
i420callback.onI420Data(tmp);
displayer.decoder_decodeBuffer(tmp, realWidth, realHeight);
```

`displayer` 是 `VideoCodec.VideoDecoderLite` 实例，构造时绑定了 `mSurface`。
`decoder_decodeBuffer` 调用 native `decodeYUV2(handle, buffer, w, h)`，
将 I420 数据通过 FFmpeg/libyuv **重新渲染到 Surface** 上。

> 注意：`releaseOutputBuffer(index, false)` — render 参数为 `false`，
> 说明 MediaCodec 不再负责渲染，渲染完全由 `displayer` 接管。

#### 软解路径（子分支 B2）

软解通过 FFmpeg 的 `decodeFrameYUV` 已经完成了解码 + Surface 渲染（FFmpeg 内部直接写 Surface），额外再通过 `onI420Data` 把 I420 数据抛出。不存在渲染中断问题。

#### 遗留缺陷：Planar 格式下 i420callback 与 displayer 均未被调用

当 `mColorFormat` 为 `COLOR_FormatYUV420Planar` 或 `COLOR_FormatYUV420PackedPlanar` 时，
代码只进入了 `sliceHeight != realHeight` 的 padding 处理分支，但**未进入** SemiPlanar 的 `if` 块，
因此 `i420callback.onI420Data()` 和 `displayer.decoder_decodeBuffer()` **都不会被调用**。

```
if (mColorFormat == SemiPlanar类...) {
    // ← 只有 SemiPlanar 才走这里
    i420callback.onI420Data(tmp);
    displayer.decoder_decodeBuffer(tmp, ...);
}
// ← Planar 格式落到这里：既无回调、也无二次渲染
mCodec.releaseOutputBuffer(index, false);  // render=false → 画面丢失
```

**这是 EasyPlayerClient 的一个潜在 bug**：Planar 解码器 + i420callback 场景下，预览和回调都会丢失。

### 7.3 对当前 App 的影响评估

```
┌──────────────────────────────────────────────────────────────────────────┐
│                  影响矩阵（App 当前使用方式 + 改造后）                    │
├──────────────────────┬──────────────────┬────────────────────────────────┤
│ 场景                 │ 预览是否受影响？  │ 原因                          │
├──────────────────────┼──────────────────┼────────────────────────────────┤
│ 当前：录制模式       │ 不影响           │ 使用虚拟 Surface，本来就不渲染 │
│ (EasyPlayerClient    │                  │ 录制走 pumpVideoSample 独立    │
│  Manger)             │                  │ 通道，与解码渲染通路无关       │
├──────────────────────┼──────────────────┼────────────────────────────────┤
│ 改造后：加 callback  │ 不影响           │ 虚拟 Surface 仍在，displayer   │
│ 仅做 YOLO 推理      │                  │ 会往虚拟 Surface 写但无人看    │
│ 不加实时预览         │                  │                                │
├──────────────────────┼──────────────────┼────────────────────────────────┤
│ 改造后：加 callback  │ 需关注           │ 需将 Surface 换为真实的        │
│ 且需要实时预览       │                  │ TextureView/SurfaceView；      │
│                      │                  │ 且需修复 Planar 格式遗漏 bug   │
└──────────────────────┴──────────────────┴────────────────────────────────┘
```

### 7.4 录制功能是否受影响

**不受影响。** 录制走的是完全独立的通路：

```
RTSP 收帧 → onRTSPSourceCallBack1
    ↓ 同时做两件事（互不干扰）
    ├→ mQueue.put(frameInfo)         → 送解码线程（渲染/回调）
    └→ pumpVideoSample(frameInfo)    → 直接写原始 H.264/H.265 到 EasyMuxer2
```

`pumpVideoSample` 写入 Muxer 的是 **编码后的原始 NAL 数据**，不是解码后的 YUV，
所以无论解码路径怎么改，MP4 录制都不受影响。

---

## 8. 三种接入方案对比

### 方案 A：仅加 I420DataCallback，不做实时预览（推荐起步方案）

```java
// EasyPlayerClientManger 构造时改为：
client = new EasyPlayerClient(Utils.getApp(), virtualSurface, null,
    buffer -> {
        // I420 帧送 YOLO（注意拷贝，buffer 生命周期短）
        ByteBuffer copy = ByteBuffer.allocateDirect(buffer.remaining());
        copy.put(buffer);
        copy.flip();
        yoloInferenceQueue.offer(copy);
    }
);
```

| 优点 | 缺点 |
|------|------|
| 改动最小，仅改一行构造参数 | 无实时预览画面（当前本来也没有） |
| 录制功能完全不受影响 | — |
| displayer 会自动往虚拟 Surface 二次渲染（不报错） | — |

**适合**：只需要检测结果（如报警、数据记录），不需要在屏幕上显示检测框。

### 方案 B：I420DataCallback + 实时预览（未来需要时）

```java
// 用真实的 TextureView 构造
EasyPlayerClient client = new EasyPlayerClient(
    context, textureView, resultReceiver, i420Callback, seiCallback
);
```

`EasyPlayerClient` 有一个接收 `TextureView` 的构造函数（第 346 行），
内部通过 `TextureLifecycler` 管理生命周期，自动绑定 Surface。

| 优点 | 缺点 |
|------|------|
| 同时拥有预览 + YOLO 帧 | 需在 UI 中添加 TextureView |
| displayer 会将 I420 渲染到真实 Surface | SemiPlanar 路径下二次渲染有额外 CPU 开销 |
| — | 需修复 Planar 格式遗漏 bug |

**需要修复的 bug**：在 `EasyPlayerClient.java` 第 1149-1190 行的 `if` 判断后，
补充 Planar 格式的 `else` 分支，确保 `i420callback` 和 `displayer` 也被调用。

### 方案 C：保留 Path A（直出 Surface）+ 从 Surface 截帧

不改 `I420DataCallback`，而是通过 `ImageReader` 或 `PixelCopy` 从 Surface 上截取帧。

| 优点 | 缺点 |
|------|------|
| 不改动 EasyPlayerClient 任何逻辑 | `ImageReader` 截帧延迟高、API 限制多 |
| 预览零影响 | 帧率不可控，不适合实时检测 |
| — | 格式可能是 RGBA 而非 YUV，多一次转换 |

**不推荐**用于实时 YOLO 检测。

---

## 9. 接入 YOLO 时在 Java 侧需要做的事

### 9.1 最小改动清单（方案 A）

1. **修改 `EasyPlayerClientManger` 构造函数**：传入 `I420DataCallback`。
2. **在回调中拷贝帧数据**：`onI420Data` 中的 `ByteBuffer` 生命周期短（SemiPlanar 路径下为方法栈临时对象，软解路径下随 `releaseBuffer` 回收），必须立即拷贝。
3. **推理线程隔离**：回调在 `VIDEO_CONSUMER` 线程中同步调用，YOLO 推理耗时必须异步，否则会阻塞解码、导致丢帧。
4. **帧宽高获取**：从 `ResultReceiver` 的 `RESULT_VIDEO_SIZE` 事件中获取；默认值参考 `CameraConfig.VIDEO_RESOLUTION_WIDTH` × `VIDEO_RESOLUTION_HEIGHT`（当前 IPC 为 **1920×1080**）。

### 9.2 推理线程参考架构

```
VIDEO_CONSUMER 线程（EasyPlayerClient 内部）
    ↓ onI420Data(buffer)
    ↓ 拷贝 ByteBuffer
    ↓ offer 到无锁队列
    ↓
YOLO_INFERENCE 线程（独立线程）
    ↓ poll 最新帧（丢弃旧帧）
    ↓ I420→BGR (cv::cvtColor)
    ↓ YOLO 推理 (NCNN / TFLite / ONNX Runtime)
    ↓ 输出检测结果
    ↓
UI 线程 / 业务线程
    ↓ 展示检测框 / 触发告警 / 记录数据
```

### 9.3 性能预估（1280×720）

| 环节 | 预估耗时 |
|------|----------|
| I420 ByteBuffer 拷贝 (1.38MB) | < 1ms |
| I420→BGR cvtColor | 3-5ms (ARM NEON) |
| YOLO 推理 (YOLOv8n, NCNN FP16) | 30-80ms (取决于 SoC) |
| 总计单帧 | 35-85ms → 约 12-28 FPS |

对于工业焊缝检测场景，10-15 FPS 通常已足够。

### 9.4 如果未来需要加实时预览

1. 在需要预览的 Activity 布局中添加 `TextureView`。
2. 使用 `EasyPlayerClient(context, textureView, receiver, callback, seiCallback)` 构造函数。
3. 修复 Planar 格式下 `i420callback` 和 `displayer` 未调用的 bug（见第 7.2 节"遗留缺陷"）。
4. 根据需要叠加 YOLO 检测框：在 `TextureView` 上层覆盖一个自定义 `View`（`Canvas.drawRect`）。

---

## 10. 相关源码索引

| 内容 | 路径 |
|------|------|
| 解码主逻辑、两条路径、I420 回调 | `vendor/easydarwin/.../video/EasyPlayerClient.java` |
| I420 回调接口定义 | `EasyPlayerClient.java` 第 478-481 行 |
| 硬解 Surface=null + displayer 二次渲染 | `EasyPlayerClient.java` 第 947-957 行 |
| SemiPlanar→I420 转换 + onI420Data | `EasyPlayerClient.java` 第 1170-1189 行 |
| releaseOutputBuffer render=false | `EasyPlayerClient.java` 第 1202 行 |
| 软解路径 decodeFrameYUV + onI420Data | `EasyPlayerClient.java` 第 1024-1028 行 |
| RTSP 收帧 + 录制分流 (pumpVideoSample) | `EasyPlayerClient.java` 第 1379-1405 行 |
| 颜色格式选择 + isRecognizedFormat | `vendor/easydarwin/.../util/CodecSpecificDataUtil.java` 第 255-281 行 |
| YUV JNI 转换 (mode=4 yuvuv_to_yuv) | `vendor/easydarwin/.../sw/JNIUtil.java` 第 53 行 |
| FFmpeg 软解 JNI (decodeYUV / decodeYUV2) | `vendor/easydarwin/.../video/VideoCodec.java` |
| App 侧播放器封装（虚拟 Surface） | `app/.../common/camera/EasyPlayerClientManger.java` |
| App 侧后台循环录制（虚拟 Surface） | `app/.../sysservice/video/BackgroundLoopRecorder.java` |
| 摄像头 RTSP/HTTP 硬件常量（IP、路径、分辨率、鉴权） | `app/.../common/config/CameraConfig.java` |
| TextureView 构造函数（预览用） | `EasyPlayerClient.java` 第 346-389 行 |
| 已录制视频回放（ExoPlayer, 与 RTSP 无关） | `app/.../video/details/ProcessVideoDetailsActivity.java` |

---

*文档基于仓库内 Java 源码静态分析整理；具体设备上解码器返回的 color format 可能不同，但 `onI420Data` 路径上的设计目标为 I420。Planar 格式遗漏属于 EasyDarwin 开源代码的已知缺陷，接入前建议补丁。*
