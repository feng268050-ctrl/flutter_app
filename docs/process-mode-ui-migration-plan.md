# 快速模式与工程师模式 UI 迁移方案

**状态：进行中：U0–U4 完成；U5 激光/气体完成、送丝待协议；U6 仓内验收完成，ynh960 实机 smoke 待做。**

目标是在 Flutter/CyberUI 中迁移 `lws-ui` 的 Quick Mode 与 Engineer Mode。页面和设备业务保留在 `lws-hmi`：不向 `cyber_ui` 增加产品状态栏或产品设备状态 API。

## 1. 当前完成：U0 工作模式状态栏

`WorkModeStatusBar` 已完成并应用到 Quick/Engineer 两个页面。

| 项目 | 实现 |
|---|---|
| 应用内抽象 | `app/lws_hmi/lib/features/work_mode/presentation/work_mode_status_bar.dart` |
| 使用页面 | `QuickModePage`、`EngineerModePage` |
| 左侧 | Back 按钮，沿用 `Navigator.maybePop` |
| 中间 | Gun Switch、Ground Clamp、Key Switch、Gas Flow、E-Stop 及各自 on/off 图标 |
| 右侧 | 仅摄像头状态图标与当前时间；不显示 Wi-Fi、蓝牙或其他状态图标 |
| CyberUI 边界 | 可组合 CyberUI 的低层图标/时钟组件，但不改动 `cyber_ui` 公共 API |

此处与 `lws-ui` 的差异是右侧：旧应用显示 Wi-Fi 图标与时间；HMI 按产品要求只显示摄像头图标与时间。

### 1.1 设备状态来源

`WorkModeEquipmentStatusController` 订阅现有 HAL/Modbus 属性，仅用于展示，不执行写入：

| 指示项 | 属性 |
|---|---|
| Gun Switch | `machine.gun_switch_on` |
| Ground Clamp | `machine.safety_ground_lock` |
| Key Switch | `machine.key_switch_on` |
| Gas Flow | `machine.air_valve_on` |
| E-Stop | `machine.emergency_stop` |

状态栏图标资源与状态模型位于 `features/work_mode/domain/`。摄像头状态使用 `IpCameraUiStatus`；时间由状态栏时钟按分钟更新。已有 `work_mode_status_bar_test.dart` 和 `work_mode_equipment_status_test.dart` 覆盖 UI 与状态映射。

### 1.2 U0 验收

- [x] `WorkModeStatusBar` 在 `app/lws_hmi/`，不属于 `cyber_ui`。
- [x] Quick 与 Engineer 路由均使用它。
- [x] 中间显示五个设备指标及图标。
- [x] 右侧严格只显示摄像头与时间。
- [x] U0 阶段 body 留白，没有工艺库筛选、参数编辑、设备控制或 Modbus 写入（U2 起仅加视觉骨架）。

## 1.3 U1：数据前置（已完成）

quick → `engineer_preset` 中位数派生已在工艺库切片落地（见 `docs/process-library-migration-plan.md` §2.1 / §7.3）：

| 项目 | 实现 |
|---|---|
| 派生器 | `EngineerPresetDeriver` |
| 导入接线 | `ProcessLibraryImporter`（同版本缺 engineer 行时 backfill） |
| 测试 | `engineer_preset_deriver_test.dart`、仓库导入集成断言 |

## 1.4 U2：视觉骨架（已完成）

1280×800 模式壳 + Quick 轮盘 + Engineer Tab + 资源/颜色 token；**mock 选择状态**，不读工艺库、不写 Modbus。

| 项目 | 实现 |
|---|---|
| Token / 标签 | `features/process_mode/domain/process_mode_tokens.dart` |
| 资源常量 | `features/process_mode/domain/process_mode_assets.dart` |
| 资源目录 | `app/lws_hmi/assets/process/`（来自 lws-ui `mipmap-xxxhdpi`） |
| Quick 轮盘 | `QuickModeProcessWheel`（六工艺类型 + 选中高亮带） |
| Engineer Tab | `EngineerProcessTabBar`（**五** Tab，对齐 lws-ui；CNC 仅在 Quick） |
| 页面 | `QuickModePage` / `EngineerModePage` 接入骨架 |
| 测试 | `process_mode_skeleton_test.dart` |

说明：方案表曾写「工程师六 Tab」；Android `engineer_tab.xml` 实际为五格（无 CNC）。HMI 跟随真机五 Tab。

## 1.5 U3：快速模式内部 UI（已完成；布局已对齐仪表盘构图）

材料 / 档位 / 厚度或摆宽选择、会话 inherit/fallback、**中心激光仪表盘**、跳转工程师草稿；匹配行经 `ProcessParameterApplier`（300ms debounce）下发。

| 项目 | 实现 |
|---|---|
| Carry / Resolver | `quick_mode_selection_carry.dart`、`quick_mode_selection_resolver.dart`（对齐 lws-ui） |
| 选择编排 | `quick_mode_selection.dart`（`QuickModeSelectionBuilder`） |
| 材料轮盘 | `QuickModeMaterialWheel` |
| 档位 / 厚度·摆宽 | `QuickModeGearPick` / `QuickModeDimensionPick`（相对仪表盘 -150 重叠 + 60/-8 微调） |
| 中心仪表盘 | `QuickModeLaserDashboard`（气压 + More Status） |
| More Parameters | → `EngineerModePage(initialProcessType, initialPresetUuid)` |
| CNC | 隐藏选择器与 More Parameters |
| 测试 | `quick_mode_selection_resolver_test.dart`、`quick_mode_page_test.dart` |

## 1.6 U4：工程师内部 UI（已完成；左右分栏已对齐）

左 460dp 设备控制面板 + 右参数卡片；参数值胶囊可点（内置点按即解锁为内存草稿）。

| 项目 | 实现 |
|---|---|
| Draft | `EngineerModeDraft`（Quick 交接为内存草稿，不立刻写库） |
| 字段可见性 | `EngineerParameterVisibility`（按工艺类型过滤 catalog keys） |
| 左栏 | `EngineerDevicePanel`（Manual Gas / Wire stub / Enable Laser） |
| 表单 | `EngineerParameterForm`（可点 value pill + CyberIME） |
| 收藏列表 | `showEngineerFavoritesPopup` |
| 操作 | Copy / Save / Delete / Reset / Apply |
| 内置编辑 | 点参数值 → 内存 user 草稿；Save 才落库 |
| 测试 | `engineer_mode_draft_test.dart`、`engineer_mode_page_test.dart` |

## 1.7 U5：设备控制（部分完成）

Flutter 优先：`CustomClipper` / `CustomPainter` 复刻 Android 梯形激光按钮及可逆径向 ripple；关闭态按住蓄满后松开确认，开启态短按结束工作。

| 项目 | 实现 |
|---|---|
| 控制器 | `DeviceControlController`（exclusiveSession 写 `control.laser_enable` / `control.manual_gas`；开关激光前清 `control.wire_work`） |
| 预检 | `LaserEnablePreflight`（E-Stop / 钥匙开关 / 告警策略） |
| UI | Quick：`QuickModeDeviceControls` + 564×223 `QuickModeLaserButton`；Engineer：`EngineerDevicePanel`；CNC 隐藏 |
| 开启顺序 | 长按预检 → 安全确认 → 重发当前工艺 → 重发高级设置 → Modbus 激光使能 |
| 互斥 | 开气先关激光；激光开时禁用开气 |
| 送丝 | Quick 连续焊：自动送丝开关；Feed 短按 500ms 脉冲、长按 3s 进入持续并再点停止；Retract 短按脉冲、长按仅按住运行 |
| 曲线/录像 | 本轮不做 |
| 测试 | `laser_enable_preflight_test.dart`、`device_control_test.dart`、`quick_mode_laser_button_test.dart`、`process_mode_acceptance_test.dart` |

### 送丝实机确认项

1. 确认 bit RMW 脉冲在 ynh960 上不会覆盖来自枪头的控制字更新。
2. 确认脉冲关断 500ms、长按开始 500ms、连续闩锁 3000ms。
3. `control.wire_manual_mode`（bit4）沿用 lws-ui 的 `autoWireFeedEnable` 写入语义；需实机确认 HAL 标注是否应更名。

## 2. 后续 UI 范围

| 切片 | 状态 | 交付 |
|---|---|---|
| U0：工作模式状态栏 | [x] | 本文 §1 |
| U1：数据前置 | [x] | quick → `engineer_preset` 中位数派生与测试 |
| U2：视觉骨架 | [x] | 1280×800 模式壳、快速模式轮盘、工程师五 Tab、资源/颜色 token |
| U3：快速模式内部 UI | [x] | 材料/档位/厚度或摆宽、继承/fallback、预览、工程师草稿跳转 |
| U4：工程师内部 UI | [x] | 内置/用户预设、catalog 表单、CyberIME、复制/保存/删除/应用 |
| U5：设备控制 | [~] | 激光/气体已落地；送丝待协议确认；曲线/录像不做 |
| U6：验收 | [~] | 仓内 widget/Modbus 模拟完成；像素 golden 不做；ynh960 smoke 见 §1.8 |

推荐顺序：在 ynh960 跑 §1.8 smoke；确认送丝协议后补齐 U5 送丝。

## 1.8 U6：验收（仓内完成；实机待做）

| 项目 | 实现 |
|---|---|
| LaserWorkGuard | `laser_work_guard_test.dart`（`isProcessChangeSafe` fail-closed；无告警时 interrupt 不写） |
| 页面 + Modbus 模拟 | `process_mode_acceptance_test.dart`（DeviceControlBar / CNC 隐藏；Quick debounce apply；Guard 阻断文案；Engineer Apply 写入） |
| HAL 抽样 | `gpio_modbus_golden_test.dart` 增补 `control.manual_gas`、`machine.wire_feeding_on` |
| 像素 golden | **不做**（与现有仓库约定一致；用 ValueKey + 1280×800 widget 断言） |

### ynh960 实机 smoke（手动）

- [ ] Quick / Engineer 布局与状态栏（五设备 + 摄像头/时间）
- [ ] Quick 选材/档/厚 → 参数下发与读回
- [ ] Engineer Apply / Copy / Save
- [ ] Manual Gas 与 Hold-to-Enable Laser 互斥；E-Stop / 钥匙开关拦截
- [ ] CNC 隐藏选择器与设备控制栏
- [ ] （协议确认后）送丝/回抽

## 3. 后续内部 UI 约束

- 快速模式复刻 `lws-ui` 的模式、材料、档位、厚度/摆宽选择；模式切换优先继承会话选择，失效时回退到第一个有效组合。
- 工程师模式复刻五个工艺类型 Tab（与 lws-ui 一致；CNC 不在工程师顶栏）；内置 `engineer_preset` 只读，编辑时先复制成 `user` 工艺。
- 参数表单由 `ProcessParameterCatalog` 驱动，不能在 widget 中复制 Modbus 地址或缩放规则。
- 所有参数应用仅经 `ProcessParameterApplier`；应用前通过 `LaserWorkGuard.isProcessChangeSafe`，成功后必须读回确认。
- CNC 连接/运行覆盖层、录像、云同步不属于本轮内部 UI 迁移。

## 4. 资源与验证

迁移 Android 视觉时，优先使用 `lws-ui` 的最高质量图标资源；纯色、渐变、边框与分割线优先由 CyberUI/Flutter 绘制。新资源归入 `app/lws_hmi/assets/process/`，并在代码中以工艺类型颜色 token 使用。

后续每个切片均须包含对应 Dart/widget 测试。U5 之后在 ynh960 验证设备状态、互锁、写入与读回。

## 5. 构建

本次改动了 `app/lws_hmi/**`，验证或部署时执行：

```text
make build-app
make push-app
```
