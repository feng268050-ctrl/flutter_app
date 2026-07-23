## Context

- `LensGuardManager` 在 `LaserApplication` 启动时 `start()`，并通过 `MemoryCacheManager` 监听 `DeviceStatus` 调用 `nativeSetLaserOn`——激光语义已正确。
- 实时帧输入仅在 `EasyPlayerClientManger` 的 I420 回调中调用 `LensGuardManager.onI420Frame()`；该管理器由 `CameraController` 在**开始/结束录像**时 `start()`/`stop()`，且固定连接 `CameraConfig.recordingRtspUrl()`（主流 **PR0**）。
- 因此快速/工程师模式下「开光不录像」时 native 认为激光 ON 但无帧，焊中 AI 实际 idle。
- AI Vision 监控 Tab 已有独立 `EasyPlayerClient` + `liveInferenceRtspUrl`（PR1），与本变更范围分离但应复用同一 URL 约定。

## Goals / Non-Goals

**Goals:**

- PR1 子流推理客户端随激光 ON/OFF 启停，向 `LensGuardManager` 持续推帧（引擎已运行时）。
- PR0 主流录像仍仅由 `CameraController` / `EasyPlayerClientManger` 控制，与推理解耦。
- 激光 ON + 录像 ON 时双客户端并行，互不因一方 stop 而误停另一方。
- 日志可区分 `laser_on` / `laser_off` 与 `record_start` / `record_stop`。

**Non-Goals:**

- 不改变 AI Vision Tab 的预览/离线分析 UX。
- 不修改 native 模型、det-only 状态机或 R2 上传链路。
- 不在本期重构为全新播放器架构。

## Decisions

1. **新增推理专用 RTSP 客户端（推荐）**  
   - 抽取或新增 `ProductionInferenceStreamClient`（名称实现时可调整），虚拟 Surface + `EasyPlayerClient`，URL = `CameraConfig.liveInferenceRtspUrl()`。  
   - 激光 ON → `start()`；激光 OFF → `stop()`。  
   - I420 回调仅 `LensGuardManager.onI420Frame` + `updateFrameSize`。  
   - **备选（不采用）**：继续复用 `EasyPlayerClientManger` 并在录像时切 URL——无法同时 PR0 录 + PR1 推帧，且 stop 录像会误停推理。

2. **激光状态来源**  
   - 复用 `LensGuardManager` 已监听的 `CacheKey.DEVICE_STATUS_KEY` / `DeviceStatus.isLaserOn()`。  
   - 在快速/工程师模式 Activity 或共享 coordinator 中，在模式进入时注册、退出时注销，避免 AI Vision Tab 外误启子流。  
   - 与 `showBlurMask`/`hideBlurMask`（Quick）及 `switchLaserEnable`（Engineer）写入的 Modbus/缓存状态保持一致。

3. **录像路径瘦身**  
   - `EasyPlayerClientManger` 保留 PR0 录制职责；移除（或不再作为生产推理来源）其向 `LensGuardManager` 的帧推送，避免双路重复 `pushFrame`。  
   - `CameraController` 计时动画中的 `start()`/`stop()` 仅影响录制客户端。

4. **并发与资源**  
   - 双 `EasyPlayerClient` 在 RK 平台上已有 AI Vision + 录制先例；需验证 eth0 带宽与 CPU，必要时维持现有 AI 帧线程池与限频。  
   - 激光 OFF 时必须先停推理客户端再依赖焊后 det（引擎仍 running，激光 OFF 路径不变）。

5. **失败与降级**  
   - 子流连接失败：记录 fallback 原因；可选按 `CameraConfig` live policy 回退（与 AI Vision 一致），但不得回退为「必须录像才推帧」。  
   - 引擎未 `isRunning()` 时启动推理流无意义——保持与 today 相同，仅 bootstrap 后生效。

## Risks / Trade-offs

- **[Risk] 双路 RTSP 增加 eth0/解码负载** → Mitigation：子流分辨率由 IPC 配置；现场对比四象限；保留单客户端时的快速回滚开关（feature flag 可选）。  
- **[Risk] 激光状态与 Modbus 延迟导致短窗口无帧** → Mitigation：以 `DeviceStatus` 缓存为准，与现有 `pushCurrentLaserState` 对齐；日志记录 laser 边沿与流启停时间差。  
- **[Risk] 模式切换未注销导致子流泄漏** → Mitigation：Activity `onDestroy` / 离模式时强制 `stopInferenceStream()`。

## Migration Plan

1. 实现推理客户端 + 激光监听，单元/仪器测试验证激光边沿。  
2. 从 `EasyPlayerClientManger` 移除生产推理推帧（保留录制）。  
3. 现场矩阵：激光 × 录像 × 快速/工程师；确认 PR1 日志与焊中告警。  
4. 若回退：恢复旧行为需重新耦合录像推帧（不推荐长期保留）。

## Open Questions

- 快速模式 `showBlurMask` 的 `laserStatus` UI 绑定是否与 `DeviceStatus.isLaserOn()` 完全同步（需实现时核对 Modbus 回读时机）。  
- CNC 切割等隐藏录像浮窗的模式是否应禁止推理子流（当前隐藏浮窗并 `tryStopRecord`——推理亦应 OFF）。
