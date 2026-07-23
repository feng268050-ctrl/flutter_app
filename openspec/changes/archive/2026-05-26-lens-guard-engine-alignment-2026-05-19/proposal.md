## Why

Lens Guard 引擎（lensinspector，2026-05-19 交付）默认 **det-only**（`models.cls.enabled: false`），并新增 **`nativeInferImageToJson`** 供 AI Vision 离线录像时间轴使用。App 侧已有 JNI 声明与 `inferJpgToJson` 路径，但离线推理仍被 `SKIP_OFFLINE_INFERENCE_FOR_UPLOAD` 绕过，且 UI/状态机仍按「分类 + MONITORING」长期可用来设计。

分类与其它检测模型只是**阶段性关闭**，后续会重新开启并可能增加新模型。本次对齐必须在满足当前引擎契约的同时，建立**可探测、可降级、可恢复**的 App 能力层，避免把 det-only 写成永久删除逻辑。

权威对接摘要：仓库根目录 [`LENS_GUARD_APP_ALIGNMENT_2026-05-19.md`](../../../LENS_GUARD_APP_ALIGNMENT_2026-05-19.md)。

## What Changes

- 引入 **Lens Guard 能力画像（Capability Profile）**：根据设备 `config.yaml`（及可选 native 探测）判断 cls / det / 离线 JSON JNI 等是否可用，供 UI 与流程分支使用，而非硬编码「无分类」。
- **启用离线推理管线**：在 `libai.so` 含 `nativeInferImageToJson` 时关闭 `SKIP_OFFLINE_INFERENCE_FOR_UPLOAD`；`code == 0` 才推进时间轴；失败有明确日志与用户提示（对齐文档 §3、§8）。
- **det-only 降级 UI**：分类面板在 cls 不可用时展示「分类未启用」或隐藏；`getLastClsResult` 长期 `valid:false` 视为预期；**不**将推流故障与 cls 关闭混淆。
- **状态机解耦**：焊中与 AI Vision 叠加层 **不得** 将 `onStateChanged(1)`（MONITORING）作为唯一前置条件；cls 恢复或新模型接入时无需重写主流程。
- **BREAKING（引擎侧，App 适配）**：激光 ON 在 det-only 下 **不** 进入 `MONITORING(1)`；污点 det、预览 det、生产 `onCheckResult` 行为不变。
- **打包与验收**：ai-library manifest / bundled zip 须指向含离线 JNI 的 `libai.so`；台架按对齐文档 §8 六项验收。
- **文档收敛（App 范围）**：不再将异常辅助、`clean_ref` 等作为新功能门禁；已有代码可保留。

## Capabilities

### New Capabilities

- `lens-guard-capability-profile`: 从部署后的 `config.yaml` 与运行时探测（如离线 JNI 符号/调用可用性）汇总引擎能力，向 UI 与 Manager 提供稳定查询 API。
- `lens-guard-offline-infer-json`: AI Vision 离线抽帧 → `inferJpgToJson` → JSON 时间轴与推理 MP4 上传的端到端契约与失败语义。
- `lens-guard-det-only-ui`: cls 关闭或无效快照时的展示与交互降级；MONITORING 缺失时的状态展示策略。

### Modified Capabilities

- `lens-guard-package-migration`: 补充「能力随 config/引擎版本变化」时回调与 EventBus 语义仍成立，但 MONITORING 与 cls 快照可能长期不出现属预期。
- `native-infer-image-contract`: 扩展 `nativeInferImageToJson` JSON 返回契约（与 `nativeInferImageAndSave` 区分）。

## Impact

- **代码**：`LensGuardManager`, `NativeBridge`, `AiVisionFragment`, `LensClsSnapshotEvent` 消费处、ai-library 打包脚本/manifest、可选 strings 资源。
- **依赖**：Workers `ai-library` zip 须含 `nativeInferImageToJson`；版本号 alone 不足以判断能力。
- **产品**：焊中自动聚焦 UI 在 det-only 下需降级或隐藏，直至 `models.cls.enabled: true` 且 native 会话重启。
- **测试**：对齐文档 §8 台架清单；现有 instrumented 路径可复用 `inferJpgToJson`。
