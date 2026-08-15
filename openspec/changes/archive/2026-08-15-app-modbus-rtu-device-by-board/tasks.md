## 1. modbus.json multi-board transport

- [x] 1.1 Add `transport.device_by_board` to `app/lws_hmi/assets/hal/modbus.json` with only `ynh960`→`/dev/ttyS5`, `ek3562`→`/dev/ttyS4`, `sim`→`/dev/ttyUSB0` (keep default `device` `/dev/ttyS5`)
- [x] 1.2 Parse `device_by_board` in `ModbusConfig` / `ModbusTransport`; resolve device by `boardId` (OEM helper → by_board → default)
- [x] 1.3 Wire `ModbusHal.fromProfile` to apply resolved device from profile `board_id`

## 2. Remove App board_profile asset

- [x] 2.1 Delete `app/lws_hmi/assets/hal/board_profile.json` and pubspec asset entry; remove `HmiHalAssets.boardProfile`
- [x] 2.2 Non-Linux `main.dart`: use in-code `hostDevBoardProfile()` + `withProductConfigs` (no Flutter asset)
- [x] 2.3 Retarget `cyber_hal` tests that read App `board_profile.json` to `oem/boards/ynh960/board_profile.json`

## 3. Docs + verify

- [x] 3.1 Update `docs/ynh960-io-pinmux-ledger.md`, `docs/ek3562-io-pinmux-ledger.md`, `docs/hal-portability.md` (App `modbus.json` SoT; no App board_profile asset)
- [x] 3.2 Unit coverage for `device_by_board` + fallback; run relevant package / App tests
