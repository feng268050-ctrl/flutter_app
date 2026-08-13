## Why

P3.2 模拟器当前用 `virtio-tablet` 提供绝对坐标指针（鼠标语义），与 ynh960 真机 Goodix 电容触摸屏（触摸语义、无可见光标）不一致。开发者在 Mac 上用鼠标点 HMI 时走的是 pointer/click 路径，无法复现触摸滚动、长按、多指手势等真机行为，也与 Android Emulator「窗口内鼠标即触摸」的体验不符。

## What Changes

- QEMU launcher 将主输入从 `virtio-tablet-pci` 改为 **`virtio-multitouch-pci`**（绑定 virtio-gpu 显示 head），使 host 鼠标在 guest 内产生 **BTN_TOUCH / MT 坐标** 事件，而非 pointer motion。
- Guest 侧确认 libinput → Weston → flutter-elinux 触摸路径在 `lws.emulator=1` 下可用；模拟器默认 **隐藏软件光标**（与 touch-only 真机一致）。
- 将 OpenSpec 能力 **`p32-utm-guest` 重命名为 `p32-qemu-guest`**（正式路径为 QEMU，不再保留 UTM 历史名）。
- 更新 `p32-qemu-guest` 规格：「绝对指针」要求替换为「触摸屏输入（Android Emulator 式 host 鼠标映射）」。
- 文档（`docs/p32-emulator.md`、launcher hw map）与 `oem/screens/virt/screen.json` 的 `touch_notes` 同步。
- 可选：`EMULATOR_INPUT=tablet|touch` 环境变量保留 tablet 指针模式供调试（默认 `touch`）。

## Capabilities

### New Capabilities

（无。）

### Modified Capabilities

- `p32-qemu-guest`（自 `p32-utm-guest` 重命名）: 将「Absolute pointer and playback audio」改为「Touchscreen input and playback audio」；明确 host 鼠标映射为 guest 单点触摸、无需 mouse grab，且与真机 touch-only UI 一致。

## Impact

- `scripts/run-emulator.sh` — QEMU `-device` 输入栈
- `docs/p32-emulator.md` — 操作说明与 hw map
- `openspec/specs/p32-qemu-guest/spec.md` — 重命名 + 需求变更（via delta）
- `docs/p32-emulator.md` — 移除 UTM 重定向链接
- `oem/screens/virt/screen.json` — touch_notes
- 可能：`overlay/.../weston-hmi-config.sh` 或 compositor 光标策略（仅 `lws.emulator=1`）
- 内核 `emulator-virtio.config` 已有 `CONFIG_VIRTIO_INPUT=y`，预计无需改 kernel；若 multitouch 需额外 Kconfig 再补 fragment
- `packages/cyber_hal` sim profile 的 `mouse` capability 可保留（USB 鼠标 passthrough 仍可用），不影响本变更主路径
