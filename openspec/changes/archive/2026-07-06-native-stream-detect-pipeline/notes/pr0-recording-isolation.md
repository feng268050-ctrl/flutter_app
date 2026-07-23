# PR0 录制与 C++ PR1 检测会话隔离验证

## 结论

**PR0 录制（`EasyPlayerClientManger`）与 C++ `StreamDetectPipeline`（PR1 检测）在架构上已隔离**，启用 native 检测管线不会替换或共享 PR0 录制客户端。

## 证据

| 路径 | RTSP 源 | 客户端 | 用途 |
|------|---------|--------|------|
| PR0 录制 | `MediaMtxRelayUrls.localPr0()` / LAN PR0 | `EasyPlayerClientManger` | 过程视频 MP4 录制 |
| PR1 检测（native） | `MediaMtxRelayUrls.resolvePr1Ingest()` | C++ `RtspDemux` 独立 TCP 会话 | 焊接 live 检测 |
| PR1 检测（Java 回退） | 同上 | `LivePr1InferenceStreamClient` | feature flag 关闭时 |

- `EasyPlayerClientManger` 注释与实现均指向 **PR0** 主流录制，不消费 PR1。
- `LivePr1InferenceStreamCoordinator` 在 `isNativeStreamDetectPipelineEnabled()` 为 true 时 **不再** 通过 `LivePr1InferenceStreamHub` 创建 Java PR1 客户端。
- MediaMTX 设计支持多读者：PR0 录制 + PR1 检测为独立 RTSP 会话。

## 验收步骤（RK3566 / 模拟器 + MediaMTX）

1. 开启 native flag（`CameraConfig.isNativeStreamDetectPipelineEnabled()`）。
2. 启动焊接，激光 ON → 确认 logcat `INFER_NATIVE start` 且 **无** `INFER_RTSP hub acquire`。
3. 并行启动 PR0 录制（Quick/Engineer 过程视频）→ 录制文件应正常增长。
4. 激光 OFF → native pipeline stop；录制不受影响。
5. `adb logcat -s StreamDetect EasyPlayerClientManger` 确认两路日志独立。

## 风险

- 若手动零点 `ZeroPointManualAutoCoordinator` 仍 acquire `LivePr1InferenceStreamHub`（`HOLDER_MANUAL_ZERO_POINT`），会在 native 焊接路径之外额外开 Java PR1 会话；与 PR0 录制仍隔离，但增加 PR1 读者数。
