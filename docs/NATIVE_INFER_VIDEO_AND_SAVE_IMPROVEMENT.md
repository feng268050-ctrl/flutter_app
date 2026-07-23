# nativeInferVideoAndSave 完善指南（YOLO / lensinspector）

**文档日期**：2026-05-26  
**面向**：lensinspector / YOLO 引擎侧  
**App 消费方**：lws-ui `AiVisionFragment` → `LensGuardManager.inferVideoAndSave`  
**引擎权威**：[`lensinspector/docs/native-infer-video-and-save.md`](../../lensinspector/docs/native-infer-video-and-save.md)

---

## 1. 背景

AI Vision 离线流程优先调用 **`nativeInferVideoAndSave`** 一次生成带框 MP4；失败时 App fallback 为：

1. 每 **500ms** `nativeInferImageToJson` 建时间轴  
2. App 侧 **全帧率** `MediaCodec` 合成（见 [`AiVisionFragment.renderInferenceVideo`](../app/src/main/java/com/lasercyber/lws/ui/activitys/device/monitor/fragment/AiVisionFragment.java)）

真机（RK3566）常见失败：

| code | 日志/现象 | App 行为 |
|------|-----------|----------|
| **-4** | `cannot create output: ...mp4.tmp` | fallback 逐帧 + App 全帧合成 |
| **-2** | 输入打不开 / 尺寸 0×0 | fallback（引擎已部分兜底首帧尺寸） |
| **-3** | 推理异常 | Toast + fallback |

本文说明 **native 侧应如何完善**，使 App 优先走 native 整段导出（更快、与引擎后处理一致）。

---

## 2. 当前实现（基线）

**源码**：`lensinspector/src/main.cpp` → `CentralScheduler::inferVideoAndSave`  
**JNI**：`lensinspector/src/jni_bridge.cpp` → `nativeInferVideoAndSave`

```text
VideoCapture 打开输入
  → 读首帧，CAP_PROP 无效则用 frame.cols/rows
  → VideoWriter(fourcc=mp4v) 打开输出
  → 循环：每帧 infer_stain → 画框 → writer.write
```

**返回值**（与引擎文档一致）：

| code | 含义 |
|------|------|
| 0 | 成功 |
| -1 | handle 无效或路径为空 |
| -2 | 无法打开输入或帧尺寸无效 |
| -3 | 推理过程异常 |
| -4 | **无法创建输出文件** |
| -5 | 输入无有效帧 |

**与 App 契约**：

- 与实时/单图相同：`infer_stain`（ROI 700×700@(565,110) → 640，全图 xyxy）  
- **不**按帧 `onCheckResult`、不写 JSON 时间轴  
- 输出：可播放的 MP4，分辨率/帧率宜与输入一致  

---

## 3. P0：修复 code=-4（输出 MP4 创建失败）

### 3.1 现象与根因

设备 logcat 典型行：

```text
[OFFLINE] nativeInferVideoAndSave cannot create output: /data/user/0/.../ai-vision-inference-....mp4.tmp
```

常见根因：**Android / RK3566 上 OpenCV `VideoWriter` + `mp4v` 不可用**（构建未带可用 MPEG-4 软编），而非 App 未建目录（App 已 `mkdirs` 并 touch `.tmp`）。

### 3.2 建议改法（按优先级）

#### A. 多 fourcc / 容器回退

`writer.isOpened()` 失败时依次尝试，并打日志记录成功的 fourcc：

| 顺序 | fourcc | 容器 | 说明 |
|------|--------|------|------|
| 1 | `avc1` | `.mp4` | H.264，ExoPlayer 友好（首选） |
| 2 | `H264` | `.mp4` | 部分 OpenCV 构建 |
| 3 | `mp4v` | `.mp4` | 当前默认，板端常失败 |
| 4 | `XVID` | `.avi` | 兜底 |
| 5 | `MJPG` | `.avi` | 兜底 |

若扩展名与 App 传入的 `.mp4.tmp` 不一致，应：

- 先写到实际可写路径，成功后再 **`rename` 到 App 期望的 `.tmp` 路径**，或  
- JNI 返回实际路径（需改 App 契约，一般不推荐）

#### B. Android 专用：MediaCodec + MediaMuxer

OpenCV `videoio` 在 RK 包上常**仅能解码**。长期方案：

```text
#ifdef __ANDROID__
  cv::Mat (BGR) → RGB/YUV420 → AMediaCodec (video/avc) → MediaMuxer → .mp4
#endif
```

与 App `renderInferenceVideo` 同思路，但帧来自 native 画框后的 `cv::Mat`。

#### C. 路径与文件

- `fscompat::makedirs(parent)` 检查返回值，失败打 `errno`  
- App 已 touch 的 **0 字节 `.tmp`**：写入前 **`remove()`** 再 `writer.open()`  
- 失败时日志附带：`fps`、`width×height`、尝试过的 fourcc  

### 3.3 验收

```bash
nm -D libai.so | grep nativeInferVideoAndSave
# 板端触发离线推理后 logcat：
# [OFFLINE] nativeInferVideoAndSave done frames=425 total_boxes=... fps=25.00 size=1920x1080
```

输出文件 `size > 0`，ExoPlayer / 系统播放器可流畅播放（帧率≈源片，非 2fps）。

---

## 4. P1：与 App 对齐——全帧写出 + 每 500ms 推理

### 4.1 App 策略（lws-ui 已实现）

| 阶段 | 行为 |
|------|------|
| **推理** | 每 **500ms** 抽一帧 → `nativeInferImageToJson`，约 35 个关键时间点 |
| **合成** | 源片 **exportFps**（如 25fps）**全帧**编码；框用 `findLastFrameWithDetectionAt(timeMs)` hold-forward（后续无框样本保留最近一次有框结果）；Status HUD 用 `findFrameAt(timeMs)` |

### 4.2 Native 建议（与 App 一致）

当前 native **每帧 `infer_stain`**（17s@25fps ≈ 425 次 RKNN），正确但慢，且与 App fallback 策略不一致。

建议在 `inferVideoAndSave` 内：

```cpp
constexpr double kInferIntervalSec = 0.5;
const int infer_every = std::max(1, (int)std::lround(fps * kInferIntervalSec));

std::vector<Detection> held;
// 首帧已在循环外 read；注意与现有 while 结构对齐，避免漏帧/双读
while (true) {
    if (frame_idx % infer_every == 0) {
        held = models_.infer_stain(frame);
        cap_detections(held, cfg_.algorithm.stain_max_det);
    }
    draw_detections_on_bgr(frame, held);
    writer.write(frame);
    ++frame_idx;
    if (!cap.read(frame) || frame.empty()) break;
}
```

| 模式 | RKNN 次数（17s@25fps） | 播放 | 框更新 |
|------|------------------------|------|--------|
| 每帧 infer（现况） | ~425 | 流畅 | 每帧 |
| **500ms infer + 全帧写出（推荐）** | **~35** | 流畅 | 每 0.5s |

### 4.3 帧率与尺寸

- `CAP_PROP_FPS` 无效或异常：默认 **25**，可用 `FRAME_COUNT / DURATION` 推算  
- 宽高：**首帧 `cols/rows` 兜底**（已实现）；若解码尺寸变化，需统一 `resize` 或按每帧 `frame.size()` 更新 writer  

---

## 5. P2：检测 / 绘制与 JSON API 一致

| 项 | 要求 |
|----|------|
| 几何 | 仅走 `infer_stain`，禁止 duplicate 后处理 |
| `stain_max_det` | `cap_detections`，与 `config.yaml` 一致 |
| `stain_score_mode` | 产线 **`logits`**（`det_raw_head`） |
| 标签 | 可选：`cls_id==0` 显示 `cont:0.87`，与 App `cls=cont` 对齐 |
| 回调 | **不**发 `onCheckResult` / 窗口 level（见引擎文档 §9.5） |

---

## 6. P3：健壮性与可观测性

| 项 | 建议 |
|----|------|
| 进度日志 | 保留每 50 帧；可增加 `frame_idx / total_frames` |
| 失败清理 | `-3/-4/-5` 时删除半截输出文件 |
| 成功校验 | `return 0` 前确认输出 `file size > 0` |
| 线程 | 仅在 **RKNN 工作线程** 调用（与 `guardedInferVideoAndSave` 一致） |
| 取消 | 可选：`nativeStop` 或专用标志位，循环内检查（App 有 `generation` 取消） |

---

## 7. 实施顺序

```mermaid
flowchart LR
  A["P0 修 VideoWriter<br/>avc1 / MediaCodec"] --> B["P1 500ms 推理<br/>全帧写出"]
  B --> C["P2 标签 / fps / 配置对齐"]
  C --> D["板端 1080p 验收"]
```

1. **先消除 -4**（否则 App 永远 fallback）  
2. **再加 500ms 推理间隔**（性能与 App 一致）  
3. **最后** MediaCodec 硬编（若 OpenCV 仍不稳定）  

---

## 8. 板端验收（App + 新 libai zip）

1. 将新包推到设备并解压为 `files/bundled-libraries/ai-library/<version>/`（示例：`libai_v1.2.8.zip` → `1.2.8/`），同步 `config.yaml` 到 `files/lens_guard/`，**冷启动 App**（或 `force-stop` 后重开）以加载新 `libai.so`。  
2. 在 **AI Vision** 选一段工艺录像，触发 **离线推理 / 重新推理**，等待合成 MP4 完成并自动播放。  
3. **通过**：logcat 出现  
   `nativeInferVideoAndSave done frames=... fps=...`  
   且播放流畅（源帧率，非 2fps 幻灯片）；App **无** `fallback to per-frame inferJpgToJson`。  
4. **若仍 code=-4**：抓取整段 logcat（含 `[OFFLINE] VideoWriter failed fourcc=...` 或 `cannot create output`），再评估是否上 **MediaCodec** 写 H.264 路径。

```bash
adb -s <device> push /path/to/libai_v1.2.8.zip /data/local/tmp/
adb -s <device> shell am force-stop com.lasercyber.lws.ui
# su 解压到 files/bundled-libraries/ai-library/1.2.8/ 并 cp config → lens_guard（见 YOLO 交付清单）
adb -s <device> logcat -c
# 在 App 内触发离线导出后：
adb -s <device> logcat -d | grep -E '\[OFFLINE\]|AiVisionFragment|nativeInferVideo'
```

---

## 9. 交付清单

- [ ] `src/main.cpp`：`inferVideoAndSave` 按上文修改  
- [ ] `CMakeLists.txt`：`videoio` + JNI `--undefined=nativeInferVideoAndSave`  
- [ ] `scripts/verify_libai_zip.sh` / `nm -D` 通过  
- [ ] 更新 `lensinspector/docs/native-infer-video-and-save.md`（fourcc 回退、500ms 策略、-4 排查）  
- [ ] 板端：17s、1920×1080、H.264 MP4、logcat `done frames=... fps=25`  
- [ ] App：不再出现 `nativeInferVideoAndSave failed; fallback`（或仅极端片源）  

---

## 10. App 与 Native 分工

| 能力 | 负责方 |
|------|--------|
| 带框 MP4、源 fps、H.264 可播 | **native `inferVideoAndSave`**（完善后优先） |
| 上传 JSON 时间轴、`level`、cacheKey | **`nativeInferImageToJson`** |
| native 仍失败时 | App **全帧 MediaCodec 合成**（已实现） |

---

## 11. 相关文档

| 文档 | 说明 |
|------|------|
| [`docs/YOLO_APP_DELIVERY_CHECKLIST.md`](YOLO_APP_DELIVERY_CHECKLIST.md) | YOLO zip / JNI 交付 |
| [`docs/AI_VISION_INFERENCE_TROUBLESHOOTING_ARCHIVE.md`](AI_VISION_INFERENCE_TROUBLESHOOTING_ARCHIVE.md) | 真机 code=-2/-4 归档 |
| [`AI_VISION_LIBAI_JNI_ALIGNMENT.md`](../AI_VISION_LIBAI_JNI_ALIGNMENT.md) | 离线 JNI 验收 |
| [`lensinspector/docs/native-infer-video-and-save.md`](../../lensinspector/docs/native-infer-video-and-save.md) | 引擎 API 权威 |
| [`lensinspector/docs/LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`](../../lensinspector/docs/LENS_GUARD_APP_ALIGNMENT_2026-05-19.md) | ROI / mask 对齐 |
