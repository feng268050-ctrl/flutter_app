## 1. Native — NV12 JNI 与色彩路径

- [x] 1.1 确认 `stream_detect/yuv_convert` 可被 opencv_stain / zero_point / edgedrawing JNI 链接（提取公共头或 CMake 源文件列表）
- [x] 1.2 实现 `nativeOpencvStainDetectFromNv12`（`opencv_stain_detect_jni.cpp`），内部 `nv12ToBgr` → 现有 stain 入口
- [x] 1.3 实现 `nativeOpencvZeroPointDetectFromNv12`（`zero_point_jni.cpp`）
- [x] 1.4 实现 `nativeOpencvEdgeDrawingDetectFromNv12`（`edgedrawing_jni.cpp`）
- [x] 1.5 将 `nativeOpencv*FromI420` 改为 `i420ToNv12` → `nv12ToBgr` shim（移除独立 `COLOR_YUV2BGR_I420` 主路径）
- [x] 1.6 更新 `CMakeLists.txt` undefined-symbol 列表与 `verify_libai_jni.sh`

## 2. Java — Nv12FrameUtil 与 API

- [x] 2.1 新增 `Nv12FrameUtil`：`fromBitmap`、`preparePayload`、`toDirectBuffer`、尺寸校验（镜像 `I420FrameUtil` API 形状）
- [x] 2.2 单元测试：固定小 bitmap golden NV12 layout 与 capacity 校验
- [x] 2.3 `NativeBridge` 声明三个 `nativeOpencv*FromNv12`；`AiManager.opencvStainDetectFromNv12` + busy/executor 对称 I420
- [x] 2.4 `@Deprecated` 标记 `opencvStainDetectFromI420` 及文档指向 NV12 主入口

## 3. 调用点迁移

- [x] 3.1 `ProcessVideoAiSession.runInferSample`：`Nv12FrameUtil.fromBitmap` + `opencvStainDetectFromNv12`
- [x] 3.2 `ZeroPointDetectNativeSession`：新增 NV12 detect；离线路径改调 `FromNv12`
- [x] 3.3 `ZeroPointManualAutoCoordinator` 离线 retriever 阶段：bitmap → NV12 → session detect
- [x] 3.4 审计其余 `FromI420` Java 调用（grep）；live 路径应无残留；RKNN I420 记录为 out-of-scope

## 4. 文档、规格与回归

- [x] 4.1 更新 `docs/OPENCV_DETECT_APP_INTEGRATION.md` 离线分支（NV12 六层 checklist）
- [x] 4.2 更新 `native/lensinspector/docs/OPENCV_STAIN_DETECT_NATIVE_API.md`、`ZERO_POINT_NATIVE_API.md`、`EDGEDRAWING_NATIVE_API.md`
- [x] 4.3 更新 `notes/offline-mp4-regression.md`：基线对比 I420→NV12 后 process video 200 ms 网格
- [x] 4.4 更新 `DumpRetrieverFrameInstrumentedTest`（若仍 dump I420，增加 NV12 路径或注释对齐）
- [ ] 4.5 Emulator：`ProcessVideoAiSession` Detect 冒烟 + logcat `process_video_lens_det sample_ok`

## 5. 验证与归档

- [x] 5.1 `./native/lensinspector/scripts/verify_libai_jni.sh` 通过（含新符号）
- [x] 5.2 单元/仪器测试绿；`make sync` 模拟器工艺视频 Detect 目视确认 overlay/timeline
- [ ] 5.3 `openspec archive offline-inference-nv12-unification -y` 合并 delta specs
