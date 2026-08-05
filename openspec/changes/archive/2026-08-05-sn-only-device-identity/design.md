## Context

Rockchip boot firmware copies Vendor Storage `VENDOR_SN_ID` into env `serial#` / FDT / RockUSB `SerialNo` when present, otherwise falls back to chip serial. Linux-side HAL already splits **product SN** (`ProductInfo.sn`) from **SoC serial** (`ProductInfo.chipId`) for crypto and diagnostics. Host `make devices` duplicated that split in a ChipID column and `CHIP_ID=` selector, which is wrong for Loader (only one SerialNo) and unnecessary for operators who should match Rockchip’s “one SN” model.

## Goals / Non-Goals

**Goals:**

- Operator-facing device table and selection use **SN only**.
- Preserve SoC serial as an implementation detail: SN fallback, HAL `chipId`, secrets KEK.
- Update specs/docs so ChipID is not presented as a second unit identity.

**Non-Goals:**

- Removing or renaming `ProductInfo.chipId` / `read-serial --chip-id`.
- Changing Vendor Storage ID map or `write-identity` PRODUCT_SN rules.
- Changing software KEK multi-factor binding (still requires chip id).
- Forcing every board to have a provisioned Vendor SN (empty SN → chip serial fallback remains).

## Decisions

### D1 — Display / selection: SN only

**Choice:** Drop ChipID from `make devices` TSV/table and remove `CHIP_ID=` from host selectors (`device-target`, USB-SSH, SSH registry, flash-usb RockUSB match, write-identity, set-prop ignore lists as a *selector*).

**Why:** Matches Rockchip’s single visible serial and the user’s clarification: keep underlying ChipID, do not surface it.

**Alternatives:** Keep ChipID column but hide on Loader only — rejected (still a dual identity UX). Keep `CHIP_ID=` without column — rejected (operators still taught a second identity).

### D2 — SN resolution unchanged

**Choice:** SN = Vendor Storage SN if non-empty, else chip/board serial. Live probe preferred over USB gadget iSerial when available. RockUSB/adb SN = tool SerialNo.

**Why:** Already aligns with `ProductInfo.sn`; after identity write, Loader SerialNo equals product SN.

### D3 — HAL chipId stays

**Choice:** No Dart API removal. Specs clarify chipId is hardware serial for App/crypto, not host device selection.

**Why:** Explicit non-goal; KEK and diagnostics depend on it.

### D4 — TSV shape

**Choice:** Producers emit MODE, SN, LocationID, IFACE, IP, USB (six fields). Update all parsers/tests that assumed seven fields with ChipID.

**Why:** Single contract for flash-usb merge, usb-ssh, ssh-devices, emulator-devices, Windows PowerShell path.

### D5 — Matching rules for SN=

**Choice:** `SN=` matches the **SN** column only (plus existing special cases: LocationID where already supported for RockUSB multi-device, EMU aliases). No longer “SN or ChipID column”.

**Why:** There is no ChipID column. When VS SN is empty, SN *is* the chip serial, so selecting by chip serial still works via `SN=`.

## Risks / Trade-offs

- **[Risk]** Scripts/docs/CI still pass `CHIP_ID=` → Mitigation: fail closed or ignore with a one-line stderr hint to use `SN=`; grep docs/tests in tasks.
- **[Risk]** Multi-board with same product SN (factory clone error) — ChipID column used to disambiguate → Mitigation: rare; use `IP=` / `IFACE=` / LocationID; factory must keep PRODUCT_SN unique.
- **[Trade-off]** Operators lose a printed SoC serial on Linux rows → Acceptable; `read-serial --chip-id` / About UI / HAL remain if needed for support.

## Migration Plan

1. Land script + test + doc changes together.
2. Operators: replace `CHIP_ID=…` with `SN=…` (same value if board had empty VS SN).
3. No board flash required for host-only changes; no identity rewrite required.

## Open Questions

- None blocking: fail vs ignore for leftover `CHIP_ID=` — default **die with hint** so mis-set env is obvious.
