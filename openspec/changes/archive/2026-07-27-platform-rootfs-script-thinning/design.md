## Context

W1 delivered OEM packs, `oem-compose` → `/run/hmi`, and App profile load from OEM. Board bringup (`wifibt-bringup`, `usb-otg-mode`, `ynh960-display-init`), LCD seeds under `/system/etc` → private1, and `hmi-launch` default orientation still assume ynh960 on rootfs. Platform plan W2 requires helpers and screen seeds in OEM so the same rootfs can pair with different `oem.img`.

`param-update.service` runs **before** `oem-compose`, so display-init cannot rely on `/run/hmi`; it must mount `/oem` and read `manifest.json` directly.

## Goals / Non-Goals

**Goals:**

- Board-specific helpers live under `oem/boards/<id>/helpers/` with profile absolute paths
- `hmi-launch` consumes `/run/hmi/screen.env` when operator orientation is unset
- Screen pack `lcd/` is preferred private1 seed; `/system/etc` remains fallback
- Stack scripts resolve modem helper from profile/`oem.env`, not hardcoded rootfs paths
- oem-compose / display-init / hmi-launch / device App fail hard without OEM (no rootfs fallback pack)
- env-verify asserts `OEM_SOURCE=partition` and OEM helpers

**Non-Goals:**

- Full private1 / ParamUpdate retirement
- W3 linux-sdk trim; W4 sim+virt
- Moving portable stack (`wpa`/`network`/`bluetooth` stack-up, A/B, compose, launch) into OEM
- Renaming every `ynh960-*` verify string in one pass beyond display-init

## Decisions

### D1 — Helper move list (ynh960 only)

| Script | OEM path |
|--------|----------|
| `wifibt-bringup.sh` | `/oem/boards/ynh960/helpers/wifibt-bringup.sh` |
| `usb-otg-mode.sh` | `/oem/boards/ynh960/helpers/usb-otg-mode.sh` |
| display-init | `/oem/boards/ynh960/helpers/display-init.sh` |

Rootfs keeps **thin wrappers** that `exec` the OEM path when present, else legacy copy during one migration window; after move, wrappers are the only rootfs stubs so systemd unit paths need not all change at once. Prefer updating `param-update.service` / usb-otg units to call wrappers under stable `/usr/libexec/...` names that forward to OEM.

**Alternative considered:** Point systemd directly at `/oem/...` — rejected as primary because OEM may be missing during early migration boots; wrappers + profile paths cover both.

### D2 — Modem path resolution in stack scripts

`wifi-stack-up` / `bt-stack-up` resolve bringup in order:

1. `WIFI_MODEM_HELPER` / `BT_MODEM_HELPER` from `/run/hmi/oem.env` if set (compose MAY export)
2. `helpers.wifi_modem` / `helpers.bt_modem` from `/run/hmi/board_profile.json` (simple shell parse or jq if available)
3. Fallback: `/oem/boards/*/helpers/wifibt-bringup.sh` or wrapper `/usr/libexec/bluetooth/wifibt-bringup.sh`

Missing helper → soft-fail for BT (current behavior); Wi-Fi may log and continue or fail as today.

### D3 — Orientation priority in hmi-launch

1. Operator `display.conf` `orientation` (and legacy import)
2. `/run/hmi/screen.env` `SCREEN_DEFAULT_ORIENTATION`
3. **Fail hard** if neither provides a value (no hardcoded landscape_left)

### D4 — LCD seed OEM-only

display-init:

1. Mount `PARTLABEL=oem` at `/oem` if needed
2. Read `/oem/manifest.json` `screen_path` → `$OEM/screens/.../lcd/`
3. Require lcd files; seed private1; **exit non-zero** if missing (no `/system/etc` seed)

### D5 — No rootfs OEM fallback pack

`oem-compose` mounts `/oem` and dies if `manifest.json` is absent or invalid. Do **not** ship `/usr/share/hmi/oem-fallback`. Export `OEM_SOURCE=partition` on success. Device App must not `loadAsset` board_profile when compose/OEM paths are missing (host/desktop may still use assets).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Wi-Fi/BT break if stack still hardcodes old path | Change stack in same change as move; device smoke test |
| display-init before compose cannot use screen.env | Read manifest + lcd/ directly from `/oem` |
| OEM missing → blank screen / no radio | Fail hard in compose / display-init / helpers; operator runs `journalctl -u oem-compose` |
| Silent fallback masking bad OEM | Removed: no oem-fallback, no App asset on device, no /system/etc LCD seed |

## Migration Plan

1. Land compose consumers + lcd dual-read while helpers still on rootfs (slices A–B safe).
2. Copy helpers to OEM, retarget profile + stack, leave wrappers.
3. `build-oem` + `OEM_ONLY=1 make upgrade` then `apply-overlay` + `build-rootfs` + `make upgrade` for wrappers/stack.
4. Remove duplicate full script bodies from rootfs once wrappers-only verified (same change if safe).

## Open Questions

_(none — decisions frozen for implementation)_
