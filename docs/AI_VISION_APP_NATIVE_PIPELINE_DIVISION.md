# AI Vision App / Native Pipeline Division

更新时间：2026-05-27

本文档整理 AI Vision 相关链路中 App 端与 native/C++ 端的任务分工，覆盖当前项目中已存在的三类路径：

- 实时 RTSP 推理链路：`RTSP -> I420 -> nativePushFrame`
- 单帧 JPG 推理链路：`Bitmap/JPG -> nativeInferImageToJson`
- 整段视频 native 推理链路：`MP4 -> nativeInferVideoAndSave`

## 1. 实时 RTSP 推理链路

目标：实时从摄像头 RTSP 流拿到解码帧，并推给 native AI 引擎做检测/分类。

### 1.1 App 端任务

1. 管理 RTSP 拉流生命周期
   - 根据业务状态决定是否启动或停止推理流。
   - 负责摄像头网络段准备、RTSP URL 选择、启动失败处理、停止释放。
   - 当前入口主要在 `ProductionInferenceStreamClient`。

2. 使用 EasyPlayerClient 解码 RTSP
   - App 端创建 `EasyPlayerClient`。
   - 使用虚拟 `Surface` 或实际预览 `Surface` 承接解码器输出。
   - 通过 `I420DataCallback` 获取解码后的 I420 帧。

3. 维护视频帧尺寸
   - 接收 `RESULT_VIDEO_SIZE` 回调。
   - 记录当前帧宽高，后续传给 native。
   - 处理设备可能上报 coded height，例如 `1920x1088`，但实际 I420 payload 是 `1920x1080` 的情况。

4. I420 帧采样与限流
   - 根据业务采样间隔决定是否接收当前帧。
   - 避免每个 RTSP 解码帧都推给 AI，防止 native/RKNN 处理不过来。
   - 当前生产推理链路由 `AiFrameSamplingGate` 控制。

5. 拷贝 I420 ByteBuffer
   - `I420DataCallback` 中的 `ByteBuffer` 生命周期很短。
   - App 必须立即拷贝为独立 `byte[]`，避免回调结束后底层 buffer 被复用。

6. 调用 nativePushFrame
   - App 调 `NativeBridge.guardedPushFrame(handle, data, width, height)`。
   - guarded 层负责校验 handle、会话状态、线程锁、异常兜底和日志。

7. 接收 native 回调结果
   - native 通过 listener 或缓存快照返回分类/检测结果。
   - App 负责将结果更新到 UI、HTTP overlay、状态缓存或事件总线。

### 1.2 Native/C++ 端任务

1. 接收 I420 帧
   - JNI 接口：`nativePushFrame(long handle, byte[] data, int width, int height)`。
   - 校验数据长度是否满足 `width * height * 3 / 2`。
   - 识别输入格式为 I420/YUV420P。

2. 帧格式转换
   - 根据模型输入要求将 I420 转为 BGR/RGB 或直接转为模型 tensor 所需格式。
   - 如有必要，处理 stride、crop、ROI、旋转、镜像等图像布局问题。

3. 预处理
   - 执行 resize、letterbox 或中心 ROI crop。
   - 执行归一化、通道重排、量化/反量化相关准备。
   - 准备 RKNN input tensor。

4. RKNN 推理
   - 调用 RKNN runtime，例如 `rknn_inputs_set`、`rknn_run`、`rknn_outputs_get`。
   - 管理 RKNN 上下文、输入输出 buffer、线程安全。

5. 后处理
   - 解析模型输出。
   - 执行 score 计算、阈值过滤、TopK、NMS。
   - 将检测框坐标还原到原始帧坐标系。

6. 状态与回调
   - 更新 native 内部最新检测/分类缓存。
   - 根据业务状态产生 Lens Guard 检测事件。
   - 通过 JNI listener 将结果通知 App。

### 1.3 适用场景

- 摄像头实时推理。
- AI Vision 实时预览检测。
- 生产过程中的低频检测/分类。

### 1.4 性能特点

- 优点：不需要 JPG 落盘，不需要 native 再读取和解码图片文件。
- 主要开销：RTSP 解码、I420 拷贝、I420 到模型输入格式转换、RKNN 推理和后处理。
- 当前仍有一次 Java `byte[]` 拷贝，后续可优化为 `DirectByteBuffer` 或 native buffer。

## 2. 单帧 JPG 推理链路

目标：App 将某一帧保存为 JPG 文件，然后通过文件路径调用 native，native 返回 JSON 推理结果。

### 2.1 App 端任务

1. 决定采样时间点
   - 根据视频时长和采样间隔生成采样点。
   - 当前录像 AI Vision 处理视频时使用固定采样间隔。

2. 从视频抽帧
   - 使用 `MediaMetadataRetriever` 打开本地 MP4。
   - 调用 `getFrameAtTime()` 按时间点抽取 `Bitmap`。
   - 该阶段由 Android framework 完成视频 seek 和解码。

3. Bitmap 转 JPG
   - 将抽出的 `Bitmap` 压缩成 JPG。
   - 写入 App cache 目录，例如 `ai-vision-video-inference/frames/<cacheKey>/frame_*.jpg`。
   - 当前 JPG quality 通常为 90。

4. 调用 inferJpgToJson
   - App 调 `LensGuardManager.inferJpgToJson(imagePath)`。
   - 校验 AI 引擎是否运行、文件路径是否有效、文件类型是否支持。

5. 进入 guarded native 调用
   - App 调 `NativeBridge.guardedInferImageToJson(handle, imagePath)`。
   - guarded 层负责串行化到 RKNN 线程、校验 session 状态、加锁、捕获异常。
   - `RKNN_THREAD_TRACE` 中的 `nativeInferImageToJson elapsedUs` 从这里开始计时，到 native 返回结束。

6. 解析 native JSON
   - App 将 native 返回的 JSON 转成 timeline frame。
   - 补充时间戳、原图宽高、检测框列表、污点等级等字段。

7. 生成时间轴
   - 将每个采样点推理结果加入 timeline。
   - 后续用于视频播放时按时间匹配检测框，或用于导出带框视频。

### 2.2 Native/C++ 端任务

1. 接收 JPG 文件路径
   - JNI 接口：`nativeInferImageToJson(long handle, String imagePath)`。
   - 校验 handle、路径、文件是否可读。

2. 读取 JPG 文件
   - 根据传入路径打开文件。
   - 从文件系统读取 JPG 字节。

3. 解码 JPG
   - 将 JPG 解码为像素数据。
   - 该阶段通常是 CPU 开销，且会产生额外内存分配。

4. 图像预处理
   - 执行颜色格式转换。
   - 执行 crop/resize/letterbox。
   - 准备模型 input tensor。

5. RKNN 推理
   - 调用 RKNN runtime 完成模型推理。
   - 该阶段通常只是 `nativeInferImageToJson` 总耗时的一部分。

6. 后处理
   - 对模型输出执行 score 计算、阈值过滤、NMS。
   - 还原坐标到输入 JPG 的完整图像坐标系。

7. 组装 JSON
   - 生成包含 `code`、`level`、`boxes`、`message` 等字段的 JSON 字符串。
   - 将 JSON 通过 JNI 返回给 App。

### 2.3 适用场景

- 离线视频抽帧生成检测时间轴。
- 调试单张图片推理结果。
- native 不支持整段视频推理时的 fallback 路径。

### 2.4 性能特点

- 优点：接口简单，App 只需要传文件路径，结果可直接持久化排查。
- 缺点：链路较长，存在重复编解码和文件 I/O。
- 额外开销包括：App 端 Bitmap 转 JPG、写文件、native 端读文件、native 端 JPG 解码。
- 当前日志中 `nativeInferImageToJson` 单帧约 `420-450ms`，该耗时不包含 App 端抽帧和 JPG 写入，只包含 native 调用内部以及 JNI 返回前后的封装时间。

## 3. 整段视频 Native 推理链路

目标：App 直接把本地视频路径传给 native，由 native 完成视频解码、推理、画框和输出视频保存。

### 3.1 App 端任务

1. 检查 native 能力
   - 判断当前加载的 `libai.so` 是否导出 `nativeInferVideoAndSave`。
   - 如果未导出，则 fallback 到单帧 JPG 推理链路。

2. 准备输入输出路径
   - 输入路径为本地 MP4。
   - 输出路径为 App 私有目录下的临时 MP4。
   - 先清理旧的临时文件，避免结果混淆。

3. 调用 inferVideoAndSave
   - App 调 `LensGuardManager.inferVideoAndSave(inputVideoPath, outputVideoPath)`。
   - 进入 `NativeBridge.guardedInferVideoAndSave(...)`。
   - guarded 层负责 session 状态校验、串行化到 RKNN 线程、加锁和日志。

4. 等待 native 返回
   - native 调用是同步返回。
   - App 根据返回码判断成功或失败。

5. 校验输出文件
   - 检查输出 MP4 是否存在、是否非空。
   - 成功后将临时文件切换为正式输出。

6. 失败 fallback
   - 如果 native 返回失败，App fallback 到单帧 JPG 时间轴加 App 侧 overlay 导出。
   - App 负责记录 fallback 日志，避免静默失败。

### 3.2 Native/C++ 端任务

1. 接收视频输入输出路径
   - JNI 接口：`nativeInferVideoAndSave(long handle, String inputVideoPath, String outputVideoPath)`。
   - 校验路径合法性和文件可读写状态。

2. 打开视频
   - native 自己打开输入 MP4。
   - 读取视频封装信息、编码信息、分辨率、时长、帧率。

3. 视频解码
   - native 负责逐帧解码。
   - 可使用硬解或 FFmpeg/软件解码，具体取决于 native 实现。

4. 帧采样或逐帧处理
   - 根据业务策略决定每帧都推理，还是按固定间隔采样。
   - 保持采样时间戳与输出视频时间线一致。

5. 图像预处理与 RKNN 推理
   - 对解码帧执行颜色转换、crop/resize、tensor 准备。
   - 调用 RKNN runtime 执行推理。

6. 后处理和画框
   - 执行检测后处理。
   - 将框坐标映射到输出视频坐标系。
   - 在视频帧上绘制检测框、标签或状态文案。

7. 视频编码与封装
   - 将带框帧重新编码。
   - 写入输出 MP4。

8. 返回状态码
   - 成功返回 `0`。
   - 失败返回负数或约定错误码，App 根据错误码 fallback 或提示。

### 3.3 适用场景

- 录像离线推理并导出带框 MP4。
- 希望 native 统一管理视频解码、推理、绘制和编码。

### 3.4 性能特点

- 优点：避免 App 抽帧、JPG 压缩、JPG 落盘、native 读 JPG 和 JPG 解码。
- 优点：native 可以复用解码帧 buffer、模型 tensor buffer、编码 buffer。
- 缺点：如果 App 还需要详细 timeline JSON，当前接口只返回视频文件状态，不天然返回每个采样点的 JSON。
- 建议扩展方向：`nativeInferVideoAndSaveWithTimeline` 或 `nativeInferVideoToTimelineJson`。

## 4. 推荐优化分工

### 4.1 短期优化

App 端：

1. 降低单帧 JPG fallback 频率
   - 当前单帧 native 调用耗时大于 200ms 采样间隔时，应避免任务堆积。
   - 可将录像推理采样间隔调整到 500ms，或采用“上一帧未结束则丢弃当前帧”策略。

2. 复用视频解码对象
   - 避免每个 sample 都重新创建 `MediaMetadataRetriever`。
   - 在同一个视频任务内复用 retriever，降低 setDataSource 和初始化开销。

3. 控制队列长度
   - 推理队列只保留最新 1-2 帧。
   - 防止离线或实时链路越积越慢。

Native 端：

1. 增加细粒度耗时日志
   - 拆分记录 `read file`、`jpeg decode`、`preprocess`、`rknn_run`、`postprocess`、`json build`。
   - 明确 `420-450ms` 中到底哪一段占比最高。

2. 复用内存 buffer
   - 避免每帧重复分配大块图像 buffer、tensor buffer 和 JSON buffer。

### 4.2 中期优化

App 端：

1. 将录像抽帧从 `MediaMetadataRetriever` 改成顺序 `MediaCodec` 解码。
   - 一次打开视频，按时间戳顺序取帧。
   - 避免每个采样点 seek。

2. 将解码帧以 I420/NV12 形式传给 native。
   - 避免 Bitmap 和 JPG 中转。
   - 对齐实时 RTSP 的 I420 推理链路。

Native 端：

1. 新增 `nativeInferYuvToJson` 或 `nativeInferRgbaToJson`
   - 入参为 ByteBuffer/byte[]、width、height、format、timestamp。
   - native 直接从解码帧做预处理和推理。

2. 优化颜色转换和 resize
   - 优先使用 libyuv、RGA 或 NEON 优化路径。
   - 避免 OpenCV 全图多次拷贝。

### 4.3 长期优化

App 端：

1. 只负责业务调度、UI、上传和状态管理。
2. 不再参与重度视频解码、JPG 编码、画框视频导出。

Native 端：

1. 接管完整 RTSP 或 MP4 处理链路。
2. 提供更完整接口，例如：
   - `nativeStartRtsp(handle, url)`
   - `nativeStopRtsp(handle)`
   - `nativeInferVideoAndSaveWithTimeline(handle, input, output)`
   - `nativeInferYuvToJson(handle, buffer, width, height, format, timestampMs)`
3. native 内部统一完成：
   - 拉流/解码
   - 采样
   - 预处理
   - RKNN 推理
   - 后处理
   - timeline JSON 输出
   - 带框视频编码

## 5. 总结

当前最推荐的任务边界是：

```text
App：业务调度、视频/RTSP 生命周期、帧采样、UI/HTTP/上传、结果解析
Native：图像预处理、RKNN 推理、后处理、检测结果生成
```

如果要进一步提升性能，应逐步减少 App 与 native 之间的文件路径交互：

```text
低效：App 写 JPG -> Native 读 JPG -> Native 解码 JPG
较好：App 解码 I420 -> Native 直接推理
最好：Native 直接管理视频/RTSP 解码和推理
```
