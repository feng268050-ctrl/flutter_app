## 1. 对齐契约与现有回调

- [x] 1.1 对照 `docs/LENS_GUARD_APP_INTEGRATION.md` 与 `LensCheckResultEvent` / `AiVisionFragment.onLensCheckResult` 现状，列出 `level`/`status`/`message` 与 UI 映射表（含空 `message` 默认文案）。
- [x] 1.2 阅读 `LensGuardManager` 中 `onAlert` 与 `GlobalSoundManager` 调用，在代码或注释中确定 **`level>=2` 告警音单一来源**，避免双响。

## 2. AI Vision：弹窗与去重（第一期交付）

- [x] 2.1 在 `strings.xml`（及必要时 `themes`）增加 MILD / HEAVY 默认标题与正文、按钮文案（如「知道了」），与文档 §5.2 一致；保留 native `message` 优先策略。
- [x] 2.2 实现可测试的弹窗调度逻辑（独立小类或 `AiVisionFragment` 内私有方法）：`level==1` / `level>=2` 分支、`level==0` dismiss、**同等级节流窗口**（常量建议 8–15s，可配置在 `AiVisionFragment`）、`level` 升级立即允许新弹窗。
- [x] 2.3 仅在 `isAdded()`、`getContext()` 非空、**`Lifecycle.State` 至少 `STARTED`**（或 `isResumed()`，按设计定稿）时 `show()`；`onPause` / `onDestroyView` 安全 **dismiss** 持有对话框引用，避免泄漏。
- [x] 2.4 在 `onLensCheckResult` 接入上述调度；保持现有 `tvAiResult` / overlay 更新行为不回归（可与弹窗并存）。
- [x] 2.5 手测：MILD 连续回调不叠窗；0→2→0 dismiss；旋转/退后台不崩溃；无 LensGuard 或未启动引擎时不误弹。

## 3. 验证与文档

- [x] 3.1 在 `docs/LENS_GUARD_APP_INTEGRATION.md` §6.3 或本文档 `design.md` 增加一句指向：AI Vision 已实现弹窗（可选，若产品希望单一事实来源则只更新 `design.md` 的「落地路径」段落）。
- [x] 3.2 补充或更新 `openspec/changes/lens-dirty-alert-dialogs/notes/` 下简短现场 checklist（可选）：模拟 `level` 的 log/调试入口说明。

## 4. 后续阶段（非第一期必做；可另开 change）

- [ ] 4.1 抽取 **`LensDirtyAlertUi`**（或同名）供其它界面复用，入参 `(Context, level, message, policy)`。
- [ ] 4.2 在第二个宿主界面（如工程师模式/设备监控其它 Tab）接入并走同一去重策略或独立计数器。
