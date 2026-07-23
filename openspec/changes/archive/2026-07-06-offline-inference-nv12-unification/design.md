## Context

Live 检测已在 `StreamDetectPipeline` 内完成 RTSP 硬解，输出 **NV12**，经 `stream_detect/yuv_convert.h` 的 `nv12ToBgr` 进入 OpenCV stain / zero_point / edgedrawing。离线路径仍走：

```
MediaMetadataRetriever.getFrameAtTime → Bitmap (ARGB)
  → I420FrameUtil.fromBitmap → ByteBuffer I420
  → nativeOpencv*FromI420 → cv::COLOR_YUV2BGR_I420 → analyzeBgr / detect
```

主要调用点：

| 场景 | Java 入口 | Native JNI |
|------|-----------|------------|
| 工艺视频 Detect | `ProcessVideoAiSession.runInferSample` | `nativeOpencvStainDetectFromI420` |
| 手动零点离线帧 | `ZeroPointManualAutoCoordinator` | `nativeOpencvZeroPointDetectFromI420` |
| 零点 session 封装 | `ZeroPointDetectNativeSession.detect` | 同上 |

Live 路径已无 Java I420 喂检测（`native-stream-detect-pipeline` Phase 4 完成）。

## Goals / Non-Goals

**Goals:**

- 离线 OpenCV one-shot 推理与 live 使用同一 **NV12 布局** 与 **nv12ToBgr** 色彩路径
- Java 侧提供稳定的 NV12 direct buffer 生产与尺寸校验（与 `I420FrameUtil.preparePayload` 对称）
- 新增 `nativeOpencv*FromNv12` JNI，更新规格与文档；离线回归（200 ms process video 网格）行为与数值结果与 I420 基线一致（同一 bitmap 源）
- `verify_libai_jni.sh` 与 CMake undefined-symbol 列表包含新符号

**Non-Goals:**

- RKNN `nativeRknnStainDetectFromI420`、`LensGuardManager.inferFromI420`（单独 change，避免 RKNN 与 OpenCV 色彩栈耦合）
- 将 `MediaMetadataRetriever` 改为 native 解码或 ExoPlayer 出 YUV（仍 bitmap 采样，只改 Java→native 契约）
- 删除 `*FromI420` JNI（本 change 仅 deprecated；删除留后续 cleanup）
- Live `StreamDetectPipeline` 改造（已完成）

## Decisions

### 1. 新增 `FromNv12` JNI，而非改签名

**选择:** 新增 `nativeOpencvStainDetectFromNv12` 等，保留 `FromI420` 并标记 `@Deprecated`。

**理由:** 避免 silent breaking JNI；仪器测试与旧 libai 仍可加载；迁移可逐模块切换。

**替代:** 仅改 I420 内部实现为 I420→NV12→BGR — 仍保留错误布局假设，未达成「统一 NV12」目标。

### 2. 复用 `stream_detect::nv12ToBgr`

**选择:** 将 `yuv_convert.h/.cpp` 提取或链接到共享编译单元，供 opencv_stain / zero_point / edgedrawing JNI 调用。

**理由:** 与 live 管线同一 libyuv/OpenCV 路径，避免 `COLOR_YUV2BGR_I420` 与 NV12 双实现漂移。

**替代:** JNI 内继续 `cv::COLOR_YUV2BGR_I420` 仅用于 deprecated shim。

### 3. Java `Nv12FrameUtil.fromBitmap`

**选择:** ARGB bitmap → NV12（Y + interleaved UV，`capacity = width * height * 3 / 2`），提供 `preparePayload(buffer, width, height)` 与 `toDirectBuffer()`，API 镜像 `I420FrameUtil`。

**实现:** 优先 **libyuv** `ARGBToNV12`（若 app/jni 已有）；否则 Java 侧 YUV420 转换（与现有 I420 工具同文件结构）。单元测试固定小尺寸 golden buffer。

**替代:** bitmap → I420 → native `i420ToNv12` — 多一次拷贝，不推荐。

### 4. `AiManager` 层命名

**选择:** 新增 `opencvStainDetectFromNv12`；`opencvStainDetectFromI420` 保留并委托 NV12（内部 `I420→NV12` 一次转换）或直调旧 native（过渡期），最终文档推荐 NV12。

**零点:** `ZeroPointDetectNativeSession.detectFromNv12` 或 overload `detect(..., Nv12Payload)`。

### 5. I420 兼容 shim 策略

**选择:** `FromI420` native 实现改为：`I420 → NV12 buffer（i420ToNv12）→ nv12ToBgr → detect`，使 deprecated 路径与 NV12 数值一致。

**理由:** 单一 BGR 入口，减少 `COLOR_YUV2BGR_I420` 分叉。

## Risks / Trade-offs

- **[Risk] Bitmap→NV12 与 Bitmap→I420 舍入差异导致 detect 结果微变** → 用 `DumpRetrieverFrameInstrumentedTest` 与固定 fixture 对比 boxes/code；允许亚像素级差异，不允许告警逻辑翻转
- **[Risk] NV12 buffer 尺寸/stride 错误导致 native 崩溃** → `Nv12FrameUtil.preparePayload` 严格校验 capacity；native 入口 assert width/height 偶数
- **[Risk] 双 JNI 符号增加 libai 体积** → 可接受；shim 共享实现无重复 detect 逻辑
- **[Trade-off] RKNN 离线仍 I420** → 文档明确 split，避免误以为全栈 NV12

## Migration Plan

1. **Phase A — Native:** 提取/共享 `nv12ToBgr`；实现三个 `FromNv12` JNI；`FromI420` 改 shim；更新 `verify_libai_jni.sh`
2. **Phase B — Java util:** `Nv12FrameUtil` + 单元测试
3. **Phase C — Call sites:** `ProcessVideoAiSession` → `FromNv12`；`ZeroPointDetectNativeSession` + manual auto 离线阶段
4. **Phase D — API/docs/spec:** deprecate I420 public methods；更新 integration doc 与 offline regression note
5. **Rollback:** 保留 `FromI420` 与 feature-free 回退 — 调用点 revert 至 I420 Java 路径即可

## Open Questions

- `Nv12FrameUtil` 是否放在 `app/.../ai/` 与 `I420FrameUtil` 同包，或抽到 `ui/common/ai/video/`（process video 专用）— 建议 **ai 包** 与 I420 并列
- 是否在 Phase D 同步改 `lens-guard-offline-infer-json`（RKNN）— **本 change 不改**，仅 proposal 引用为 follow-up
