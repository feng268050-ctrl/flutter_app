## Context

P3.2 模拟器（`make emulator` / `scripts/run-emulator.sh`）在 `virt` machine 上启动与真机相同的 `Image` + rootfs + `sim_virt` OEM。当前输入栈为 `virtio-keyboard-pci` + **`virtio-tablet-pci`**：host 鼠标产生绝对坐标 pointer 事件（`EV_ABS` + `BTN_LEFT`），Weston/flutter-elinux 走 **鼠标/光标** 路径。

真机 ynh960 使用 Goodix 电容屏（`INPUT_MT_DIRECT` / `BTN_TOUCH`），HMI 为 **touch-only**（无可见光标）。Android Emulator 同样在窗口内将 host 鼠标映射为 **单点触摸**，便于在桌面开发机上验证触摸 UX。

内核 fragment `overlay/kernel/rockchip/emulator-virtio.config` 已启用 `CONFIG_VIRTIO_INPUT=y`。QEMU（qemu-virgl）提供 **`virtio-multitouch-pci`**，可将 display backend 的 pointer 事件转为 guest multitouch 协议。

## Goals / Non-Goals

**Goals:**

- 默认 `make emulator` 使用 **virtio multitouch** 作为主显示输入，host 鼠标点击/拖动在 guest 内表现为 **单点触摸**（down/move/up）。
- 保持 **无需 mouse grab**（host 光标可自由移出 QEMU 窗口，与现有 tablet 行为一致）。
- Guest HMI 默认 **不显示软件光标**（与 touch-only 真机一致）；USB 外接鼠标 passthrough 时仍可显示光标（现有 USB HID 路径）。
- 更新规格与文档，使「Android Emulator 式触摸」成为正式验收项。

**Non-Goals:**

- 多指手势仿真（pinch/zoom 等）— QEMU multitouch 可报告多点，但本变更只要求 **单指 ≈ 鼠标左键** 与真机主交互一致。
- 替换真机 Goodix 驱动或 DT。
- 修改 App 内触摸业务逻辑（依赖现有 libinput → flutter-elinux 触摸栈）。
- 触摸屏压感、 palm rejection、校准 UI。

## Decisions

### D1 — QEMU 设备：`virtio-multitouch-pci` 替代 `virtio-tablet-pci`

**Choice:** Launcher 默认 `-device virtio-multitouch-pci`（必要时 `display=<virtio-gpu id>` / `head=0` 与 GPU 绑定，与 `-device virtio-gpu-gl-pci,xres=…,yres=…` 同 head）。

**Rationale:** `virtio-tablet` 在 Linux 上注册为 pointer tablet；`virtio-multitouch` 注册为 **touchscreen**（`INPUT_MT`），libinput 分类为 touch，flutter-elinux 收到 Flutter touch 事件 — 与真机/Android Emulator 语义对齐。

**Alternatives considered:**

| Option | Rejected because |
|--------|------------------|
| 保留 tablet + guest uinput 转换脚本 | 额外 daemon、坐标系/同步复杂，违反「最小 diff」 |
| `usb-tablet` | USB 栈开销；仍多为 pointer 语义 |
| 仅文档说明「用 tablet 凑合」 | 不满足 touch-only UX / 滚动差异 |

### D2 — 可选回退：`EMULATOR_INPUT=tablet|touch`（默认 `touch`）

**Choice:** 环境变量切换输入模式；`touch` 为默认，`tablet` 恢复旧 virtio-tablet 供 pointer 调试。

**Rationale:** 低成本的 escape hatch，不影响 CI/文档主路径。

### D3 — Guest 光标策略

**Choice:** 当 `lws.emulator=1` 且 **无 USB pointer HID** 时，Weston（或 flutter-elinux launcher 参数）**隐藏默认光标**；检测到 USB 鼠标节点后再显示（复用现有 mouse 探测逻辑，若已有）。

**Rationale:** Touch-only 真机无光标；tablet 模式下光标会误导 QA。

**Fallback:** 若 Weston 14 隐藏光标 API 在 virt 上不稳定，可在 `weston-hmi-config.sh` 的 sim 分支写 `cursor-theme=` / `use-input-method=false` 等 documented ini 键，或接受短期「有光标但事件为 touch」并在 tasks 中验证 touch 事件优先。

### D4 — 规格：`p32-utm-guest` → `p32-qemu-guest` + 触摸输入要求

**Choice:** 将 canonical spec 目录重命名为 `p32-qemu-guest`；delta 中 REMOVED「Absolute pointer…」+ ADDED「Touchscreen input…」（见 specs）。

**Rationale:** 正式 launcher 为 QEMU（`make emulator`），旧 UTM 名误导；触摸语义变更与重命名一并归档。

### D5 — Kernel / rootfs

**Choice:** 先 **不** 改 `emulator-virtio.config`；bring-up 时在 guest 验证 `evtest` / `libinput list-devices` 出现 multitouch 节点。

**Rationale:** `CONFIG_VIRTIO_INPUT` 已开；若缺 MT slot 等选项再追加 `CONFIG_INPUT_MULTITOUCH=y`（Buildroot 通常默认 y）。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| QEMU multitouch 与 cocoa/gtk display 坐标缩放不一致 | 绑定 `display=` / 与 `EMULATOR_XRES/YRES` 一致；在 guest 用 `evtest` 核对 ABS 范围 |
| flutter-elinux 仍优先 pointer 设备 | 移除默认 tablet；确认 touch 设备在 libinput seat 中；必要时 sim-only weston ini `core-touch-mode=` |
| 开发者习惯 pointer 模式 | `EMULATOR_INPUT=tablet` 文档化 |
| USB 鼠标 + multitouch 双输入 | USB 鼠标为次要；touch 为主交互；文档说明调试鼠标行为 |

## Migration Plan

1. 改 `run-emulator.sh` 输入设备 + hw map 文案。
2. Guest smoke：`make emulator` → SSH → `libinput list-devices` 含 Touch；HMI 可点按/滚动。
3. 更新 `docs/p32-emulator.md`、`oem/screens/virt/screen.json`。
4. 归档 OpenSpec delta 到 `openspec/specs/p32-qemu-guest/spec.md`（删除 `p32-utm-guest`）。

**Rollback:** `EMULATOR_INPUT=tablet make emulator` 或 revert launcher commit；无 GPT/分区变更。

## Open Questions

- `virtio-multitouch-pci` 在 macOS cocoa + `virtio-gpu-gl-pci` 上是否必须显式 `display=virtio_gpu_0` — bring-up 时确认（QEMU 版本差异）。
- flutter-elinux 对 touch-only seat 是否需要额外 env（如 `FLUTTER_ENGINE`-侧参数）— 实现阶段在 guest 验证后再定。
