## Context

Today:

- **`make upgrade`** → `scripts/upgrade-remote.sh`: SSH-only stream of inactive FIT + `rootfs.img` (+ optional oem). Explicitly refuses RockUSB / `upgrade_tool uf`.
- **`make flash`** → `scripts/flash-usb.sh`: macOS RockUSB `ul` (Maskrom) + `uf factory.img` — full blob including MiniLoader, U-Boot, misc, GPT/`parameter`, both FITs, both rootfs letters, oem.
- **OTA payload** (product staged apply / planned package): `boot.img`, `boot_b.img`, `rootfs.img`, optional `oem.img` — **no** uboot/loader/GPT. Signing/zip (`unified-ota-cyber-ota`) is **not** landed and is **out of scope** here.

Gap: a board in **Loader/Maskrom** cannot take SSH upgrade, but flashing full `factory.img` is heavier than needed for “same images as OTA.”

## Goals / Non-Goals

**Goals:**

- Same Make target: `make upgrade` works when the target is RockUSB Loader or Maskrom.
- Flash only the OTA-equivalent loose images over RockUSB (partition download), transport-wise analogous to `make flash` (Loader/Maskrom + `upgrade_tool`), payload-wise analogous to OTA (not factory).
- Preserve today’s SSH stream path when a Linux SSH target is selected.
- Reuse `APP=` / SKU / `OEM_IMG` / `OEM_ONLY` resolution.

**Non-Goals:**

- `make ota-package`, Ed25519, `/userdata/ota/` staged apply, HMI upgrade page, `cyber_ota`.
- Replacing `make flash` / `factory.img` for GPT, U-Boot, MiniLoader, factory reset.
- Changing on-device `ab-upgrade-stream.sh` / `ab-upgrade-apply.sh` contracts.
- Linux-host RockUSB support beyond today’s macOS `upgrade_tool` constraint.

## Decisions

### D1 — One target, two transports (dispatch)

- **Choice:** `make upgrade` resolves target mode:
  1. If a deployable **Linux SSH** target is selected (USB-SSH / `IP=` / `SN=` → SSH) → **existing stream path**.
  2. Else if a **RockUSB** Loader/Maskrom device is selected → **OTA-images RockUSB path**.
  3. Else fail with `make devices` / `reboot-loader` / Maskrom guidance.
- Prefer SSH when both could match the same `SN=` only if the board is still on SSH (normally mutually exclusive). Multi-device: require `SN=` / `CHIPID=` as today.
- Optional escape: `UPGRADE_TRANSPORT=ssh|rockusb` to force (default auto).
- **Why:** Matches “`make upgrade` 支持 loader/maskrom” without a second Make verb; keeps flash = factory.
- **Alternatives:** New `make flash-ota` (clearer separation, but user asked to extend upgrade).

### D2 — Payload = OTA image set, unsigned

| Image | RockUSB destination |
|-------|---------------------|
| `output/firmware/boot.img` | partition `boot` |
| `output/firmware/boot_b.img` | partition `boot_b` |
| `output/firmware/<APP>/rootfs.img` | **both** `rootfs_a` and `rootfs_b` |
| resolved `oem.img` (unless skipped) | `oem` |

- **Not written:** MiniLoader to storage as product content, `uboot.img`, `misc.img`, `parameter` / GPT.
- Maskrom still uses **RAM** `ul` MiniLoader (same as `make flash`) so `di` can run — that is tool bring-up, not “flashing loader into the OTA set.”
- No `.sig` / zip requirement.
- **Why:** Dead-board recovery cannot read misc for “inactive letter”; dual rootfs + both FITs mirrors factory’s OS payload half and leaves a bootable pair. userdata untouched.
- **Alternatives:** Inactive-only (needs misc read over RockUSB — fragile); `uf` a slim custom update.img (extra pack step; closer to flash).

### D3 — Tooling: `upgrade_tool di` (+ Maskrom `ul`), not `uf factory.img`

- Implement partition download via Rockchip `upgrade_tool` **`di`** (or documented equivalent) against partition names from the A/B GPT / `package-file` map.
- Reuse `flash-usb.sh` primitives where practical (device list, `SN=`, Maskrom detect, `ul`, macOS gate); keep factory `uf` path exclusive to `make flash`.
- **`OEM_ONLY=1`:** only `di` oem; skip boot/rootfs; no SSH reboot semantics (RockUSB reset/`rd` as appropriate).
- **Why:** Avoids packing factory; image sources stay the same loose files SSH upgrade already uses.

### D4 — Explicit non-goals vs unified OTA / flash

- Docs MUST say: RockUSB upgrade path ≠ product OTA (no sign/stage/UI); ≠ `make flash` (no uboot/loader/GPT/misc).
- Do not auto-run `build-img` or consume `factory.img` / `IMAGE=`.

### D5 — Platform constraint

- RockUSB path: **macOS only** (same as `make flash`). Linux hosts keep SSH upgrade; enter Loader on device from USB-SSH via `reboot-loader` then flash from Mac if needed.

## Risks / Trade-offs

- [Dual rootfs write takes longer than SSH inactive-only] → Mitigation: progress per `di`; still cheaper than full factory `uf`.
- [misc try-boot marker left stale] → Mitigation: both letters get same rootfs + matching FITs; document that RockUSB upgrade does not rewrite misc (unlike factory flash). If needed later, optional misc reset can be a follow-up.
- [Operator expects factory reset] → Mitigation: docs + banner “OTA images only; use make flash for GPT/U-Boot.”
- [Wrong board / multi RockUSB] → Mitigation: reuse flash-usb `SN=` / ChipID selection.
- [di CLI / partition name skew across tool versions] → Mitigation: verify against `tools/upgrade_tool` docs in implementation; fail fast on di error.
- [Confusion with unified-ota redesign of make upgrade] → Mitigation: this change keeps stream + adds RockUSB loose imgs; unified-ota remains a separate change and must not be assumed.

## Migration Plan

1. Land dispatch + `di` sequence + docs; no board overlay change required if GPT already A/B.
2. Operators: `make reboot-loader` (or Maskrom) → `make upgrade` on Mac with built boot/rootfs[/oem].
3. Rollback: force `UPGRADE_TRANSPORT=ssh` or revert script branch; `make flash` unchanged.

## Open Questions

- None blocking. Optional later: `UPGRADE_RESET_MISC=1` to force letter A after RockUSB writes.
