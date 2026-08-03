## Why

The tree currently hardcodes `app/lws_hmi` → overlay `/opt/hmi` for `make build-app` / `push-app` / rootfs bake. A second Flutter app (`app/factory_test`) needs the same AOT packaging path without forking Make targets, while daily HMI iteration stays `APP`-free (default `lws_hmi`). Future product HMIs (e.g. `cnc_hmi`) must share `/opt/hmi` so `hmi.service` can launch them.

## What Changes

- Add Make/env `APP` (default `lws_hmi`) for `build-app`, `push-app`, and `build-rootfs`.
- **Convention:** HMI apps are named with suffix `_hmi` and always install to `/opt/hmi`. Non-HMI apps (e.g. `factory_test`) install to `/opt/<APP>`. One rootfs has at most one HMI tree at `/opt/hmi` plus optional `factory_test`.
- `build-app` / `push-app` operate only on the selected `APP` (non-HMI overlay trees left intact; HMI builds replace `/opt/hmi`).
- `build-rootfs` always ensures the selected `APP` is present in overlay; if `app/factory_test` exists, also ensure and bake `/opt/factory_test` without requiring `APP=factory_test`.
- Product companions (MediaMTX / AI / ffmpeg) install for all `*_hmi` apps; ship-asset prepare runs when that app has process-library / firmware sources.
- Docs: Makefile `help`, README Make commands, `AGENTS.md` rebuild table.

## Capabilities

### New Capabilities

- `multi-app-build-select`: Host Make/scripts select which Flutter app under `app/` to build, push, and include in rootfs; `_hmi` suffix → `/opt/hmi`; factory_test auto-include rules.

### Modified Capabilities

- `buildroot-lws-hmi-image`: Rootfs verify MAY assert `/opt/factory_test` when that app source exists; `/opt/hmi` remains the single product HMI path for any `APP=*_hmi`.

## Impact

- `Makefile` (`build-app`, `push-app`, `build-rootfs`, `help`)
- `scripts/build-app.sh`, `scripts/push-app.sh`, `scripts/hmi-bundle-common.sh`, `scripts/app-select.sh`, `scripts/ensure-rootfs-apps.sh`
- `scripts/verify-rootfs-overlay.sh` (optional factory_test checks)
- `README.md`, `AGENTS.md`
- Board apply script for any `*_hmi`; non-HMI push copies tree without `hmi.service` restart
