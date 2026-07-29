## 1. Firmware assets and packaging

- [x] 1.1 Add `app/lws_hmi/assets/firmware/control-board/` with the release control-board `.bin` (`LSW01H####S####.bin`; start from current lws-ui release bin or document the chosen version)
- [x] 1.2 Declare `assets/firmware/` in `pubspec.yaml` (checked-in asset root; no repo-root mirror / sync script)
- [x] 1.3 Allow multiple bins under `assets/firmware/control-board/`; discovery auto-selects newest SW for matching device HW

## 2. Version gate and discovery (pure Dart)

- [x] 2.1 Port filename pattern + HW/SW integer parse (`BundledFirmwareVersionGate` / `UpgradeFileReaderUtils` rules)
- [x] 2.2 Implement asset discovery under `assets/firmware/control-board/` (auto-select latest matching HW)
- [x] 2.3 Unit-test gate + latest-bin selection: newer SW offers upgrade; equal SW / HW mismatch / invalid name; multi-bin picks max SW

## 3. Modbus control-board upgrade handler

- [x] 3.1 Implement upgrade session state (file info, offset, progress, awaiting confirm) using App Modbus attrs (`upgrade.*`, `device.ota_request_command`, control HW/SW)
- [x] 3.2 Port transfer sequence: info write (`0x1234`) → ≤128-byte data packets (`0x55AA`) → end (`0x0000`) → confirm poll (`0x1212` / `0x0202` / version match / 30s confirm timeout → success)
- [x] 3.3 Pause or isolate continuous Modbus live poll/watch during exclusive transfer; resume on end
- [x] 3.4 Wire stall / timeout failure paths aligned with lws-ui constants; emit progress percent for UI
- [x] 3.5 Add contiguous `writeHoldingRegisters` on `cyber_hal` + App `ModbusRtuClient`; build lws-ui-length frames (not full `writeGroup('upgrade')`)
- [x] 3.6 Confirm via `status` snapshot; prefer HW/SW match; tolerate brief fail latch; timeout after end → success

## 4. Coordinator and bootstrap

- [x] 4.1 Add `FirmwareUpgradeCoordinator` (bundled + future OTA busy flags; only bundled used now)
- [x] 4.2 Implement home bootstrap: evaluate candidate when Home visible + Modbus + versions ready; skip on emulator/virt / busy / no candidate
- [x] 4.3 Hook from `HomePage` after self-check (when shown) and `ensureModbusLive`, without blocking first paint; re-check on return to Home via `RouteAware` / `appRouteObserver`
- [x] 4.4 On confirm: start transfer; on dismiss: no transfer; cleanup temp/cache and coordinator flags on session end

## 5. CyberUI dialogs and version refresh

- [x] 5.1 Confirm dialog using `bundledFirmwareDialogTitle` / `bundledFirmwareDialogMessage`
- [x] 5.2 Blocking progress dialog with determinate percent (`bundledFirmwareUpgrading*` / `bundledFirmwareProgressPercent`)
- [x] 5.3 Success / fail result dialogs (`bundledFirmwareSuccess*` / `bundledFirmwareFailed*`)
- [x] 5.4 On success, refresh Firmware Version display source (`device.control_card_version` invalidate/re-read or equivalent)
- [x] 5.5 Bound firmware dialog content width (no full-bleed stretch)

## 6. Host control-board upgrade helper

- [x] 6.1 Add `scripts/upgrade-control-board.sh` + Makefile `upgrade-control-board` (pick newest `control-board` bin, SSH upload, write cmd file)
- [x] 6.2 App watcher on `/run/hmi/upgrade-control-board.cmd` starts Modbus upgrade with no confirm / no version gate
- [x] 6.3 Document helper in README / AGENTS.md as control-board-only subset of host `upgrade*` naming

## 7. Verification

- [x] 7.1 `flutter analyze` / unit tests for gate + handler edge cases under `app/lws_hmi/`
- [x] 7.2 Device smoke on ynh960: Home offers upgrade when SW older, dismiss skips, confirm completes or fails cleanly; Settings OTA footer still deferred
- [x] 7.3 Confirm no product OTA / cloud OTA / host OS `make upgrade` paths were introduced beyond the control-board-only helper
