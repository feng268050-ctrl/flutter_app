## Why

ek3562 与 ynh960 的 Modbus RTU 串口节点不同（`/dev/ttyS4` vs `/dev/ttyS5`），但产品寄存器图仍是同一份 App `modbus.json`。设备路径应写在**产品** `modbus.json` 的多板表里，由 HAL 按 `board_id` 解析——对齐「gpio/modbus 属 App」，**不得**写入 shipping OEM helpers。

同时，App 内遗留的 `assets/hal/board_profile.json` 只是历史「迁移兜底」，与真机「仅 `/run/hmi/board_profile.json`」契约冲突，应在本变更一并删除。

## What Changes

- 扩展 `modbus.json`：`transport.device_by_board` 仅含 **`ynh960` → `/dev/ttyS5`**、**`ek3562` → `/dev/ttyS4`**、**`sim` → `/dev/ttyUSB0`**；未列出的 board（如 ynh961/962）回落 `transport.device`。
- `ModbusConfig` / `ModbusHal.fromProfile` 按 `profile.info.boardId` 解析 device；可选 OEM `modbus_rtu_device` 仍可覆盖（sim 包测兜底）。
- **不**增加 `HmiHalAssets.modbusRtuDeviceForBoard` Dart 板表。
- **删除** `app/lws_hmi/assets/hal/board_profile.json` 及 pubspec 引用；非 Linux 主机改用代码内最小 stub。
- 包测改读 `oem/boards/ynh960/board_profile.json`。
- 文档台账标明 RTU 路径权威源在 App `modbus.json`。
- **不**在 shipping OEM `ynh960` / `ek3562` 增加 `modbus_rtu_device`。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `hal-modbus-config`: 产品 `modbus.json` 支持按 `board_id` 选 RTU `device`；OEM MUST NOT 成为 shipping 板路径权威源。
- `oem-pack`: shipping OEM MUST NOT 声明产品 Modbus RTU 设备路径；sim 既有 helper 仅作模拟器/包测兜底。HMI App MUST NOT 再捆绑 `assets/hal/board_profile.json`。
- `hal-board-profile`: Linux 仅 `/run/hmi/board_profile.json`；无 App asset 兜底。

## Impact

- `app/lws_hmi/assets/hal/modbus.json`、`main.dart`、`pubspec.yaml`；删除 `assets/hal/board_profile.json`
- `packages/cyber_hal`：`ModbusConfig` / `ModbusHal.fromProfile`；测试改读 OEM profile + `device_by_board` 解析
- `docs/ynh960-io-pinmux-ledger.md`、`docs/ek3562-io-pinmux-ledger.md`、`docs/hal-portability.md`
- 验证：`make build-app` + `push-app` / `upgrade-app`（无 OEM rebuild 要求）
