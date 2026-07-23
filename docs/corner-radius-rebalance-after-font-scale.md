# 字体放大后的圆角再平衡（分阶段）

## 背景

近期改动主要是**字号抬高（约 +5sp）与控件高度/间距调整**；圆角 token 本身几乎未动。观感问题来自「字更大、壳更高，半径仍按旧比例」，以及部分 drawable **硬编码半径与 token 不一致**。

本文只列**优先级最高、建议分阶段修**的项。胶囊类（30dp / 半高圆角）比例正确，不在此列。

## 当前主 token（基线 → 已落地）

| Token | 旧值 | 现值 | 典型用途 |
|-------|------|------|----------|
| `frost_corner_radius` | 24dp | **28dp** | Frost 卡片 / 对话框壳 / Live Monitor 表盘面板 |
| `frost_rectangle_button_corner_radius` | 12dp | **14dp** | Frost 矩形按钮、输入框 |
| `engineer_toggle_btn_corner_radius` | 10dp | **14dp** | Laser Enable、工程师可逆开关 |
| `home_stat_card_corner_radius` | 18dp | **22dp** | 首页统计卡 / 快捷入口 |
| `ai_vision_overlay_hud_corner_radius` | 20dp | 20dp（未动） | AI Vision HUD |

原则：

- **优先改 token / 单一入口**，再扫硬编码。
- 每个阶段改完后在 **emulator-5554** 上对关键页目视验收，再进入下一阶段。
- 不要把 A/B 键盘或胶囊控件的圆角并进矩形按钮体系。

---

## Phase 1 — 工程师大按钮（最高优先）✅

**问题：** Laser Enable / 连续焊设备控制按钮高度已到约 72–104dp，字也更大，仍用 **10dp** clip，最容易显得「方角、比例失调」。

**落地：** `engineer_toggle_btn_corner_radius` **10 → 14dp**；`frost_reversible_ripple_corner_radius` 已 alias。工程师相关 drawable（`pline_btn_background` / `pline_disable_btn_background` / `base_btn_background`）改为引用该 token。

**关键入口：**

| 路径 | 说明 |
|------|------|
| `app/src/main/res/values/dimens.xml` → `engineer_toggle_btn_corner_radius` | token |
| `EngineerToggleButtonChrome.kt` | outline clip |
| `FrostReversibleRippleAppearance.kt` | ripple 圆角 |
| `engineer_continuous_device_controls.xml` 及相关 layout | 连续焊左栏大按钮 |
| `pline_btn_background.xml` 等 | 已改为 `@dimen/engineer_toggle_btn_corner_radius` |

**验收：** 工程师模式 · 连续焊左栏 + Laser Enable 开/关态；ripple 填充边缘与 fill 一致。

---

## Phase 2 — Frost 矩形按钮对齐 token ✅

**问题：** `frost_button_primary.xml` / `frost_button_secondary.xml` 写死 **14dp**，与 token **12dp** 不一致。

**落地：** drawable 改为 `@dimen/frost_rectangle_button_corner_radius`；token **12 → 14dp**（与原 XML 观感对齐，并适配字号放大）。`FrostButton` / `dialog_edit_bg` 等已读同一 token。

**验收：** 任意 Frost 对话框主/次按钮；与同页 `FrostButton` 控件圆角一致。

---

## Phase 3 — Frost 面板壳 + 状态磁贴 / Live Monitor ✅

**问题：** 面板仍用 `frost_corner_radius` **24dp**。标题/正文变大、磁贴绿底大字、表盘面板变高后，外壳可能显得偏钝或与内部内容「脱节」。

**落地：** `frost_corner_radius` **24 → 28dp**（+4，一次改 token），覆盖 FrostCard / dialog shell / 状态磁贴 / Live Monitor 表盘面板 / Wi‑Fi 行等已引用表面。

**验收：** 机台状态磁贴（Idle / Success）、Laser Current 表盘卡、任意标准 Frost 对话框。

---

## Phase 4 — 首页卡片与同页圆角层级 ✅

**问题：** 首页用 `home_stat_card_corner_radius` **18dp**；字放大后卡片圆角与字块比例可能偏紧。

**落地：** `home_stat_card_corner_radius` **18 → 22dp**（+4），保持低于面板壳 28dp 的层级差。

**验收：** 首页首屏各入口卡；点击 ripple 边缘与卡片一致。

---

## 后续（不阻塞前四阶段）

以下可单独开小任务：

- AI Vision HUD（`ai_vision_overlay_hud_corner_radius` 20dp）字号/HUD 密度变化后再调。
- 遗留硬编码：`spinner_dropdown_bg` 8dp、`engineer_base_box` 15dp、`dialog_bg*` 16dp、`popup_rounded_bg` 10dp、CNC border 8dp 等，逐步迁到对应 token。
- 底栏 / tab 顶圆角与工程师 toggle 体系的视觉跳变，放在工程师 + 首页都稳定后再统一尺度表。

---

## 建议实施顺序（摘要）

```text
Phase 1  engineer_toggle 10→14dp + drawable 收口     ✅
    ↓
Phase 2  Frost 按钮对齐 token；token 12→14dp         ✅
    ↓
Phase 3  frost_corner_radius 24→28dp                 ✅
    ↓
Phase 4  home_stat_card 18→22dp                      ✅
    ↓
后续     HUD + 遗留硬编码收口
```

每阶段：改 token → 扫同场景硬编码 → `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync` → 目视通过再合入。

## 非目标

- 不合并专用数字键盘与 QWERTY 符号层布局。
- 不把胶囊滑条 / switch track 的半高圆角改成矩形按钮半径。
- 不在未验收的情况下全局批量替换所有 `android:radius` 硬编码。
