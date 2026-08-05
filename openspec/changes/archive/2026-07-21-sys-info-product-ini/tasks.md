## 1. HAL product.ini + ProductInfo

- [x] 1.1 Add `ProductIniReader` (parse flat `key=value`, comments/blanks) with injectable path default `/var/lib/hmi/product.ini`
- [x] 1.2 Add `ProductInfo` with properties `brand` / `model` / `sn` and accessors `cameraIp` / `cameraType` / `focusScaleRef` / `controlCardCommAlarmMode` / `get(key)` (empty string defaults; typed enum validation)
- [x] 1.3 Implement `sn` resolution: non-empty ini `sn`, else chip/board serial via existing `DeviceSnReader` / `read-serial`
- [x] 1.4 Export from `cyber_hal` (sys_info or adjacent library barrel) and wire `BoardBindings` / stub constructors
- [x] 1.5 Unit tests: missing file, comments, factory sn override, chip fallback, invalid `camera_type` / alarm mode, generic `get`

## 2. SysInfo snapshot surface

- [x] 2.1 Add `brand` and `model` to `SysInfoSnapshot`; set `serialNumber` from `ProductInfo.sn` (map empty → null if UI still expects null, or document empty+UI dash)
- [x] 2.2 Update `LinuxSysInfo` / `StubSysInfo` / volatile signature as needed so identity fields stay on every watch emit
- [x] 2.3 Extend `sys_info_test.dart` (and stub fixtures used by App tests)

## 3. Shell / make devices SN parity

- [x] 3.1 Update `read-device-serial.sh` (product.ini sn + `--chip-id`)
- [x] 3.2 `make devices`: columns SN + ChipID; live probe; android/RockUSB ChipID = adb/SerialNo
- [x] 3.3 HAL `ProductInfo.chipId` + `SysInfoSnapshot.chipId`; sn falls back to chipId
- [x] 3.4 Rename host device-selection env `SERIAL=` → `SN=`; add `CHIP_ID=`; keep `SERIAL=` as deprecated alias; clear SN-as-selector when `set-prop`/`del-prop` writes product `SN`
- [x] 3.5 Docs: Makefile help, `.env.example`, README, AGENTS.md, OpenSpec for SN/ChipID + env rename

## 4. App Device Information + camera_ip

- [x] 4.1 Device Information: Device Model (`brand + " " + model`, empty/`- -` → `-`) before Device SN; empty → `-`
- [x] 4.2 Demo device-info rows (if still shown): SN resolution matches product identity
- [x] 4.3 Boot self-check camera host: prefer `ProductInfo.cameraIp()`, else board profile `camera_ip`, else default
- [x] 4.4 Expose `ProductInfo` on `AppServices` for later product pages (alarm mode / focus scale consumers)
- [x] 4.5 Device Information: three cards — identity / versions / platform (Display Stack + Camera Type + Focus Scale Reference); no Modbus Link
- [x] 4.6 Device Information: device QR v2 dialog (`SN|2|Model|SystemVersion`) on Device Model row
- [x] 4.7 Device Information: Camera Type (`1`→Blue Light, `2`→Red Light) before Focus Scale Reference; both from `ProductInfo` (empty → `-`), with Display Stack

## 5. Host make set-prop / del-prop

- [x] 5.1 Add shared host helper to upsert/delete lowercase keys in a local `product.ini` copy (validate key shape; skip Make/workflow vars)
- [x] 5.2 Add `scripts/set-product-prop.sh`: SSH pull/create `/var/lib/hmi/product.ini`, apply **one or more** `UPPERCASE_KEY=value` upserts, push, restart `hmi.service` once
- [x] 5.3 Add `scripts/del-product-prop.sh`: remove one UPPERCASE key; warn if absent; push if changed; restart HMI when file changed
- [x] 5.4 Wire Makefile `set-prop` / `del-prop` (device selection like `push-app`); swallow `del-prop KEY` extra goals; update `help`
- [x] 5.5 Update README Make commands + AGENTS.md (`SN=` / `CHIP_ID=` / `set-prop`; host-only: no firmware rebuild)
- [x] 5.6 Document `SERIAL=` → `SN=` rename (Makefile help, `.env.example`, living OpenSpec host-push / devices specs)

## 6. Docs / verification

- [x] 6.1 Note `/var/lib/hmi/product.ini` as Linux successor for these `model.properties` keys (plan or HAL README — brief)
- [x] 6.2 Run `cyber_hal` tests and App analyze for touched Dart
- [x] 6.3 On device (when available): `make set-prop` multi-key + Settings Device Model/SN/QR/Focus Scale; `make del-prop`; `make devices` SN/ChipID with/without `sn`
