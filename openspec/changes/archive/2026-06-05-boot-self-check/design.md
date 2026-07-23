## Context

HMI App 由 Android 开发板开机自动拉起，操作员首屏为 `MainActivity`（首页）。应用启动时 `LaserApplication` 已打开 Modbus 串口并注册设备状态/数据轮询任务（`DeviceStatusTaskHandler`），轮询回调会通过 `DeviceDialogHandler.checkDeviceStatus` 弹出告警。首页 `initView` 当前会立即启动 `CameraCommunicationMonitor`（1 Hz ICMP ping + `CameraCommunicationAlarmController` C002 监听）。

Monitor → Alarm Information 左侧面板已定义 Modbus 可检测项（通讯状态、温度类告警）与摄像头 ping 健康（`CameraCommStatus`）。开机阶段这些异步通路会在自检完成前各自触发，缺乏统一、可读的启动期结论。

约束：不改造系统级开机拉起逻辑；仅编排 App 进入首页后的行为。与现有启动弹窗（WiFi 引导、固件升级提示、设备绑定检查）共存，自检弹窗优先级低于安全/联网阻断类弹窗，但应尽早展示。

## Goals / Non-Goals

**Goals:**

- 首页首次进入时触发**每进程一次**同步开机自检，弹窗逐项追加检测名称与状态。
- 自检项与 Alarm Information 左侧面板 Modbus 检测语义对齐，并包含摄像头 ICMP 连通检测。
- 自检期间抑制异步告警通路（Modbus 弹窗、摄像头周期 ping 与 C002 弹窗）。
- 自检结束后自动关闭弹窗并恢复 `CameraCommunicationMonitor` 与 `DeviceDialogHandler` 正常行为。
- 提供可单元测试的编排器与抑制闸门，不阻塞主线程 UI。

**Non-Goals:**

- 不修改 Modbus 轮询频率、寄存器协议或 Alarm Information 页面 UI。
- 不自检失败时阻断首页操作（仅展示结果；恢复异步后按既有规则告警）。
- 不将自检结果持久化到数据库或上报云端。
- 不处理 App 进程被杀后再次冷启动以外的重复自检（同进程内仅一次；用户离开首页再返回不重复）。

## Decisions

1. **编排入口：`MainActivity.initView` 触发 `BootSelfCheckCoordinator`**
   - Rationale：与 `CameraCommunicationMonitor.startWhenHomeEntered` 同层，保证有前台 Activity 承载弹窗；`initView` 在首页布局完成后调用，满足「进入首页后」语义。
   - Alternative：`onResume` 触发；易与其他启动弹窗（固件、绑定）重复竞争，且每次 resume 需额外幂等守卫。

2. **检测流水线：后台线程串行执行，主线程更新弹窗**
   - 先追加「检测中」，完成后再更新为「正常/异常」。
   - Modbus 项通过 `ModbusManagerRtu` 同步 `readInputRegisters`（`createDeviceStatus` / `createDeviceData`）获取快照，再按 `WarnInfoFragment` / `fragment_warn_info.xml` 同等表达式判定每项。
   - 摄像头项复用 `CameraUtils.checkCameraBlocking()`（bounded ping，不发起 HTTP deviceinfo）。
   - Alternative：等待异步轮询缓存就绪再读；缺点是启动期时序不确定、无法保证同步顺序展示。

3. **异步抑制：`BootSelfCheckGate` 进程级闸门**
   - 自检开始 `BootSelfCheckGate.setActive(true)`；`DeviceDialogHandler.checkDeviceStatus` / `showCameraCommunicationDialog` 在 gate active 时 no-op。
   - `MainActivity.initView` **不再**直接调用 `CameraCommunicationMonitor.startWhenHomeEntered`；改为自检 `onComplete` 回调中调用。
   - Modbus 轮询任务保持运行（填充缓存供后续 UI），仅抑制弹窗。
   - Alternative：暂停 `RxTaskManager` 全部任务；影响面过大且拖慢缓存预热。

4. **弹窗 UI：不可取消的列表式进度对话框**
   - 复用项目现有 Dialog 风格（与 WiFi 引导/告警弹窗一致的深色 HMI 皮肤）。
   - 标题 + `RecyclerView`/`LinearLayout` 动态追加行：项目名称、状态图标/文案（检测中、正常、异常）。
   - 无手动关闭按钮；全部项完成后延迟约 500ms 自动 dismiss（便于操作员扫一眼汇总）。
   - Alternative：`ProgressDialog` 单条进度；无法展示逐项结论，不符合需求。

5. **检测项清单（固定顺序）**

   | 顺序 | 分组 | 检测项 | 判定依据 |
   |------|------|--------|----------|
   | 1 | 下位机 | 控制器通讯 | 同步读取 `DeviceStatus` 且 `deviceType > 0` |
   | 2 | 激光设备 | 泵通讯状态 | `!deviceStatus.isLaserCommunicationAlarm`（需 statusReady） |
   | 3 | 焊枪 | 枪头通讯 | `!deviceStatus.isGunCommunicationAlarm` |
   | 4 | 焊枪 | 电机驱动板温度 | `alarmMetric` 规则：`statusReady && dataReady && hasValue && !isDriverTemperatureAlarm` |
   | 5 | 焊枪 | 电机温度 | 同上，`isGunMotorOverTemperatureAlarm` |
   | 6 | 焊枪 | 保护镜温度 | 同上，`isProtectionBoardTemperatureAlarm` |
   | 7 | 焊枪 | 聚焦镜温度 | 同上，`isStraightTrackTemperatureAlarm` |
   | 8 | 送丝机 | 送丝机通讯 | `!deviceStatus.isWireFeederCommunicationAlarm` |
   | 9 | 摄像头 | 摄像头通讯 | `CameraUtils.checkCameraBlocking()` 返回 true |

   - 控制器通讯失败时，后续 Modbus 依赖项标记为「跳过/异常」并继续摄像头项（避免长时间阻塞）。
   - 字符串键复用 Alarm Information 已有 `@string/...` 资源。

6. **幂等：进程内 `BootSelfCheckCoordinator.completed` 标志**
   - 同进程第二次进入 `MainActivity` 不再弹自检，直接 `CameraCommunicationMonitor.startWhenHomeEntered`。
   - Alternative：每次冷启动都自检；符合开机场景，但需明确「进程存活 = 非开机」产品语义——采用进程内一次。

## Risks / Trade-offs

- **[Risk] 自检与 WiFi/固件/绑定弹窗同时出现]** → Mitigation：自检弹窗不阻断底层交互但 z-order 低于强制引导；若 WiFi 引导正在显示，延后到 `evaluateWifiInitializationPrompt` 完成后再启动自检（通过 MainActivity 启动编排回调串联）。
- **[Risk] Modbus 串口尚未连接导致首项超时]** → Mitigation：每项 bounded timeout（如 3s）；超时记为异常并继续流水线。
- **[Risk] 自检期间真实故障被延迟告警]** → Mitigation：Acceptable by design；自检弹窗已展示结论，完成后立即恢复异步通路。
- **[Risk] 同步 Modbus 读与轮询任务争用串口]** → Mitigation：复用 `ModbusManagerRtu` 既有队列；自检读入队后等待完成，不绕过任务队列。
- **[Trade-off] 温度项在 data 未就绪时标为异常而非跳过]** → Mitigation：与 Alarm Information readiness 一致，无有效数据视为未通过。

## Migration Plan

1. 新增 `BootSelfCheckGate`、`BootSelfCheckCoordinator`、`BootSelfCheckDialog` 与检测项枚举/判定器。
2. 调整 `MainActivity.initView`：移除即时 `CameraCommunicationMonitor` 启动，改调自检编排。
3. `DeviceDialogHandler` 增加 gate 判断；`CameraCommunicationMonitor` 仅在自检完成后启动。
4. 补充字符串资源（弹窗标题、状态：检测中/正常/异常/跳过）。
5. 单元测试：gate 抑制、项顺序、完成后恢复 monitor、幂等。
6. 回滚：移除 `MainActivity` 自检调用并恢复 `initView` 内直接 `CameraCommunicationMonitor.startWhenHomeEntered`。

## Open Questions

- WiFi 引导弹窗显示时，自检是否应等待用户关闭 WiFi 弹窗后再开始？（当前设计：等待 WiFi onboarding 完成事件。）
- 全部正常时是否仍需 500ms 延迟关闭，还是立即关闭？
- 模拟器上是否跳过自检或全部标为中性（与 `alarm-comm-status-platform-display`  emulator 规则对齐）？
