## Why

W1 placed board×screen packs on the OEM partition and exports `/run/hmi`, but board bringup scripts, LCD seed paths, and HMI launch defaults still live in rootfs with ynh960 hardcoding. W2 makes boot/rootfs a common OS by moving board-specific helpers and screen param seeds into OEM and teaching launch/display paths to consume OEM contracts.

## What Changes

- Move ynh960 board helpers (`wifibt-bringup`, `usb-otg-mode`, display-init) into `oem/boards/ynh960/helpers/`; update profile helper paths and stack call sites that currently hardcode `/usr/libexec/...`.
- **BREAKING (default orientation source):** `hmi-launch` requires `display.conf` or `/run/hmi/screen.env`; missing orientation fails hard (no hardcoded default).
- **BREAKING (no OEM fallback):** `oem-compose` fails if `/oem` pack is missing/invalid; remove `/usr/share/hmi/oem-fallback`; display-init seeds private1 from OEM `lcd/` only; device App refuses App-asset board_profile fallback.
- Add screen-pack `lcd/` files; keep `05-display.sh` `/system/etc` install only as unused residue until retired.
- Sync env-verify / verify-rootfs-overlay / docs for fail-hard OEM authority.
- Document `OEM_IMG` / `OEM_ONLY` as environment variables (`.env` + command-line prefix); update `WITH_DOTENV` and host-remote-upgrade spec.

**Out of scope:** linux-sdk trim (W3), sim+virt / UTM (W4), Factory Test App, deleting private1 / ParamUpdate, moving `/opt/hmi` into OEM.

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `oem-pack`: Board helpers live under OEM; screen packs carry `lcd/` seeds; compose `/run/hmi/screen.env` consumed by HMI launch; display-init requires OEM lcd (no fallback).
- `host-remote-upgrade`: `OEM_IMG` / `OEM_ONLY` are environment variables (`.env` + prefix override), not make positional args.
- `product-ini`: `oem-compose` applies OEM `brand` / `model` / `sn` over runtime; other seed keys remain fill-empty-only. Host `make set-prop` / `del-prop` refuse those identity keys.

## Impact

- **OEM:** `oem/boards/ynh960/helpers/*`, `oem/screens/.../lcd/*`, `board_profile.json` helper absolute paths, `screen.json` lcd refs.
- **Rootfs overlay:** `hmi-launch.sh`, display-init, wifi/bt stack-up, usb-otg units, `env-verify.sh`, oem-fallback copies.
- **Docs:** `storage-layout.md`, platform plan W2 status; `Makefile` / `.env.example` / AGENTS for `OEM_IMG` / `OEM_ONLY` env vars.
