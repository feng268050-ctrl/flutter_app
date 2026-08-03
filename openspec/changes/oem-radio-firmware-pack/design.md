## Context

- Target tree today: `/usr/lib/firmware` ≈ **42.6 MiB** (~296 files); ynh960 AIC8800D80 keep-set ≈ **547 KiB** (7 files). Innohi source dump ≈ **33 MiB**.
- Hardware SoT: `overlay/kernel/rockchip/ynh960-wifibt.config` (AIC8800D80). Lunch still sets `RK_WIFIBT_CHIP="AP6256"` so `post-wifibt` builds/copies Broadcom paths; Innohi block then `cp -rf` entire firmware trees into `vendor/etc/firmware` (hardlinked with `/usr/lib/firmware`).
- Product already injects modem via OEM profile (`wifi_modem` / `bt_modem` → `wifibt-bringup.sh`) after HMI — see `docs/network-stack.md`.
- Active parallel change: **`kernel-61-lts-rebase`** (kernel tip, overlay patches/DTS, Wi‑Fi/BT regression). This design must not race that work.

## Goals / Non-Goals

**Goals:**

- OEM owns **module firmware blobs** for the onboard combo radio.
- Shared rootfs stops carrying multi-vendor Wi‑Fi/BT firmware.
- Bringup prefers OEM; driver search paths still satisfied via symlink/bind.
- Clear implement gate relative to kernel LTS rebase.

**Non-Goals:**

- Moving `aic8800_*.ko` into OEM.
- Moving wpa_supplicant / bluetoothd / BlueZ-ALSA into OEM.
- Supporting every Rockchip `RK_WIFIBT_MODULES` kitchen-sink chip in one image.
- Editing `overlay/kernel/**` as part of the first implementation slice (leave kernel fragment ownership to LTS rebase until it archives).

## Decisions

### D1 — Scheme C: firmware in OEM radio pack

Authoritative blobs live under the board OEM pack (see D2). Rootfs MUST NOT be the long-term home for AIC (or other) combo firmware.

**Alternatives:** B (trim keep-set into rootfs only) — rejected for RED / board-local radio ownership; A (post-build purge only) — insufficient as sole strategy (source still dumps everything).

### D2 — Layout (ynh960 first)

```text
/oem/boards/ynh960/
  board_profile.json          # existing wifi_modem / bt_modem
  helpers/wifibt-bringup.sh
  radio/
    manifest.json             # chip id, file list, optional cert/note fields
    firmware/                 # AIC8800D80 keep-set only
```

If 961/962 share the same module later, factor `oem/radio/aic8800d80/` (or symlink/copy into each board) — out of first slice unless trivial.

**Keep-set (ynh960, locked at implement by bringup + driver):**

- `fmacfw_8800d80_u02.bin`
- `lmacfw_rf_8800d80_u02.bin`
- `fw_adid_8800d80_u02.bin`
- `fw_patch_8800d80_u02.bin`
- `fw_patch_table_8800d80_u02.bin`
- `aic_userconfig_8800d80.txt`
- `aic_userconfig.txt` (if still referenced)

### D3 — Bringup resolution order

1. OEM `radio/firmware/` (or profile override path) — **required** for product success path.
2. Optional short transitional fallback to `/vendor/etc/firmware` **only** if explicitly enabled for one release (default off once OEM ships).
3. Symlink/bind OEM dir into paths `CONFIG_AIC_FW_PATH` / historical `/lib/firmware` expectations so driver code need not change.

Missing OEM radio: log + soft-fail (same spirit as missing modem today); do not crash HMI.

### D4 — `.ko` stay on OS

`aic8800_bsp` / `aic8800_fdrv` / `aic8800_btlpm` remain produced with the kernel and installed via existing module paths (`/vendor/lib/modules` or equivalent). OEM MUST NOT ship competing `.ko` copies in v1.

### D5 — Rootfs assembly: stop the kitchen sink

When implementing (after LTS gate):

1. Stop Innohi full `firmware/*` copy into target (or copy only nothing / empty dir).
2. Retire `RK_WIFIBT_CHIP="AP6256"` Broadcom side-effect (replace with an AIC-oriented or “modules-only / no FW dump” post-wifibt mode so `.ko` still land without bcm firmware).
3. Do not install `bcmdhd*.ko` for this product line.
4. `post-build` and/or `verify-rootfs-overlay`: fail or purge if `fw_bcm*` / multi-vendor dumps reappear under `/usr/lib/firmware`.

Exact post-wifibt patch strategy is an implement detail; prefer overlay-owned script patches consistent with `patch-post-wifibt.sh` patterns — **coordinate with LTS** so both don’t rewrite the same script concurrently.

### D6 — Sequencing vs `kernel-61-lts-rebase`

| Phase | This change | Kernel LTS |
|-------|-------------|------------|
| Now | Artifacts only (proposal/design/specs/tasks) | In progress — owns kernel tip + overlay/kernel |
| Implement | **After** LTS archived (or after explicit “kernel tip frozen + Wi‑Fi smoke green”) | Done |
| Avoid until then | Edits to `overlay/kernel/**`, competing `post-wifibt` large rewrites, forcing Wi‑Fi matrix on unstable tip | — |

Optional prep that does **not** conflict (only if desired later, still not required before LTS): add empty `oem/.../radio/` docs-only tree — prefer waiting to keep one landing.

## Risks / Trade-offs

- **[Risk]** OEM not mounted / wrong SKU → no Wi‑Fi → Mitigation: soft-fail; factory always packs matching OEM; env-verify checks OEM radio files.
- **[Risk]** Driver hard-codes paths → Mitigation: D3 symlink/bind; spike on device before deleting vendor fallback.
- **[Risk]** Conflict with LTS post-wifibt / module install → Mitigation: D6 hard gate; single owner for script edits at implement time.
- **[Risk]** 961/962 different radio later → Mitigation: per-board `radio/`; shared OS stays clean.

## Migration Plan

1. Archive / stabilize `kernel-61-lts-rebase` (Wi‑Fi/BT smoke on new tip).
2. Add OEM radio keep-set + manifest; teach bringup; `make build-oem` + `OEM_ONLY=1 make upgrade` validate Wi‑Fi.
3. Cut rootfs kitchen sink (post-wifibt + verify); `make build-rootfs` + full upgrade; confirm size drop (~40 MiB+).
4. Remove transitional vendor fallback if any.

## Open Questions

1. Factor shared `oem/radio/aic8800d80/` for 960/961/962 in v1, or duplicate under `ynh960` only until other boards are validated?
2. Should `radio/manifest.json` record RED/doc references as free-form metadata only, or stay minimal (chip + files)?
