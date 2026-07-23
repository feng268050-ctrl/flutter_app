## Why

`native-stream-detect-pipeline` 已将 live RTSP 检测统一为 C++ 硬解 **NV12 → BGR** 入口；离线工艺视频、手动零点离线阶段等路径仍经 Java `MediaMetadataRetriever` → bitmap → **I420** → `nativeOpencv*FromI420`，与 live 管线色彩契约不一致，且 I420 平面布局与 NdkMediaCodec 输出不同，增加 Java 侧转换与 JNI 文档/测试分叉。本 change 将**离线 OpenCV 推理**与 live 对齐为 NV12 契约，复用 `stream_detect/yuv_convert` 色彩路径，降低维护成本并为后续统一 YUV 工具链铺路。

## What Changes

- **新增** Java `Nv12FrameUtil`（或等价工具）：bitmap / ARGB 采样帧 → NV12 direct `ByteBuffer`（stride = width，Y 平面 + interleaved UV）
- **新增** native JNI：`nativeOpencvStainDetectFromNv12`、`nativeOpencvZeroPointDetectFromNv12`、`nativeOpencvEdgeDrawingDetectFromNv12`（与现有 FromI420 对称，内部 `nv12ToBgr` → 现有 detect 入口）
- **迁移** `ProcessVideoAiSession.runInferSample`：`I420FrameUtil.fromBitmap` + `opencvStainDetectFromI420` → NV12 + `opencvStainDetectFromNv12`
- **迁移** 离线零点路径：`ZeroPointDetectNativeSession.detect`、`ZeroPointManualAutoCoordinator` 离线 `MediaMetadataRetriever` 阶段改为 NV12
- **迁移** `AiManager` / `NativeBridge` 公开 API：离线 one-shot 以 `*FromNv12` 为主入口；保留 `*FromI420` 为兼容 shim（内部 I420→NV12 或直调旧路径，见 design）
- **更新** OpenSpec、`OPENCV_DETECT_APP_INTEGRATION.md`、Native API 文档、`verify_libai_jni.sh` 与离线回归 notes
- **明确不改造**（本 change 范围外）：RKNN `inferFromI420` / `nativeRknnStainDetectFromI420`、JPG/RGB 离线入口、live `StreamDetectPipeline`（已 NV12）
- **BREAKING**（规格层）：`lens-det-app-inference` 等离线 process video 要求由 I420 改为 NV12；Java 公共 API 新增 `*FromNv12`，`*FromI420` 标记 deprecated

## Capabilities

### New Capabilities

- `offline-inference-nv12`: 离线 OpenCV 推理统一 NV12 帧契约、Java 转换工具、native `FromNv12` JNI 族与 live `yuv_convert` 复用

### Modified Capabilities

- `lens-det-app-inference`: process video Detect 采样与 one-shot API 由 I420 改为 NV12
- `zero-point-line-detect`: 离线 / 手动自动流程中 zero_point JNI 输入由 I420 改为 NV12
- `native-infer-image-contract`: OpenCV stain / zero_point / edgedrawing JNI 契约增加 NV12 入口，I420 入口 deprecated
- `zero-point-mock-json-debug`: mock 路径描述对齐 NV12 主入口（mock 仍可在 Java 层短路，不经 native）
- `lens-det-emulator-session`: 仪器/模拟器验收场景改为 `FromNv12` 或等价 NV12 喂帧

## Impact

- **Java**: `ProcessVideoAiSession`、`AiManager`、`NativeBridge`、`ZeroPointDetectNativeSession`、`ZeroPointManualAutoCoordinator`；新增/扩展 NV12 工具类；`I420FrameUtil` 保留供 RKNN / 兼容
- **C++ / libai.so**: 三个 OpenCV JNI 模块新增 `FromNv12`；共享 `stream_detect::nv12ToBgr` 或提取至公共 `yuv/` 头文件；`verify_libai_jni.sh` 符号清单
- **规格与文档**: 更新离线 MP4 回归说明（`notes/offline-mp4-regression.md`）、六层 checklist 离线分支
- **测试**: 单元测试 NV12 布局与 payload 尺寸；`DumpRetrieverFrameInstrumentedTest` 对齐 NV12 路径
