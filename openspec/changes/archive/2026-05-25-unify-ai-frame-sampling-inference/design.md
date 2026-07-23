## Context

当前两条实时推理路径：

| 路径 | 帧来源 | 节流方式 | 间隔 |
|------|--------|----------|------|
| 快速/工程师（`ProductionInferenceStreamClient`） | 子码流 I420 回调 | **无** — 每帧 `onI420Frame` | ~25fps |
| AI Vision 直播（`AiVisionFragment`） | TextureView `getBitmap` | Handler `postDelayed` | 500ms |

`LensGuardManager.onI420Frame` 对每帧做 `byte[]` 拷贝并提交 `LensGuard-I420` 单线程队列执行 `guardedPushFrame`，生产模式下队列易饱和（`DiscardOldestPolicy`），仍浪费解码线程与拷贝 CPU。

AI Vision 离线推理（`inferJpgToJson` + `OFFLINE_VIDEO_INFERENCE_SAMPLE_INTERVAL_MS`）已是文件级抽帧，与本次无关。

## Goals / Non-Goals

**Goals:**

- 提供单一、可测试的抽帧门控抽象，配置 `sampleIntervalMs` 即可区分场景。
- 生产模式默认 **2000ms**；AI Vision 直播默认 **500ms**（行为与现网一致）。
- 在拷贝/入队之前丢弃多余帧，降低 CPU 与 RKNN 压力。
- 常量与 profile 集中定义，避免魔法数散落。

**Non-Goals:**

- 不改变激光 ON/OFF 驱动子码流连接的生命周期（`ProductionInferenceStreamCoordinator`）。
- 不改变离线 `inferJpgToJson` 时间轴抽帧间隔。
- 不改变双码流 URL、letterbox 640、RKNN JNI 契约。
- 不在此变更中做动态自适应抽帧（负载感知调节间隔）。

## Decisions

### 1. 新增 `AiFrameSamplingGate`（`com.lasercyber.lws.ai`）

轻量类，构造时传入 `sampleIntervalMs`，提供：

```java
boolean tryAccept(long monotonicMs);  // true = 本帧应进入推理管线
void reset();                         // 流停止 / profile 切换时清零
```

- 使用 `SystemClock.elapsedRealtime()` 比较上次接受时间。
- **Rationale**: 与 UI Handler 解耦，生产 I420 回调与 AI Vision 均可调用；比把间隔逻辑塞进 `LensGuardManager` 更清晰。

**Alternative considered**: 仅在 `LensGuardManager` 内用静态 profile —  rejected，Manager 已承担引擎生命周期，不宜再持有场景 profile 状态。

### 2. 生产路径：门控置于 `onI420Frame` 入口（拷贝前）

`LensGuardManager` 持有 `AiFrameSamplingGate productionGate`（2000ms），在 `buffer.get(data)` 之前 `tryAccept`；拒绝则直接 return。

`ProductionInferenceStreamClient` 保持调用 `onI420Frame`，无需改 EasyPlayer 回调结构。

**Rationale**: 最早丢弃可避免每帧 `byte[]` 分配与线程池提交，是生产模式性能收益最大的位置。

### 3. AI Vision 直播：保留 Handler 调度，统一到 profile 常量

`AiVisionFragment` 继续 `mainHandler.postDelayed(aiFrameSampleTask, interval)`，但：

- `AI_FRAME_SAMPLE_INTERVAL_MS` 改为引用 `AiFrameSamplingInterval.AI_VISION_LIVE.getIntervalMs()`（500）。
- `onBitmapFrame` 入口增加同一 profile 的 gate（防御性，避免 Handler 漂移导致连推）。

**Alternative considered**: 改为 I420 子码流 + gate — rejected，AI Vision 刻意走 TextureView 小图，与 MediaCodec Surface 直出路径分离（见 `LensGuardManager.onBitmapFrame` 注释）。

### 4. Profile 枚举集中默认间隔

```java
public enum AiFrameSamplingInterval {
    PRODUCTION_WELD(2000L),
    AI_VISION_LIVE(500L);
}
```

`LensGuardManager` 在 `start()` / `stop()` 时 `productionGate.reset()`；AI Vision `scheduleAiFrameSampling` / `stopAiFrameSampling` 时 reset 直播 gate（可由 Fragment 持有或 Manager 提供 `resetGate(profile)`）。

### 5. 可观测性

调试日志（`LogTAGConstant` / `LensGuard`）：profile 名、interval、每 N 次 accept 计数。避免每帧 info 刷屏。

## Risks / Trade-offs

- **[Risk] 生产模式检测延迟升至 2s** → 与产品确认焊接污染告警可接受；`publishLastClsSnapshotIfDue` 周期需对照验证。
- **[Risk] Gate 与 Handler 双路径语义不一致** → AI Vision 以 Handler 为主、gate 为辅；单测覆盖 `tryAccept` 边界（0ms、interval-1、interval、burst）。
- **[Risk] 流重启后首帧延迟** → `reset()` 后首帧立即 accept（`lastAcceptMs = 0` 或 `-interval` 初始化策略）。

## Migration Plan

1. 实现 `AiFrameSamplingGate` + `AiFrameSamplingInterval` + 单元测试。
2. `LensGuardManager.onI420Frame` 接入 production gate。
3. `AiVisionFragment` 改用 profile 常量；`onBitmapFrame` 加 gate。
4. 字段设备验证：激光开 + 快速模式，确认 log 推送间隔 ≈2s；AI Vision 直播 ≈500ms。
5. 无配置迁移；默认硬编码 profile。

## Open Questions

- 生产 2s 间隔是否需 Advanced Settings 可配置？**当前假设：否**，固定常量即可。
- `publishLastClsSnapshotIfDue` 是否依赖推帧频率？实现时需读代码确认；若依赖，文档注明最小推送间隔。
