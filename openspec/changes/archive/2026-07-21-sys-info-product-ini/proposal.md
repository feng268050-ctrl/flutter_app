## Why

Product identity and factory-tunable parameters today are split across board SN helpers (`read-serial` / SoC ID), `board_profile.json` (`camera_ip`), and a planned but unimplemented `model.properties` path. Device Information and host tooling (`make devices`) need a single, standardized, HAL-owned product file — aligned with lws-ui `model.properties` intent, but as an extensible `/var/lib/hmi/product.ini` contract rather than ad-hoc App reads.

## What Changes

- Add a HAL **product identity** layer that reads `/var/lib/hmi/product.ini` (missing file or key → empty string; Device Information UI maps empty → `-`).
- Expose **built-in class properties** on the product identity type: `brand`, `model`, `sn`.
  - `sn`: use `product.ini` `sn` when non-empty; otherwise fall back to chip/board serial (same priority as today’s `read-device-serial.sh` / DT → `/proc/cpuinfo` Serial).
- Expose **typed accessors / functions** for extended keys: `camera_ip`, `camera_type` (`1`|`2`), `focus_scale_ref`, `control_card_comm_alarm_mode` (`slide_window`|`immediate`); unknown future keys remain readable via a generic getter so the HAL stays extensible.
- Wire Settings **Device Information** (lws-ui grouping parity):
  - **Device Model** row before Device SN: display `brand + " " + model`; each missing part as `-`; computed `- -` collapses to `-`.
  - **Device QR**: icon on the Device Model row; tap opens identity QR **v2** payload `SN|2|Model|SystemVersion` (same sanitize rules as lws-ui).
  - Three cards: identity (Device Model + QR, Device SN, Gunhead SN) → versions (System / Kernel / Control Card / Laser / Wire Feeder) → platform (Display Stack + Camera Type `1`/`2` → Blue/Red Light + Focus Scale Reference from `product.ini`, empty → `-`). Do not show Modbus Link.
- Update board serial resolution used by USB gadget / `make devices` so host **SN** follows `product.ini sn` → chip ID, and **ChipID** shows the chip serial (`read-serial --chip-id`). Android adb / RockUSB loader rows use adb/SerialNo in both SN and ChipID (chip identity).
- **Rename host device-selection env** from `SERIAL=` to **`SN=`** across Make targets (`push-app`, `upgrade`, `shell`, `flash`, `reboot*`, `debug-app`, `set-prop` selection, …). `SN=` matches table **SN** or **ChipID**. Add **`CHIP_ID=`** for ChipID-only selection (needed when `make set-prop SN=…` would collide with device selection). Keep deprecated `SERIAL=` as an alias. Update Makefile `help`, `.env.example`, README, and AGENTS.md.
- Prefer `product.ini` over `board_profile.json` helpers for `camera_ip` when the key is present (profile remains fallback for boards without a product file).
- Add host Make targets mirroring lws-ui **`make set-prop` / `make del-prop`**, targeting `/var/lib/hmi/product.ini` over SSH (USB-SSH or registered `IP`/`SN`/`CHIP_ID`), not adb/`model.properties`.
  - CLI keys UPPERCASE → file keys lowercase (e.g. `CAMERA_IP` → `camera_ip`), same convention as lws-ui.
  - **`set-prop` enhancement:** allow **one or more** `KEY=value` assignments in a single invocation (lws-ui allowed only one).
  - When `SN=` is a **product** assignment on `set-prop` / `del-prop`, it MUST NOT also act as device selection for that run (use `CHIP_ID=` / `IP=` / deprecated `SERIAL=` on multi-board).
  - **`del-prop`:** remove one UPPERCASE key per invocation (same as lws-ui); missing key → warning, non-fatal.
  - After successful write/delete, restart `hmi.service` so the App reloads product identity (analogous to lws-ui app relaunch).
- Docs: note Linux path `/var/lib/hmi/product.ini` as the successor to the P5.1 `model.properties` candidate for these keys (no Android `/system/etc/model.properties` work in this change); document `SN=` / `CHIP_ID=` / `set-prop` / `del-prop` in Makefile `help`, README Make commands, and AGENTS.md.

## Capabilities

### New Capabilities

- `product-ini`: Contract for `/var/lib/hmi/product.ini` (keys, empty defaults, SN fallback, HAL product identity API, Device Information display including Device Model / QR / Focus Scale Reference, host `make devices` SN/ChipID alignment, and host `make set-prop` / `del-prop` mutate/reload flow).

### Modified Capabilities

- `dart-hal`: Extend `hal/sys_info` (or adjacent product-identity surface under the same HAL package) so Apps consume brand/model/sn and extended product keys from HAL, not by parsing the ini in App code.
- `settings-ui`: Device Information SHALL use lws-ui-style card grouping; Device Model (`brand + " " + model`), device QR v2, Focus Scale Reference, and Device SN from product identity (empty → `-`).
- `p2-device-demo-ui`: Device SN resolution SHALL follow product.ini → chip serial (still not Modbus); missing still displays `-`.

## Impact

- **HAL:** `packages/cyber_hal` — new product-ini reader + product identity type; `LinuxSysInfo` / `DeviceSnReader` (or successor) SN resolution; stub values for sim; tests.
- **App:** Settings Device Information tab (grouped cards, QR dialog, focus scale); Demo identity rows if still shown; callers of `camera_ip` (e.g. boot self-check) prefer product.ini via HAL; `qr_flutter` for QR rendering.
- **Overlay / host:** `read-device-serial.sh` (or shared helper) prefers `product.ini` `sn`; USB gadget iSerial and `scripts/ssh-devices.sh` / `make devices` inherit the same rule; optional sample/empty `product.ini` under `/var/lib/hmi` (via userdata) is factory-provisioned, not baked as a secrets file in git.
- **Host tooling:** `scripts/set-product-prop.sh` / `scripts/del-product-prop.sh` + Makefile `set-prop` / `del-prop`; rename device-selection env `SERIAL=` → `SN=` (+ `CHIP_ID=`); update `help`, README, AGENTS.md (host-only; no firmware rebuild).
- **Non-goals:** Modbus gunhead / control-card firmware fields; OTA check-update / auto-check controls on Device Information; rewriting MediaMTX / eth0 camera segment scripts beyond reading `camera_ip` from the new source when those scripts are next touched; Android adb `set-prop` against `/system/etc/model.properties`.
