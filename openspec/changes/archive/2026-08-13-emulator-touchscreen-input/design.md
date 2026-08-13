## Context

P3.2 模拟器（`make emulator` / `scripts/run-emulator.sh`）在 `virt` machine 上启动与真机相同的 `Image` + rootfs + `sim_virt` OEM。变更前输入栈为 `virtio-keyboard-pci` + **`virtio-tablet-pci`**：host 鼠标产生绝对坐标 **pointer** 事件（`EV_ABS` + `BTN_LEFT`），Weston/flutter-elinux 走鼠标/光标路径。

真机 ynh960 使用 Goodix 电容屏（`INPUT_MT_DIRECT` / `BTN_TOUCH`），HMI 为 **touch-only**（无可见光标）。Android Emulator 在窗口内将 host 鼠标映射为 **单点触摸**，便于在桌面开发机上验证触摸 UX。

**Bring-up 发现：** Homebrew **qemu-virgl + cocoa** 只把指针事件交给 **绝对坐标设备**（tablet）；**不会**把 host 鼠标送到 `virtio-multitouch-pci`。因此不能靠单独换 multitouch PCI 设备达到目标。

## Goals / Non-Goals

**Goals:**

- 默认 `make emulator` 下，host 鼠标点击/拖动在 guest 内表现为 **单点触摸**（down/move/up）。
- Host 滚轮 / 触控板双指滚动在 guest 内为 **平滑滚轮事件**（非卡顿的 touch-flick）。
- **无需 mouse grab**（host 光标可自由移出 QEMU 窗口）；macOS/Linux display 使用 `show-cursor=on`，避免 tablet 模式下 Host 指针被藏。
- Guest HMI 默认 **不显示软件光标**（与 touch-only 真机一致）；USB 外接鼠标 passthrough 时仍可显示光标。
- 更新规格与文档，使「Android Emulator 式触摸」成为正式验收项。

**Non-Goals:**

- 多指手势仿真（pinch/zoom 等）。
- 替换真机 Goodix 驱动或 DT。
- 修改 App 内触摸业务逻辑（依赖现有 libinput → flutter-elinux 触摸栈）。
- 触摸屏压感、palm rejection、校准 UI。

## Decisions

### D1 — Host：`virtio-tablet-pci` + Guest：`emulator-tablet-to-touch`（uinput）

**Choice（最终）：**

| 层 | 默认 `EMULATOR_INPUT=touch` |
|----|------------------------------|
| QEMU | 仍挂 `-device virtio-tablet-pci`（cocoa 唯一可靠指针源） |
| Guest | `emulator-tablet-to-touch`：**EVIOCGRAB** tablet → **LWS Emulator Touch**（MT/BTN_TOUCH）+ **LWS Emulator Wheel**（`REL_WHEEL` 透传） |
| 启动 | cmdline `lws.emulator.input=touch`；systemd `emulator-tablet-to-touch.service`（`ConditionKernelCommandLine=lws.emulator=1`） |
| `EMULATOR_INPUT=tablet` | 同挂 tablet，但 cmdline `lws.emulator.input=tablet`，桥进程直接 exit 0，恢复绝对指针调试 |

**Rationale:** 与 Android Emulator「UI 层把鼠标变成触摸」同构：host 仍发 tablet，guest 合成 touch。滚轮用独立 uinput pointer 的 `REL_WHEEL`（含 hi-res），方向跟随 host（macOS 自然滚动已在 host 侧处理）；**不要**用瞬时 touch flick（会被当成 tap，且在 0..32767 ABS 下极卡）。

**Alternatives considered:**

| Option | Outcome |
|--------|---------|
| 默认 `virtio-multitouch-pci` | **否决（bring-up）** — cocoa 不向 MTT 送指针，窗口内无有效触摸 |
| 仅文档说明「用 tablet 凑合」 | 否决 — 仍为 pointer UX，与真机不一致 |
| `usb-tablet` | 否决 — USB 开销；仍为 pointer |
| Wheel → timed touch flick | **否决（验收）** — 易成 tap、延迟大；改为 `REL_WHEEL` 透传 |

### D2 — `EMULATOR_INPUT=touch|tablet`（默认 `touch`）

**Choice:** 环境变量 + cmdline；`touch` 启桥，`tablet` 跳过桥。

**Rationale:** 低成本 escape hatch；rootfs 可同时含桥二进制与 unit，由 cmdline 决定是否运行。

### D3 — Guest / Host 光标

**Choice:**

- Guest：`weston-hmi-config.sh` 在 `lws.emulator=1` 且存在 LWS touch、无 USB pointer HID 时 `cursor-size=0`。
- Host：`-display cocoa,gl=es,show-cursor=on`（Linux：`gtk,...,show-cursor=on`），否则 touch 模式 Guest/Host 双隐指针。
- `hmi.service.d/emulator-input.conf` **仅** `After=emulator-tablet-to-touch.service`——**禁止**在 hmi drop-in 上写 `ConditionKernelCommandLine` / `Requires=`（会合并进 `hmi.service`，导致真机跳过 HMI）。

### D4 — 规格：`p32-utm-guest` → `p32-qemu-guest` + 触摸输入要求

**Choice:** Canonical spec 为 `p32-qemu-guest`；REMOVED「Absolute pointer…」+ ADDED「Touchscreen input…」（实现路径写清 tablet + guest uinput **equivalent**）。

### D5 — Kernel / rootfs

**Choice:** `overlay/kernel/rockchip/emulator-virtio.config` 增加 **`CONFIG_INPUT_UINPUT=y`**（桥依赖）。`CONFIG_VIRTIO_INPUT=y` 已有。预置 `make build-libexec-binaries TOOL=emulator-tablet-to-touch` → overlay libexec + preset enable unit。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| cocoa 不驱动 multitouch | 默认保留 tablet + guest 桥（D1） |
| 滚轮变点击 / 卡顿 | 禁止 flick；`REL_WHEEL` 透传 + 独立 wheel uinput |
| 真机误启桥或 Conditional 污染 hmi | unit 上 `ConditionKernelCommandLine=lws.emulator=1`；hmi drop-in 不加 Condition/Requires |
| Host 指针消失 | display `show-cursor=on` |
| USB 鼠标 + touch 双输入 | USB 为次要；有 USB pointer 时恢复 Guest 光标 |

## Migration Plan

1. Launcher：`build_input_args` + cmdline + `show-cursor=on`。
2. Guest：桥二进制、systemd unit、preset、weston 光标策略、uinput fragment。
3. Smoke：`libinput` 见 **LWS Emulator Touch**；点按/拖动/滚轮；`EMULATOR_INPUT=tablet` 回退。
4. 文档 / OEM `touch_notes`；归档 OpenSpec。

**Rollback:** `EMULATOR_INPUT=tablet make emulator`；或停用桥 unit / 恢复旧 launcher。

## Open Questions

（无 — bring-up 已关闭 multitouch 绑定与 flick 滚轮问题。）
