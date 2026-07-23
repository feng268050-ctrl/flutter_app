# level / status / message → UI 映射（AI Vision）

对照 `docs/LENS_GUARD_APP_INTEGRATION.md` 与 `LensCheckResultEvent`（native → `LensGuardManager` → EventBus）。

| `level` | 典型 `status`（native） | `message` | 叠加层 `tvAiResult` | 告警弹窗（`LensDirtyAlertDialogCoordinator`） |
|--------|-------------------------|-----------|---------------------|-----------------------------------------------|
| 0 | `CLEAN` 等 | 人读文案或空 | 显示「最新结果：…」；空则用 `ai_overlay_result_waiting` | **不弹窗**；若有未关弹窗则 **dismiss** |
| 1 | `MILD` / `STAIN_MILD` 等 | 优先人读；可为 JSON（框） | 仍用 `message` 全文作前缀（含 JSON 时与现逻辑一致） | **提示**：标题 `lens_alert_mild_title`；正文 **非空且非 JSON** 用 `message`，否则 `lens_alert_mild_body_default` |
| ≥2 | `HEAVY` 等 | 同上 | 同上 | **告警**：标题 `lens_alert_heavy_title`；正文 **非空且非 JSON** 用 `message`，否则 `lens_alert_heavy_body_default` |

**去重**：同一 severity 档（轻度=1、重度=2）在 **12s** 内不重复弹窗；**等级变化**（如 1→2）立即允许新窗。

**告警音**：仅 **`onAlert` → `GlobalSoundManager.warnSound()`**；弹窗路径不播音。
