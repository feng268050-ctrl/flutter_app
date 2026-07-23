# 现场 / 手测 checklist（镜片告警弹窗）

## 前置

- 构建未设置 `DISABLE_LENS_GUARD`（默认开启镜片检测），或从 AI Vision 能收到 `LensCheckResultEvent` 的环境。
- Logcat：`LensGuardManager`、`LensDirtyAlert` tag。

## 建议步骤

1. **MILD**：触发 `level==1` 连续回调 → **12s 内**不应叠多个弹窗；**超过 12s** 同档可再弹。
2. **HEAVY**：`level>=2` → 弹窗 + 听 **`onAlert`** 是否已响（弹窗不应二次播音）。
3. **CLEAN**：`level==0` → 弹窗关闭。
4. **生命周期**：弹窗打开时按 Home / 切 Tab → **无** `WindowLeaked`；回 AI Vision 行为正常。
5. **JSON message**：若 native 推框 JSON → 弹窗正文应为 **默认 mild/heavy 文案**，不应整段 JSON。

## 调试

- 若无真实 native，可临时在 Dev 或单测里 `EventBus.getDefault().post(new LensCheckResultEvent(…))`（主线程）模拟。
