## Context

- 脏污等级与 `message` 由 native 产出，App 只展示；契约见 **`docs/LENS_GUARD_APP_INTEGRATION.md`** §6。
- 事件链路：`LensGuardManager` → `NativeListener.onCheckResult` → `EventBus` → **`LensCheckResultEvent`** → **`AiVisionFragment.onLensCheckResult`**（当前更新 `tvAiResult` 与 overlay）。
- **落地（已实现）**：`LensDirtyAlertDialogCoordinator` + `AiVisionFragment` 在 `onLensCheckResult` 末尾调度弹窗；`onPause`/`onDestroyView` dismiss；详见 `notes/level-status-ui-mapping.md`。
- 第一期仅 **AI Vision**；后续若其它页面也要弹窗，应抽取 **可复用控制器/helper**（非本期强制交付）。

## Goals / Non-Goals

**Goals:**

- 在 **AI Vision 可见且 resumed** 时，按 **`level`** 弹出与文档一致的 **对话框**（MILD / HEAVY 区分样式与文案）。
- **`message` 非空时优先展示**；否则使用文档 §5.2 默认中文映射。
- **`level >= 2`**：与文档一致触发 **告警音**（若工程已有 `GlobalSoundManager` / native `onAlert` 路径，避免重复刺耳，见决策）。
- **去重/节流**：避免同一手势周期内数十次 `onCheckResult` 叠多个 `Dialog`；`level==0` 关闭已显示的同主题弹窗或不再弹新窗。

**Non-Goals:**

- 不在 Java 实现 `docs/LENS_GUARD_APP_INTEGRATION.md` §6.2 规则；不改 `config.yaml`。
- 本期不强制实现 **其它 Activity** 的弹窗（仅预留扩展点说明）。
- 不强制改 native 或增加新 JNI（除非后续发现 `status` 必须解析）。

## Decisions

1. **对话框技术栈**  
   - *选择*：优先 **`androidx.appcompat.app.AlertDialog`**（或项目已有 Material `MaterialAlertDialogBuilder` 若已依赖）。  
   - *理由*：与现有 Fragment 生命周期兼容、易在主线程展示。  
   - *备选*：全屏 `DialogFragment` — 过重，本期不采用。

2. **展示入口**  
   - *选择*：仅在 **`AiVisionFragment`** 的 `@Subscribe onLensCheckResult`（主线程）内调度弹窗；`isAdded() && getContext() != null` 且 **`getLifecycle().getCurrentState().isAtLeast(STARTED)`** 才显示。  
   - *理由*：与「第一期 AI Vision」范围一致。

3. **与告警音关系**  
   - *选择*：`level >= 2` 时弹窗与 **`LensGuardManager` / native 已有 `onAlert`** 可能重复发声；若 `onAlert` 已播，弹窗路径 **不再二次播放**，或 **统一由一处**（优先 native `onAlert`）负责声音，App 弹窗只做视觉。具体以现场不「双响」为准，在实现时二选一并在代码注释标明。  
   - *备选*：仅弹窗内振动/静音 — 与文档 §6「建议以 level>=2 为准」略冲突，故不推荐默认。

4. **去重策略**  
   - *选择*：维护 **`lastAlertLevel`** + **`lastAlertDialogShownElapsed`**（或 `SystemClock.elapsedRealtime()`）：同 `level` 在 **T 秒**（建议 **8–15s** 可配置常量）内不重复弹同等级对话框；`level` 升高（0→1→2）**立即**允许新窗。  
   - *备选*：每次 HEAVY 都弹 — 操作员会崩溃；不采用。

5. **`level == 0`**  
   - *选择*：**不弹窗**；若当前有 MILD/HEAVY 对话框仍显示，**dismiss** 或更新为「已恢复」单行（二选一：推荐 **dismiss** 保持简单）。  
   - *理由*：文档 §5.1 洁净为正常态。

6. **字符串**  
   - *选择*：`strings.xml` 放默认映射文案；native `message` 优先时直接 `setMessage(message)`。

## Risks / Trade-offs

- **[Risk] 弹窗打断缩放/触控** → *Mitigation*：对话框可取消、非 `cancelable(false)`（HEAVY 若产品要求强提示可配置为 false，默认 true 降低误锁）。  
- **[Risk] 旋转/重建导致 WindowLeaked** → *Mitigation*：持有 `Dialog` 弱引用或在 `onPause`/`onDestroyView` dismiss；用 `LifecycleObserver` 可选。  
- **[Risk] EventBus 在后台页面仍投递** → *Mitigation*：`isResumed()` 检查；或仅当 AI Vision tab 选中时处理（若父 Activity 有 tab 状态可查询）。

## Migration Plan

1. 实现后仅在 **AI Vision** 灰度验证。  
2. 无数据迁移；回滚为移除订阅内弹窗调用即可。

## Open Questions

- HEAVY 弹窗是否 **`setCancelable(false)`** 需产品拍板。  
- 告警音是否已由 **`onAlert`** 全覆盖 — 实现前读 `LensGuardManager` 与 `GlobalSoundManager` 调用链确认。
