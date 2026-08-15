## Context

真机 HMI 已只读 `/run/hmi/board_profile.json`（oem-compose），再 `withProductConfigs` 注入 App gpio/modbus。`assets/hal/board_profile.json` 与「profile 属 OEM、产品目录属 App」分工矛盾。

Modbus RTU 节点因主板而异，寄存器图是产品资产；路径表应落在同一份 `modbus.json`，而不是 Dart `switch` 或 OEM helper。

## Goals / Non-Goals

**Goals:**

- `transport.device_by_board`：仅 **`ynh960`、`ek3562`、`sim`** 三键。
- HAL 按 `board_id` 解析；未命中 → `transport.device`（保持 `/dev/ttyS5`，覆盖 ynh961/962 等同线板）。
- 删除 App 捆绑的 `board_profile.json`；主机 stub 不进 Flutter assets。
- shipping OEM 不写 `modbus_rtu_device`。

**Non-Goals:**

- 不为 ynh961/ynh962 单独建 `device_by_board` 条目。
- 不 fork 整份 `modbus.json` 为每板副本。
- 不做 RS485 DE / DTS。
- 不改 `app/os_settings` 的 `assets/board_profile.json`。
- 不从 sim OEM 删除既有 `modbus_rtu_device`。

## Decisions

### D1 — `modbus.json` `device_by_board`（非 Dart 板表、非 OEM）

- **Choice:**
  ```json
  "transport": {
    "device": "/dev/ttyS5",
    "device_by_board": {
      "ynh960": "/dev/ttyS5",
      "ek3562": "/dev/ttyS4",
      "sim": "/dev/ttyUSB0"
    },
    ...
  }
  ```
- **Resolve order:** OEM `modbus_rtu_device` helper（若设）→ else `device_by_board[boardId]` → else `transport.device`。
- **Why:** 路径与寄存器图同属产品资产；三键足够；同线板靠默认 `device`。
- **Alt rejected:** `HmiHalAssets.modbusRtuDeviceForBoard`；OEM helpers on ynh960/ek3562；每板全量 JSON。

### D2 — 删除 App `assets/hal/board_profile.json`

- **Choice:** 删文件与 pubspec；非 Linux 用 `hostDevBoardProfile()` 代码 stub + `withProductConfigs`。
- **Why:** 避免假权威源。

### D3 — 包测改读 OEM

- **Choice:** `cyber_hal` 测试读 `oem/boards/ynh960/board_profile.json`。

## Risks / Trade-offs

- [未列出的 board 静默回落默认 device] → Mitigation: 新板接入 checklist 要求补 `device_by_board`；台账文档写明。
- [sim OEM helper vs JSON] → Mitigation: 两者同为 `/dev/ttyUSB0`；helper 优先仅保留包测兼容。

## Migration Plan

1. 改 `modbus.json` + HAL 解析 + 删 App board_profile。
2. `make build-app` 后 `push-app` / `upgrade-app`。
3. 无需 `build-oem`。

## Open Questions

- （无）
