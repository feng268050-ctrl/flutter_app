## Why

P3.2 模拟器当前用 `virtio-tablet` 提供绝对坐标指针（鼠标语义），与 ynh960 真机 Goodix 电容触摸屏（触摸语义、无可见光标）不一致。开发者在 Mac 上用鼠标点 HMI 时走的是 pointer/click 路径，无法复现触摸滚动、长按等真机行为，也与 Android Emulator「窗口内鼠标即触摸」的体验不符。

## What Changes

- **Host QEMU** 仍使用 **`virtio-tablet-pci`**（qemu-virgl + cocoa 只向绝对设备送指针；单独挂 `virtio-multitouch-pci` 不可用）。
- **Guest** 增加 **`emulator-tablet-to-touch`**：grab tablet → uinput 触摸设备（单点 down/move/up）+ 独立 wheel 设备（**`REL_WHEEL` 透传**，平滑滚动）。
- Launcher：`EMULATOR_INPUT=touch|tablet`（默认 touch）+ cmdline；display **`show-cursor=on`**；Guest 无 USB 鼠标时隐藏软件光标。
- 将 OpenSpec 能力 **`p32-utm-guest` 重命名为 `p32-qemu-guest`**；规格「绝对指针」→「触摸屏输入（Android Emulator 式）」。
- 文档（`docs/p32-emulator.md`、launcher hw map）与 `oem/screens/virt/screen.json` 的 `touch_notes` 同步；`CONFIG_INPUT_UINPUT=y`。

## Capabilities

### New Capabilities

（无。）

### Modified Capabilities

- `p32-qemu-guest`（自 `p32-utm-guest` 重命名）: 将「Absolute pointer and playback audio」改为「Touchscreen input and playback audio」；明确 host 鼠标映射为 guest 单点触摸（tablet + guest uinput equivalent）、无需 mouse grab，且与真机 touch-only UI 一致。

## Impact

- `scripts/run-emulator.sh` — 输入模式、cmdline、`show-cursor`
- `native/emulator_tablet_to_touch/` + `make build-libexec-binaries` — 桥二进制
- `overlay/.../emulator-tablet-to-touch.service`、preset、`hmi.service.d/emulator-input.conf`（仅 After）
- `overlay/.../weston-hmi-config.sh` — emulator 光标策略
- `overlay/kernel/rockchip/emulator-virtio.config` — `CONFIG_INPUT_UINPUT`
- `docs/p32-emulator.md`、`oem/screens/virt/screen.json`
- `openspec/specs/p32-qemu-guest/spec.md`
- `packages/cyber_hal` sim `mouse` capability 仍可用于 USB 鼠标 passthrough
