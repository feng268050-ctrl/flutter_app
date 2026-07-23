## Context

- **摄像头通讯告警（C002）** 经 `CameraCommunicationWarnAlarm` → `WarnDialogVo` → `WarnDialogUtil.openDialog` → `dialog_warn.xml` 展示：顶部告警图标、红色 `security_alert_title`、滚动正文、底栏单按钮确认（`confirm_text`）。关闭时走 `WarnCacheManager` 与 `GlobalSoundManager` 既有逻辑。
- **零点偏移提醒** 由 `ZeroPointOffsetWarnAlarm`（`DeferredExternalWarnAlarm`）在激光关光后经 `WeldDeferredWarnCoordinator` 展示；当前为 `AlertDialog.Builder` + `setPositiveButton(知道了)` / `setNegativeButton(去设置)`，系统默认按钮顺序与样式不一致，且跳转 Tab 误为 `0`（设备信息）而非高级设置 `2`。
- 产品要求：零点偏移弹窗**视觉对齐** C002 `WarnDialog`，底栏为**左确认、右跳转**；确认行为与其他告警一致。

## Goals / Non-Goals

**Goals:**

- 零点偏移弹窗使用 `dialog_warn` 壳层（图标、标题色、正文区、无进度条）。
- `WarnDialogVo` 支持可选第二按钮（跳转）及 `onJump` 回调；`WarnDialogUtil` 渲染左右双按钮底栏。
- 左键确认：等同现有 `btn_confirm`（`onConfirm` 若空则仅 dismiss + listener）；零点场景调用 `ZeroPointOffsetWarnAlarm.onDialogDismissed`。
- 右键跳转：启动 `DeviceSettingActivity`，`EXTRA_INITIAL_TAB_INDEX = TAB_INDEX_ADVANCED_SETTINGS`（`2`）。
- 单按钮告警（C002 等）零回归。

**Non-Goals:**

- 不将 C002 改为双按钮（除非后续单独需求）。
- 不迁移 `WarnDialog` 至 `FrostedGlassDialog`（本 change 延续现有严重告警壳层）。
- 不修改零点检测算法或 Modbus 写回逻辑。

## Decisions

### 1. 扩展 `WarnDialogVo` 而非零点专用布局

新增字段：

- `String jumpButtonText` — 右侧按钮文案；非空时显示双按钮模式。
- `Runnable onJump` — 右侧点击回调。

**理由**：C002 与零点偏移共用 `dialog_warn`；双按钮为可选能力，避免复制布局。

**备选**：零点独立 `dialog_zero_point_warn.xml` — 否决，样式漂移风险高。

### 2. `dialog_warn.xml` 底栏结构

将单 `btn_confirm` 改为水平 `LinearLayout`：

- `btn_confirm`（`layout_weight=1`，左侧）
- 竖向分隔线（复用 `info_row_line_style` 或细 `View`）
- `btn_jump`（`layout_weight=1`，右侧，默认 `gone`）

`WarnDialogUtil.openDialog`：当 `jumpButtonText` 非空时显示 `btn_jump` 并绑定 `onJump`；否则保持现单按钮全宽（或仅显示 confirm 占满）。

**按钮顺序**：左确认、右跳转（产品明确要求）。

### 3. `ZeroPointOffsetWarnAlarm` 展示路径

在 `tryShowDialog` 中构建 `WarnDialogVo`：

```text
type = WARN_TYPE
title = security_alert_title
content = zero_point_offset_alert_body
isShowProgress = false
buttonText = confirm_text (或 lens_alert_btn_ack，与 C002 一致用 confirm_text)
jumpButtonText = zero_point_offset_alert_go_settings
onConfirm -> onDialogDismissed
onJump -> 跳转高级设置 + onDialogDismissed 同等清理
```

使用 `Dialog` 实例持有（替换 `AlertDialog`），dismiss 逻辑与现 `currentDialog` 一致。

**理由**：与 C002 同一视觉管道；deferred 队列不经过 `AutoDialogQueue`（零点告警无 warnCode 缓存），保持 `tryShowDialog` 直接展示。

### 4. 高级设置 Tab 索引

使用 `DeviceSettingActivity.TAB_INDEX_ADVANCED_SETTINGS`（`2`），**非** `0`。

**理由**：高级设置页含零点校正入口（`AdvancedSettingFragment`）；`0` 为设备信息，与产品「一键跳转高级设置」不符。

### 5. 跳转后弹窗与 pending 状态

跳转按钮点击后：

- 设置 `dialogAcknowledgedThisBoot = true`、`pendingReminder = false`
- 清除 `ZeroPointPendingCorrectionStore`
- dismiss 对话框
- 调用 `WeldDeferredWarnCoordinator.showNextPendingDialog`

与确认按钮一致，避免返回后重复弹窗。

## Risks / Trade-offs

- **[Risk] 双按钮模式下误触跳转** → 跳转在右、确认为主操作在左，与产品稿一致；可选后续加二次确认（非本 change）。
- **[Risk] `WarnDialogUtil` 静态单例与 deferred 零点弹窗并发** → 零点展示前 `dismissDialog()`；不与 `AutoDialogQueue` 并行打开同一 `WarnDialogUtil` 实例（deferred 协调器串行）。
- **[Risk] Tab 索引与 ViewPager 顺序变更** → 使用命名常量 `TAB_INDEX_ADVANCED_SETTINGS`，单测断言 Intent extra。

## Migration Plan

1. 扩展 layout + `WarnDialogVo` + `WarnDialogUtil`（向后兼容）。
2. 重构 `ZeroPointOffsetWarnAlarm.tryShowDialog`。
3. 手动验证：Quick/Engineer 连续焊关光后弹窗样式、左确认关闭、右跳转进入高级设置 Tab。
4. 回归 C002 单按钮弹窗与 Modbus 严重告警。

## Open Questions

- 右侧按钮文案沿用 `zero_point_offset_alert_go_settings`（「去设置」）还是改为「跳转」专用 string — **默认沿用现有 string**，与 archived 产线需求一致。
