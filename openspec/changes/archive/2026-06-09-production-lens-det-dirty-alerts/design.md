## Context

- **原 RKNN 产线告警**：`LensHeavyContaminationAlarmController` 在**激光上升沿**弹重度窗——与新产品要求冲突，需改为**激光停止后**弹出。
- **lens_det**：二值检测，映射为 `level=2`；不涉及轻度。
- **zero_point**：激光 ON 后 500ms×4 采样；超容差时写 0090H，现无产线弹窗。
- **产品补充（2026-05-29）**：
  1. 只保留重度污染（`level >= 2`）
  2. 零点文案「零点偏移中心请及时校正」，确认 + 跳转设置
  3. **两类弹窗均在激光停止后再弹出**

## Goals / Non-Goals

**Goals:**

- 产线焊接（连续焊/点焊）仅 **level >= 2** 脏污提醒；激光 **关光后** 弹 `WarnDialog`（标题 `安全警报`，正文 `镜片重度污染，立即清洗/更换` + 可选「点击确认可继续出光」）。
- 零点偏移超容差时，激光 **关光后** 弹双按钮窗：确认 / 跳转高级设置（`DeviceSettingActivity`，`EXTRA_INITIAL_TAB_INDEX=0`）。
- 激光 **ON** 期间两类窗均不显示（仅记 pending）。
- RKNN 与 `production_lens_det` 共用同一套「pending + 激光停止展示」状态机。

**Non-Goals:**

- 轻度污染（`level == 1`）产线弹窗；`LensDirtyAlertDialogCoordinator` 接入产线焊接界面。
- AI Vision 直播/工艺视频阻断弹窗。
- 修改 native 阈值或零点/脏污算法。

## Decisions

### 1. 触发时机：激光下降沿（ON → OFF）

将 `LensHeavyContaminationAlarmController` 的 `maybeShowReminder()` 从 `risingEdge` 改为 **`fallingEdge`**（`lastLaserOn && !laserOn`），且调用前断言 `!isLaserOn()`。

零点弹窗同理：在 `ZeroPointDetectCoordinator` 任务判定 `!isWithinPositionTolerance` 时设 `pendingZeroPointAlert`；在激光下降沿由 `ZeroPointOffsetAlertCoordinator`（或内联）展示。

**Rationale**：出光中不打扰；关光后操作员可处理镜片/零点。

**Alternative**：保持上升沿弹脏污窗 → 产品已否决。

### 2. 仅重度脏污

| 事件 level | 产线焊接行为 |
|------------|----------------|
| `>= 2` | 记 pending，关光后弹重度窗 |
| `== 1` | **忽略**（不 pending、不弹窗） |
| `== 0` | 清除脏污 pending |

`lens_det` 有 target → `level=2`；无 target → `level=0`。

### 3. 重度脏污弹窗内容（中文）

| 字段 | 文案 |
|------|------|
| 标题 | 安全警报（`security_alert_title`） |
| 正文 | 镜片重度污染，立即清洗/更换（`lens_alert_heavy_body_default`） |
| 按钮 | 知道了（`lens_alert_btn_ack`） |
| 告警码 | `ALARM_L001` |

单按钮；与现 `WarnDialogUtil` 一致。可选保留第二段「点击确认可继续出光」——若产品认为关光后已停光可省略（**建议关光场景去掉第二段**，避免语义冲突）。

### 4. 零点偏移弹窗

| 字段 | 文案（中文） |
|------|----------------|
| 标题 | 提示（或复用 `security_alert_title` / 专用 `zero_point_offset_alert_title`） |
| 正文 | **零点偏移中心请及时校正** |
| 确认按钮 | 知道了 / 确认 |
| 跳转按钮 | **去设置**（跳转 `DeviceSettingActivity`，高级设置 Tab index `0`） |

实现：`AlertDialog.Builder` 双按钮，或扩展 `WarnDialogVo` + 布局第二按钮。跳转：

```java
Intent intent = new Intent(context, DeviceSettingActivity.class);
intent.putExtra(DeviceSettingActivity.EXTRA_INITIAL_TAB_INDEX, 0);
context.startActivity(intent);
```

**触发条件**：本轮激光 ON 的零点任务 `finalizeTaskLocked` 判定 `!isWithinPositionTolerance(meanOffsetX, meanOffsetY)`（与是否已写 0090H 无关，写后仍提示人工复核）。任务全失败（0 有效样本）**不**弹零点偏移窗。

**Scope**：同 `ProductionWeldAlertScope`（Quick/Engineer + 连续焊/点焊）。

### 5. 优先级与互斥

关光瞬间若脏污与零点 pending 同时存在：**先弹重度脏污窗**，确认后再弹零点窗（队列）；或合并为一次——**本期采用队列**，避免叠窗。

### 6. 去重

- 脏污：同 boot 内用户确认后 `dialogAcknowledgedThisBoot`；同等级 12s 内不重复记 pending。
- 零点：同一次激光 ON 任务最多记一次 pending；关光弹一次，确认后清除。

## Risks / Trade-offs

- **[Risk] 改 RKNN 触发沿影响已上线习惯** → 与 lens_det 统一为关光后弹，需全量回归 RKNN 路径。
- **[Risk] 关光时 Activity 不可见** → pending 保留至下一关光且 TopActivity 为 Quick/Engineer 时再弹。
- **[Risk] 自动写 0090H 后仍弹零点窗** → 操作员可能困惑；正文强调「请及时校正」引导进设置复核。

## Migration Plan

1. 改 `LensHeavyContaminationAlarmController` 下降沿 + 忽略 level 1。
2. 接 lens_det publisher + zero_point pending + 双按钮窗。
3. `make sync` 验收：出光中无窗；关光后脏污/零点各测一次；CNC 无窗。

## Open Questions

- 重度脏污关光弹窗是否仍保留「点击确认可继续出光」第二段？**建议删除**（已关光）。
