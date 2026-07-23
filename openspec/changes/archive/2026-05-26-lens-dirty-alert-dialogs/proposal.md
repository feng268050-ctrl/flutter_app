## Why

镜片脏污等级由 native（`lensinspector`）按 `docs/LENS_GUARD_APP_INTEGRATION.md` 输出；App 当前在 AI Vision 以叠加层文案为主展示 `onCheckResult`，**重度/轻度缺少与等级一致的阻断式告警弹窗**，现场不易引起操作员注意。需要按文档约定在 **AI Vision（第一期）** 落地告警弹窗，其它界面可后续分批接入。

## What Changes

- 在 **AI Vision**（`AiVisionFragment`）根据 `LensCheckResultEvent` 的 **`level` / `status` / `message`** 展示 **AlertDialog**（或 Material 等价组件），行为对齐 `docs/LENS_GUARD_APP_INTEGRATION.md` §6。
- **`level == 0`**：不弹窗（或仅恢复叠加层常态）；不重复打扰。
- **`level == 1`**：提示态弹窗（建议擦拭）；可带「知道了」；考虑 **节流/去重**（同等级连续回调不疯狂叠窗）。
- **`level >= 2`**：告警态弹窗（立即清洗/更换）；**优先展示 native `message`**；文案为空时使用文档默认映射；与 **`level >= 2` 告警音** 建议一致（若已有 `GlobalSoundManager` 路径则复用）。
- **不做**：在 Java 侧重算脏污等级；不改变 native 规则与 `config.yaml` 语义。
- **后续阶段（非本期必交付）**：其它 Activity/Fragment 复用同一套展示策略的说明留在 `design.md` / `tasks.md` 扩展项。

## Capabilities

### New Capabilities

- `ai-vision-lens-dirty-alerts`: AI Vision 界面镜片脏污告警弹窗的触发条件、文案优先级（`message` > 默认映射）、等级与样式（黄/红）、与 `level>=2` 告警音的联动、去重与生命周期（Fragment 可见性、`onPause` 不泄漏）。

### Modified Capabilities

- （无）本期为纯 UI 行为扩展；若未来抽取共享组件并改变全局事件契约，再单独开 change 修改既有 spec。

## Impact

- **代码**：`AiVisionFragment`（EventBus 订阅、`onLensCheckResult`）、可选 **strings** / **theme**、与 `LensCheckResultEvent` 字段使用方式。
- **依赖**：`docs/LENS_GUARD_APP_INTEGRATION.md` 为产品/算法契约；`LensGuardManager` / `NativeBridge` 回调不变。
- **风险**：弹窗频率过高影响操作 → 必须在设计与任务中明确 **防抖/同等级合并** 与 **仅前台可见时弹出**。
