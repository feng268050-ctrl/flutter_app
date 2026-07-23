# 焊接实时监视浮层（方案 A）设计

将工程师模式与快速模式在 **Laser Enable ON + 枪头开关 ON** 时弹出的「机台实时状态」浮层，统一改为 **本地 RTSP 预览 + AI 检测框叠层 + 侧栏机台仪表**，对齐手机 App Monitor 的「画面 + 检测数据 + DetectionOverlay」体验。快速模式另保留既有「更多监测」手动入口（同一套 body）。

**相关文档**

- 检测管线：[`Native Stream Detection Pipeline.md`](Native%20Stream%20Detection%20Pipeline.md)
- 本机 HTTP / SSE（手机消费端）：[`network-api-reference.md`](network-api-reference.md)（`/v1/monitor/stat`、`/v1/camera/ai`）
- AI Vision 预览叠层参考：`AiVisionFragment` + `DetectionOverlayView`

**设计日期**：2026-07-22  
**修订**：

- 2026-07-22 — 快速模式增加与工程师相同的枪头自动弹  
- 2026-07-22 — **保留**「更多监测」按钮与手动进入；**CNC 不计入本改动**

**状态**：已实现（OpenSpec `add-laser-live-monitor-overlay`）

---

## 1. 目标与非目标

### 1.1 目标

1. **工程师模式**：Laser Enable 已开且枪头开关 ON 时弹出的浮层，从纯仪表改为实时画面 + 检测框 + 机台状态侧栏（**开闭时机保持现有**）。
2. **快速模式（焊接通用操作页）**：
   - **枪头自动弹**：与工程师同一触发语义（Laser Enable ON + 枪头 ON 开；枪头 OFF / End of work 关）。
   - **「更多监测」保留**：设备 Logo / More Monitor 按钮与手动打开浮层的入口保留；打开的是 **同一套** Live Monitor body（可继续带确认条关闭）。
3. 两端枪头路径共用 `WorkStatusDialogBuilder` + 同一 Fragment body，避免两套监视 UI。
4. 检测结果来自现有 `StreamDetectPipeline` 发布总线；浮层只订阅并绘制，不另起检测解码。
5. 交互语义对齐手机 Monitor：视频为主，检测框叠在画面上，机台关键量可并存。

### 1.2 非目标

- **CNC Cut（及 CNC 相关页）不计入本改动**：不新增枪头监视浮层，不改 CNC 状态/连接 UI。
- 不改 Laser Enable / End of work 的 Modbus 流程与告警门禁。
- 不在浮层内再订阅 `http://127.0.0.1:5580/v1/monitor/stat` 或 `/v1/camera/ai`（本机用 `MemoryCache` + `StreamDetectResultBus`）。
- 不把完整 `AiVisionFragment`（选视频、离线推理、捏合教程等）搬进浮层。
- 不在本方案内重做告警列表 SSE UI（可后续迭代）。
- 不强制改 Monitor Tab「机台状态」全屏页布局。

---

## 2. 现状基线

### 2.1 工程师模式（已有枪头自动弹）

```
Laser Enable ON（长按确认 → Modbus）
  → LaserEnableStateHolder
  → LivePr1InferenceStreamCoordinator
  → NativeStreamDetectCoordinator 启停 C++ 检测（无 UI）

DEVICE_STATUS_KEY 变化且 isOpenLaser
  → EngineerModeActivity.openWorkStatusDialog
       gun ON  → WorkStatusDialogBuilder.createShowNoButtonDialog()
                 → MachineStatusOverlay.show(ctx, showConfirm=false)
       gun OFF → scheduleCloseOnGunOff() / closeDialogDelayMillis
```

浮层标题：`real_time_machine_status_text`（机台实时状态）。  
Body：`machine_status_overlay_body` → `#work_status_content` → `MachineStatusDialogFragment`（仅仪表）。

### 2.2 快速模式（现状）

```
Laser Enable ON → LivePr1InferenceStreamCoordinator（检测管线会跑）

GeneralOperationsFragment.onCacheChanged(DEVICE_STATUS)
  → deviceStatusListen()
       → 作业门禁 / 告警关光 / SafetyGroundLockPrompt
       → ❌ 没有 openWorkStatusDialog / 枪头边沿弹窗

激光进度条设备 Logo 点击
  → MachineStatusOverlay.show(ctx, showConfirm=true)   // 「更多监测」— 保留
```

- 已有状态监听与使能门禁，**缺**与工程师对称的枪头开闭浮层。
- 「更多监测」手动入口 **保留**，body 随本方案升级为 Live Monitor。

### 2.3 缺口

| 能力 | 工程师现状 | 快速现状 | 目标 |
|------|------------|----------|------|
| 枪头自动弹浮层 | ✅ | ❌ | ✅ 焊接通用页一致 |
| 实时画面 + AI 框 | ❌（仅仪表） | ❌ | ✅ |
| 手动「更多监测」 | （工程师无） | ✅ Logo 点击 | ✅ **保留**，body 升级 |
| CNC | — | 独立子页 | **不改** |

---

## 3. 方案 A 锁定决策

| 项 | 决策 |
|----|------|
| 枪头触发（工程师 + 快速焊接页） | **Laser Enable ON + 枪头 `isGunSwitchOn` 上升沿** → 开；下降沿 → debounce 后关；End of work → 关 |
| 枪头开闭 API | **共用** `WorkStatusDialogBuilder`（`createShowNoButtonDialog` / `scheduleCloseOnGunOff` / `closeDialogDelayMillis`） |
| 枪头浮层形态 | `MachineStatusOverlay.show(ctx, showConfirm=false)` — 无确认条，靠枪头/关使能关闭 |
| 「更多监测」 | **保留**按钮与入口；`MachineStatusOverlay.show(ctx, showConfirm=true)` — 有确认条，手动关；**同一** Live Monitor Fragment |
| Body | `#work_status_content` → **`LaserLiveMonitorOverlayFragment`** |
| 视频 | 本机 MediaMTX **PR1**：`MediaMtxRelayUrls.localPr1()` |
| 框层 | `DetectionOverlayView` |
| 检测订阅 | 订 `StreamDetectResultBus`（推荐）或扩 `StreamDetectOverlayBridge`；**不** start/stop 管线 |
| 仪表 | **保留**侧栏/底栏紧凑区 |
| 快速枪头增量 | `GeneralOperationsFragment.deviceStatusListen` 补齐 `openWorkStatusDialog` 同语义 |
| CNC | **明确排除**；不接 `WorkStatusDialogBuilder`、不改 CNC UI |

**入口并存时注意**：若枪头自动浮层已显示，再点「更多监测」应复用已显示 Handle（现 `MachineStatusOverlay` 单例行为），或忽略二次 show；枪头关闭路径不要误关用户刚手动打开且需确认条的实例——实现上建议：

- 枪头路径只管理 `WorkStatusDialogBuilder` 持有的无确认条实例；
- 「更多监测」走 `show(..., true)`；若当前已是枪头自动浮层在显示，直接 return 已有 Handle（与现 `sActiveHandle` 逻辑一致）。

---

## 4. 目标触发流

### 4.1 枪头自动（工程师 = 快速焊接页）

```
Laser Enable ON
  → 检测管线按现规则运行

DEVICE_STATUS_KEY 且 isOpenLaser
  → 边沿检测 lastIsGunSwitchOn vs deviceStatus.isGunSwitchOn()
       gun ON  → WorkStatusDialogBuilder.createShowNoButtonDialog(ctx)
                 → MachineStatusOverlay.show(ctx, false)
                      → LaserLiveMonitorOverlayFragment
       gun OFF → WorkStatusDialogBuilder.scheduleCloseOnGunOff(ctx)

End of work / Activity destroy
  → closeDialogDelayMillis / clearInstance
```

### 4.2 「更多监测」（仅快速，保留）

```
Logo / More Monitor 点击
  → MachineStatusOverlay.show(ctx, true)   // 确认条保留
       → 同一 LaserLiveMonitorOverlayFragment
  → 用户点「我知道了」关闭
```

- Laser Enable OFF 时仍可手动打开：可见画面 + 仪表；框可能为空（可接受）。
- Laser Enable ON 且管线有结果时，手动打开同样可画框。

---

## 5. 目标 UI 结构

```
FrostDialog（标题；枪头路径无确认条 / 更多监测有确认条）
└─ body
   └─ #work_status_content
      └─ LaserLiveMonitorOverlayFragment
         ┌──────────────────────────────────────────────────┐
         │  ┌─────────────────────────┐  ┌───────────────┐  │
         │  │ TextureView (PR1)       │  │ 侧栏仪表区    │  │
         │  │ DetectionOverlayView    │  │ 气压 / 电流   │  │
         │  │ （可选 HUD status 行）   │  │ 机台位灯等    │  │
         │  └─────────────────────────┘  └───────────────┘  │
         └──────────────────────────────────────────────────┘
```

布局原则：

- 视频区占主导；侧栏复用现有 gauge / tile 或抽公共 include。
- 枪头路径与「更多监测」**内容 Fragment 相同**；仅 `showConfirmButton` 不同。
- 对话框尺寸按视频区加大，避免裁切 TextureView。

---

## 6. 数据流

```
                    ┌─ MemoryCache DEVICE_STATUS / DEVICE_DATA
                    │     → 侧栏仪表
Laser Enable ON ────┼─ NativeStreamDetectCoordinator
                    │     → StreamDetectPipeline
                    │     → StreamDetectResultBus
                    │           → Fragment listener
                    │                 → DetectionOverlayView.setBoxes
                    └─（可选）CameraAiOverlayState → HUD

Fragment show
  → EasyPlayerClient 播 localPr1()
Fragment dismiss
  → 停播 + removeListener
  （管线仍由 LaserEnable 生命周期管）
```

### 6.1 空态

- 枪头自动弹：通常 Laser Enable 已开，管线在跑；短暂无结果则清框。
- 「更多监测」在 Laser OFF：画面 + 仪表可用，框为空。
- 摄像头不可用：占位文案，不阻塞关闭。

### 6.2 Bridge 门控

推荐浮层直订 `StreamDetectResultBus` + mapper；或扩展 bridge 支持焊接 live overlay。

---

## 7. 模块改动清单（建议）

| 模块 | 变更 |
|------|------|
| `res/layout/` | 新增 `fragment_laser_live_monitor_overlay.xml` |
| 新 Fragment | `LaserLiveMonitorOverlayFragment`：播流、订检测、绑仪表 |
| `MachineStatusOverlay` | attach 新 Fragment；支持 `showConfirm` true/false 两种入口 |
| `MachineStatusDialogFragment` | 浮层不再使用；可后续清理 |
| `WorkStatusDialogBuilder` | API 保持；工程师已用；**快速焊接页新接入** |
| `EngineerModeActivity` | 枪头开闭逻辑基本不变；body 升级自动生效 |
| `GeneralOperationsFragment` | **新增**枪头 `openWorkStatusDialog`；End of work / destroy 关浮层；**保留** Logo → `MachineStatusOverlay.show(..., true)` |
| `CNCCutFragment` / CNC 相关 | **不改** |
| `MachineStatusOverlayPreloader` | 适配新 layout |
| 单测 | 枪头边沿（工程师+快速焊接）；更多监测仍可开；与枪头单例不冲突 |

**建议不改**：`LivePr1InferenceStreamCoordinator`、Modbus 使能、`CameraController` 录制勾选、CNC 全链路。

---

## 8. 生命周期与资源

| 事件 | 行为 |
|------|------|
| gun ON（且 Laser Enable ON） | `createShowNoButtonDialog` → 播 PR1 + 订检测 |
| gun OFF | `scheduleCloseOnGunOff` → delay dismiss |
| 「更多监测」打开 | `show(..., true)`；确认条关闭 |
| End of work | `closeDialogDelayMillis` |
| Activity destroy | `clearInstance` + 停播 |

风险与缓解：

| 风险 | 缓解 |
|------|------|
| 与 PR0 录制争带宽 | 预览固定 PR1 |
| EasyPlayer stop ANR | 异步 stop |
| 枪头关误伤手动浮层 | 单例 Handle + Builder 只 dismiss 自己打开的实例（现网已偏此模型，实现时回归） |
| CNC 误接枪头弹窗 | 代码范围限定 `GeneralOperationsFragment`，不碰 CNC |

---

## 9. 与手机 Monitor 对齐范围

| 手机 Monitor | 本方案浮层 | 说明 |
|--------------|------------|------|
| RTSP 画面 | ✅ 本机 PR1 | |
| AI 框 + HUD | ✅ 框；HUD 可选 | 本地 bus |
| 气压 / 电流表 | ✅ 叠在画面左右 | MemoryCache；对齐手机全屏 Monitor |
| 状态标签 | ✅ 叠在画面底部一行 | |
| 温度 / Alarm Logs | 二期可选 | |
| 全屏放大 | ✅ 右上角按钮 | 占满屏并隐藏标题/确认条；再点退出 |

---

## 10. 分阶段落地

### Phase 0 — 契约确认

- 侧栏字段；标题文案；框数据源（bus vs bridge）。

### Phase 1 — Live Overlay + 快速枪头 + 保留更多监测

- layout + Fragment；`MachineStatusOverlay` 挂新 Fragment。
- 快速焊接页接入 `WorkStatusDialogBuilder`。
- **保留** Logo「更多监测」→ `show(..., true)`。
- 工程师枪头路径随 body 升级生效。
- **不改 CNC**。

### Phase 2 — 打磨

- HUD、stale、尺寸、录制并发、枪头/手动入口交互回归。

### Phase 3 — 可选增强

- 温度 / 告警列表；标题与手机统一。

---

## 11. 验收标准（首版）

**工程师与快速焊接页（枪头）**

1. Laser Enable ON → 扣枪 → 浮层自动出现，可见 PR1。  
2. 有检测结果时框叠在画面上。  
3. 侧栏仪表随状态更新。  
4. 松枪 → 延时关闭；无泄漏。  
5. End of work → 浮层关闭。

**快速「更多监测」（保留）**

1. Logo / More Monitor 仍可打开同一套 Live Monitor 浮层。  
2. 带确认条，可手动关闭。  
3. Laser OFF 时打开：画面 + 仪表可用（框可空）。

**范围**

- CNC Cut 行为与现网一致，无本方案回归要求。

**回归**

- Laser Enable 门禁、告警关光、Recording Work 不受影响。  
- Monitor / AI Vision Tab 不回归。  
- 无 EasyPlayer stop ANR。

---

## 12. 开放问题

1. 侧栏仪表字段是否与现 `fragment_machine_status_dialog` 完全一致？  
2. 检测框是否仅 `lens_det`，是否叠零点等？  
3. 标题是否改为「实时监视 / Live Monitor」？  
4. 枪头自动浮层显示中用户点「更多监测」：仅复用 Handle，是否需把确认条从无切到有？（建议首版：已显示则 no-op / 复用）

---

## 13. 总结

方案 A：共用 Live Monitor body（PR1 + `DetectionOverlayView` + 侧栏仪表）。  
**枪头自动弹**：工程师与快速焊接页对齐。  
**「更多监测」**：按钮与手动进入 **保留**，打开同一 body（带确认条）。  
**CNC**：不计入本改动。  
检测管线仍由 Laser Enable 驱动，浮层只负责播与画。
