## Why

Product rootfs currently carries ~42 MiB of multi-vendor Wi‑Fi/BT firmware (bcm/syn/rtl/hcd kitchen sink) while **ynh960** only needs ~0.5 MiB of **AIC8800D80** blobs. Radio modules are motherboard-local, central to **RED** certification, and already brought up **after HMI** via OEM `wifi_modem` / `bt_modem`. Firmware therefore belongs in an **OEM radio pack** (on-demand per board), not in the shared embedded OS image.

## What Changes

- Add an OEM **radio pack** layout under the board pack (firmware keep-set + small manifest) for AIC8800D80 on ynh960 (shareable by other SKUs that use the same module).
- Point `wifibt-bringup` at OEM as the **authoritative** firmware source (symlink/bind into driver search paths as needed).
- Stop `post-wifibt` / Innohi from copying the full multi-chip firmware tree into rootfs; drop the AP6256/`bcmdhd` side path that exists only to keep post-wifibt non-empty.
- Keep **`aic8800_*.ko` with the kernel/OS** (not OEM) — ABI-coupled to the running Image.
- Optional post-build / verify guards so rootfs cannot silently re-accumulate `fw_bcm*` / kitchen-sink firmware.
- **Non-goals:** relocating wpa/BlueZ into OEM; putting `.ko` into OEM; jumping Wi‑Fi chip families in this change; implementing during the in-flight `kernel-61-lts-rebase`.

## Capabilities

### New Capabilities

- `oem-radio-pack`: Board OEM radio firmware pack layout, manifest, bringup resolution rules, and on-demand packaging for combo Wi‑Fi/BT module blobs (RED-scoped).

### Modified Capabilities

- `oem-pack`: Board helpers / pack contents MAY include a `radio/` subtree; `build-oem` MUST include it when present.
- `buildroot-lws-hmi-image`: Product rootfs MUST NOT ship the multi-vendor Wi‑Fi/BT firmware kitchen sink; AIC module firmware for product boards comes from OEM.
- `linux-wifi`: Modem bring-up MUST load combo firmware from the OEM radio pack path (not assume a full `/vendor/etc/firmware` dump).

## Impact

- OEM: `oem/boards/ynh960/` (and shared radio assets if factored), `board_profile.json`, `helpers/wifibt-bringup.sh`, `scripts/build-oem.sh`.
- Rootfs assembly: `post-wifibt` / Innohi firmware copy, `board/ynh960_defconfig` `RK_WIFIBT_*` placeholders, optional `post-build.sh` / `verify-rootfs-overlay.sh` / `env-verify`.
- **Sequencing:** Do **not** implement while `kernel-61-lts-rebase` is active — that change owns `overlay/kernel/**`, FIT rebuild, and Wi‑Fi/BT smoke on the new tip. This change’s code landing waits until that work is archived (or explicitly sequenced after its kernel tip is stable). Drafting artifacts only is OK in parallel.
- Runtime: existing deferred modem port after HMI; missing OEM radio → soft-fail Wi‑Fi/BT (UI stays up).
