## Why

Rockchip U-Boot / MiniLoader already treat Vendor Storage `VENDOR_SN_ID` as the board’s visible unique serial (`serial#` / RockUSB `SerialNo`); when set, Loader mode never exposes a separate SoC chip id. Our host table still shows a parallel **ChipID** column and accepts **`CHIP_ID=`**, which confuses operators (Loader rows duplicate product SN). Align the **operator-facing** surface with Rockchip: **SN only**. Keep SoC serial underneath for fallbacks, HAL, and secrets.

## What Changes

- **BREAKING (display / selection):** Remove **`ChipID`** from `make devices` and related TSV producers. Columns: MODE / SN / LocationID / IFACE / IP / USB.
- **BREAKING (selection):** Remove host env **`CHIP_ID=`**. Operators select with **`SN=`** (deprecated **`SERIAL=`** alias), plus **`IP=`** / **`IFACE=`** where already defined.
- **SN** stays the sole operator identity: Vendor Storage product SN when present; else SoC / board serial fallback (unchanged resolution).
- RockUSB / adb rows: **SN** = upgrade_tool / adb SerialNo.
- **Keep (non-display):** HAL **`ProductInfo.chipId`**, `SysInfoSnapshot.chipId`, `read-serial --chip-id`, software KEK chip-id binding, and SN←chip fallback when Vendor Storage is empty.
- Docs (README, AGENTS.md, make-commands, hal-portability) stop presenting ChipID / CHIP_ID= as operator identity.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `properties-ini`: Host listing/selection is SN-only; drop ChipID column and CHIP_ID= matching. HAL chipId property remains.
- `host-push-hmi`: `make devices` / `push-app` without ChipID / CHIP_ID=.
- `host-remote-ssh`: Registry rows expose SN only (no ChipID column).
- `buildroot-lws-hmi-image`: `make devices` column list and Loader scenarios are SN-only.
- `vendor-storage-identity`: write-identity selection examples use SN=/IP= only (not CHIP_ID=).
- `dart-hal`: Clarify chipId remains on snapshots as hardware serial; operator host identity is SN-only (no requirement change to remove chipId API).

## Impact

- Host scripts and tests that print or select by ChipID / CHIP_ID=.
- Operator workflows using `CHIP_ID=` → switch to `SN=` (value may still be the SoC serial when Vendor Storage SN is empty).
- No change to Vendor Storage ID map, PRODUCT_SN write path, HAL chipId APIs, or KEK binding.
