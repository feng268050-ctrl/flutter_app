# 排查笔记：网络摄像头 / AI Vision 延迟偏大（代码栈侧）

本节基于仓库当前实现推断**可能成因**，不涉及现场 RTP 抓包。现场请按 §4 逐项排除。

## 1. 协议与传输层（IPC → 平板）

| 因子 | 说明 |
|------|------|
| **RTSP over TCP** | `AiVisionFragment` 使用 `Client.TRANSTYPE_TCP`，带宽紧张时不会像 UDP 丢包瞬时花屏那样明显，但可能增加排队与 jitter 缓冲体感延迟。 |
| **Native EasyRTSP 缓冲** | `Client.openStream` 在 JNI/库内部还有接收缓冲区，Java 侧无直接旋钮；需在厂商层或 JNI 映射中查文档。 |

## 2. Java 层帧队列（易堆积 → 端到端变慢）

来源：`EasyPlayerClient.FrameInfoQueue`（`EasyPlayerClient.java`）

- **最大容量 CAPACITY = 500** — 解码线程赶不上拉流时可堆积大量未解码帧，`mNewestStample - stamp`（cache）拉大后，Soft 解码路径上会配合 `fixSleepTime` 去做时间戳调速，表现为「追着最新画面跑」但更晚才显示当下。
- 消费者线程：`takeVideoFrame(5)` 短阻塞轮询队列。

**结论：** 若在弱网或多任务 CPU 满载下，积压深度是延迟的重要来源。

## 3. 解码路径差异（关键因素）

同样在 `VIDEO_CONSUMER` 线程：

- **`KEY_VIDEO_DECODE_TYPE = 1`（Hardware MediaCodec 成功初始化）**：输出释放路径里 `Thread.sleep` 已注释掉，主要靠 MediaCodec → Texture 链路，Java 侧**主动按 PTS sleep 较少**。
- **`KEY_VIDEO_DECODE_TYPE = 0`（fallback `VideoDecoderLite` 软路径）**：存在基于 PTS 差的 `fixSleepTime` + **`Thread.sleep(sleepTime/1000)`**（毫秒级），有明显**人为步调延迟**。若 RK3566 上硬解初始化失败或未支持分辨率，会一直走这一路。

附加：`preference "use-sw-codec" = true` 可强制抛错走软件路径。

**App 已实现**：AI Vision 首帧 `RESULT_VIDEO_DISPLAYED` 时打日志 `VIDEO_DISPLAYED decodeType=…`，便于现场确认是 **0** 还是 **1**。

## 4. 首帧与密钥帧

`EasyPlayerClient.start()` 读取 `waiting_i_frame`（AI Vision `onResume` 里已通过 `overrideLowLatencyPrefs(false→true)` 临时改为 **false**，离开页面恢复）。

- `mWaitingKeyFrame == true` 时会丢弃直到 **I 帧**，GOP 大则首帧时间明显变长。（当前 AI Vision 已尝试规避。）

## 5. AI 与同路拷贝

带 `i420callback` 时：`configure(..., surface=null)`，`MediaCodec` 输出再走 `VideoDecoderLite` 画到 Surface，并在每帧上做 **allocateDirect + put**（`LensGuardManager.onI420Frame` 还有一次全数组拷贝）。

**结论：** LensGuard（YOLO/RKNN 输入）全开时 CPU/内存带宽争用会加重 **§2 队列堆积**，体感延迟变大；二分验证：关引擎或关 `ENABLE_LENS_GUARD_STARTUP` 对照。

## 6. 网络与 IP（非播放器）

- 交换机/千兆/线缆、是否与 IPC **同网段**（见 `CameraConfig`、`setCameraNetworkSegment`）。
- 摄像头 **码率/GOP/WDR**：高码率、长 GOP、多 slice 都会影响首帧和解码积压。

---

## 7. 建议的下一步（已与 `tasks.md` §0–§3 对齐）

1. Logcat：看到 `VIDEO_DISPLAYED decodeType=**` → 若为 **0**，优先查明硬解为何失败或未选用。
2. 同 URL 下 **VLC 与 AI Vision** 对比：两处都慢 → IPC/网线/码流；仅 App 慢 → §2§3§5。
3. 条件允许：短时 **降低 IPC 分辨率/帧率/GOP**，观察队列积压是否缓解（无需改 APK 即可试）。
