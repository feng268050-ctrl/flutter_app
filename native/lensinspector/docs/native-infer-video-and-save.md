# nativeInferVideoAndSave — 设备录像带框输出

对设备上已保存的录像做污点检测，并写出**带推理框**的可播放视频文件。

**App 消费**：lws-ui `LensGuardManager.inferVideoAndSave` → `AiVisionFragment` 离线优先路径。
**完善说明**：lws-ui [`docs/NATIVE_INFER_VIDEO_AND_SAVE_IMPROVEMENT.md`](https://github.com/lasercyber/lws-ui/blob/dev/docs/NATIVE_INFER_VIDEO_AND_SAVE_IMPROVEMENT.md)

## 引擎交付清单

| 文件 | 内容 |
|------|------|
| `src/jni_bridge.cpp` | `nativeInferVideoAndSave` → `inferVideoAndSave` |
| `src/main.cpp` | 解码 → **500ms 间隔 infer** + 全帧写出 → 多 fourcc 回退 |
| `CMakeLists.txt` | `videoio` + JNI `--undefined=nativeInferVideoAndSave` |

```bash
bash scripts/verify_libai_jni.sh build_android/libai.so
nm -D libai.so | grep nativeInferVideoAndSave
```

## JNI

```java
int nativeInferVideoAndSave(long handle, String inputVideoPath, String outputVideoPath);
```

## 行为（与 lws-ui 对齐）

| 项 | 说明 |
|----|------|
| 检测 | 与实时相同：`infer_stain`（ROI 700×700@(565,110)→640，全图 xyxy，`stain_score_mode: logits`） |
| **推理节奏** | 每 **0.5s** 抽帧做一次 RKNN（与 App 离线时间轴约 500ms 一致；时间轴本身宜用 `nativeInferRgb`）；**每一源帧都写出** |
| 框保持 | 两次推理之间沿用上一组框绘制（全帧率播放流畅） |
| 框上限 | `algorithm.stain_max_det`（默认 100） |
| 标签 | `cont:0.87`（`cls_id==0`） |
| 回调 | **不**发 `onCheckResult` / 窗口 level |
| 取消 | `nativeStop` 后 `running=false`，循环内中止并删除半截输出 |

## 输出编码

Android 设备优先用 `MediaCodec` + `MediaMuxer` 写标准 H.264 MP4。失败后仅尝试 OpenCV H.264 MP4 writer；不会再把 AVI/MJPG 侧车文件 rename 成 `.mp4`。App 可能已 `touch` 0 字节 `.mp4.tmp`，写入前会 **删除** 再打开。

| 顺序 | fourcc | 说明 |
|------|--------|------|
| 1 | `MediaCodec-avc` | Android H.264 MP4（ExoPlayer 首选） |
| 2 | `avc1` | OpenCV H.264 MP4 |
| 3 | `H264` | 部分 OpenCV 构建 |

成功返回 **0** 前校验输出文件 **`size > 0`**。失败 **-3/-4/-5** 会删除半截输出。`XVID`/`MJPG` 不再作为成功输出，避免生成扩展名是 `.mp4`、实际容器/编码却不是 MP4/H.264 的文件。

## 帧率与尺寸

- `CAP_PROP_FPS` 无效时用 **25fps**（日志注明 `frame_count` 若可读）。
- 宽高：首帧 `cols/rows` 兜底；解码尺寸变化时 **resize** 到 writer 尺寸。

## 返回值

| code | 含义 |
|------|------|
| 0 | 成功（`out_bytes > 0`） |
| -1 | handle 无效或路径为空 |
| -2 | 无法打开输入或帧尺寸无效 |
| -3 | 推理异常或 `nativeStop` 取消 |
| -4 | 无法创建输出（已尝试全部 fourcc） |
| -5 | 输入无有效帧 |

## 与离线 JSON 的区别

| API | 输出 | 用途 |
|-----|------|------|
| `nativeInfer*` / `*ToJson` | 每帧 JSON + `level` | 时间轴、上传 |
| `nativeInferVideoAndSave` | 带框 MP4 | 预览/分享；native 失败时 App fallback 全帧 MediaCodec 合成 |

## 板端验收

```text
[OFFLINE] nativeInferVideoAndSave infer interval=500ms infer_every=13 fps=25.00 frames_hint=425
[OFFLINE] nativeInferVideoAndSave done frames=425 infer=85 total_boxes=... fps=25.00 size=1920x1080 fourcc=MediaCodec-avc out_bytes=...
```

- 输出可播放，帧率≈源片（非 2fps 幻灯片）。
- logcat 无 `refusing MJPG/XVID fake MP4` / App 无 `fallback`（极端片源除外）。

## Mac 调试（ONNX）

```bash
python check/infer.py det --model det_raw_head.onnx \
  --source video.mp4 --save-video runs/out_det.mp4 \
  --conf 0.25 --raw-channel-order box_first
```

板端用 JNI 或 `tools/rknn_infer`。
