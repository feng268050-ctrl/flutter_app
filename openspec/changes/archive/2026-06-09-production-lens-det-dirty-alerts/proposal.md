## Why

`lens_det` 已在快速模式/工程师模式的产线 PR1 路径（`LensDetDetectCoordinator`）按 2000ms 采样运行，但检测到脏污后**仅打日志**，操作员在焊接界面看不到告警。`zero_point` 激光 ON 后会自动写 0090H，但偏移超限时**无**面向操作员的产线提示。产品要求：在**连续焊**与**点焊**中，**仅重度脏污（level >= 2）**与**零点偏移需校正**两类提醒，且**均在激光停止（关光）后**再弹窗，避免出光过程中打断作业。

## What Changes

- **镜片脏污（仅重度）**：`lens_det` 或 RKNN 产线路径检出 `level >= 2` 时，记录 pending；**激光由开→关**后在 Quick/Engineer 连续焊/点焊界面弹出重度脏污窗（复用 `WarnDialog` 文案：`安全警报` + `镜片重度污染，立即清洗/更换`）。**不**展示轻度（`level == 1`）弹窗；`level == 1` 事件在产线焊接范围**忽略**。
- **零点偏移**：激光 ON 期间零点任务检测到偏移超出容差（与现 `ZeroPointCorrectionMapper` 一致）时记录 pending；**激光停止后**弹窗，正文 **「零点偏移中心请及时校正」**，**确认**关闭；**跳转**打开 `DeviceSettingActivity` 高级设置 Tab（零点校正入口）。自动写 0090H 逻辑可保留（design 定是否仍静默写入后再提示复核）。
- **统一触发时机**：两类弹窗 **MUST NOT** 在 `isLaserOn == true` 时弹出；仅在激光下降沿（或关光后且 Activity 可交互时）展示。
- **作用域**：仅 Quick Mode、Engineer Mode 的 `CONTINUOUS_WELDING`、`POINT_WELDING`；`ENABLE_LENS_DET_APP=false` 时 lens_det 路径不变。
- **不做**：轻度污染弹窗；AI Vision 预览阻断弹窗；修改 native 算法。

## Capabilities

### New Capabilities

- `production-lens-det-dirty-alerts`: 产线仅重度脏污、激光停止后弹窗。
- `production-zero-point-offset-alerts`: 产线零点偏移、激光停止后双按钮弹窗（确认 + 跳转设置）。

### Modified Capabilities

- `lens-det-app-inference`: 产线 lens_det Layer 5 发布重度事件 + 激光停止展示。
- `ai-vision-lens-dirty-alerts`: 产线仅 level >= 2；预览路径仍无阻断弹窗。
- `zero-point-detect-on-laser-on`: 增加产线偏移 pending 与激光停止后提示（不改变采样调度契约）。

## Impact

- **Java**: `LensHeavyContaminationAlarmController`（触发改为激光下降沿）、`LensDetDetectCoordinator`、新 `ZeroPointOffsetAlertCoordinator`（或并入 `ZeroPointDetectCoordinator`）、`ProductionWeldAlertScope`、双按钮对话框（`AlertDialog` 或扩展 `WarnDialogVo`）、`DeviceSettingActivity` 跳转。
- **strings**: `zero_point_offset_alert_body`（零点偏移中心请及时校正）、`zero_point_offset_alert_go_settings`（跳转设置）。
- **测试**: 激光 ON 期间不弹窗；关光后弹窗；CNC 模式不弹。
