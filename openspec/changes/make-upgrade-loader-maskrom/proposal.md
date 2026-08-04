## Why

`make upgrade` today only works when the board already boots Linux and answers SSH (stream-to-partition). Boards stuck in **RockUSB Loader / Maskrom** (or deliberately entered via `make reboot-loader`) still need an OS payload refresh without packing/flashing full **`factory.img`** (U-Boot, MiniLoader, GPT/`parameter`, misc). Operators want the same Make entry to burn the **OTA-equivalent image set** over RockUSB—parallel to `make flash`’s transport, not the unified/product OTA zip+sign path.

## What Changes

- Extend **`make upgrade`** with a **RockUSB Loader/Maskrom path**: when the selected (or sole) target is RockUSB—not a live SSH Linux session—flash the OTA-equivalent loose images via `upgrade_tool` partition download (`di`), **not** `uf factory.img` / `update.img`.
- **Image set (align with OTA payload, unsigned lab path):** `boot.img`, `boot_b.img`, `output/firmware/<APP>/rootfs.img`, optional `oem.img` (same `APP=` / `FACTORY_SKU` / `OEM_IMG` / `OEM_ONLY` resolution as SSH upgrade). **MUST NOT** write MiniLoader, `uboot.img`, `misc.img`, or GPT/`parameter` in this path.
- **Maskrom:** same bring-up pattern as `make flash` — `ul` MiniLoader into RAM (`LOADER_NORESET` as needed) then partition downloads; **Loader:** skip `ul`, download only.
- Keep the existing **SSH stream-to-partition** path unchanged when a USB-SSH / registered SSH Linux target is selected.
- Document dispatch: SSH vs RockUSB; contrast with **`make flash`** (full factory blob) and with **unified / product OTA** (zip, Ed25519, `/userdata/ota/` staged apply)—this change does **not** implement or require `make ota-package` / `cyber_ota`.
- **Out of scope:** unified-ota-cyber-ota; signing; userdata wipe; repartition; Android flash; Linux-host RockUSB (macOS `upgrade_tool` constraint remains as for `make flash`).

## Capabilities

### New Capabilities

- (none — RockUSB OTA-image flash is a new mode of the existing `make upgrade` host capability)

### Modified Capabilities

- `host-remote-upgrade`: Allow `make upgrade` on RockUSB Loader/Maskrom by flashing the OTA-equivalent image set via partition download; keep SSH stream path; lift the blanket “MUST NOT RockUSB / upgrade_tool” rule for this mode only; clarify vs `make flash` and vs product OTA.

## Impact

- **Host scripts:** `scripts/upgrade-remote.sh` (dispatch) and/or shared helpers with `scripts/flash-usb.sh` (`upgrade_tool` `di` / Maskrom `ul` sequence, `SN=` selection).
- **Makefile / docs:** `help`, README / `docs/storage-layout.md` upgrade-vs-flash-vs-OTA table, AGENTS.md rebuild row (host-only when only scripts/docs change).
- **Artifacts consumed:** existing `output/firmware/{boot,boot_b}.img`, `output/firmware/<APP>/rootfs.img`, resolved `oem.img` — no new pack format.
- **Cross-change:** does not land or depend on `unified-ota-cyber-ota` / `make-publish-ota`.
