## Context

`scripts/build-app.sh` / `push-app.sh` previously hardcoded `APP_DIR=app/lws_hmi` and `DEST=…/opt/hmi`. Product launch (`hmi.service`) and verify scripts assume `/opt/hmi`. A second Flutter project `app/factory_test` shares AOT/meta-flutter layout but must not become the default daily path. Future products (e.g. `cnc_hmi`) need the same on-device prefix.

## Goals / Non-Goals

**Goals:**

- Single `APP` Make/env knob (default `lws_hmi`) for build / push / rootfs ensure.
- **Naming convention:** HMI apps use suffix `_hmi` and always install to `/opt/hmi` so `hmi.service` works; one rootfs ≤ one HMI + optional `factory_test`.
- `build-rootfs` auto-includes `factory_test` when `app/factory_test` exists.
- Non-HMI overlay trees survive `build-app` for a different non-HMI app; HMI builds replace shared `/opt/hmi`.

**Non-Goals:**

- Creating `app/factory_test` / `app/cnc_hmi` themselves or factory_test launch systemd unit.
- Changing `hmi.service` / `hmi-launch.sh` to multi-bundle or multi-path.
- `debug-app` / `l10n` multi-app (remain `lws_hmi` until a follow-up).
- Renaming `/opt/hmi` → `/opt/lws_hmi`.

## Decisions

### 1. APP id = directory under `app/`

- `APP=lws_hmi` → `app/lws_hmi`; `APP=cnc_hmi` → `app/cnc_hmi`
- Reject empty / path traversal / missing `app/$APP/pubspec.yaml`

### 2. Install prefix mapping (`*_hmi` → `/opt/hmi`)

| APP pattern | Overlay / device prefix |
|-------------|-------------------------|
| `*_hmi` (e.g. `lws_hmi`, `cnc_hmi`) | `/opt/hmi` |
| any other (e.g. `factory_test`) | `/opt/<APP>` |

One rootfs therefore has a single HMI payload at `/opt/hmi` (whichever `APP=*_hmi` was last ensured/built) plus optional `/opt/factory_test`.

### 3. Shared resolver script

`scripts/app-select.sh` exports:

- `APP`, `APP_DIR`, `APP_OPT_NAME` (`hmi` or `$APP`)
- `OVERLAY_APP`, `DEVICE_APP`
- `APP_IS_HMI` (true when name ends with `_hmi`; `APP_IS_PRODUCT_HMI` alias for compat)

### 4. Companions and ship assets

- MediaMTX / ffmpeg / AI: when `APP_IS_HMI`
- `prepare-hmi-ship-assets`: when `$APP_DIR` has process-library or control-board firmware sources (uses `APP_DIR` from env)

### 5. push-app behavior

- `APP_IS_HMI`: staging + `push-app-apply-and-restart.sh` (restart `hmi.service`)
- Other APP: upload to `/opt/<APP>`; **do not** restart `hmi.service`

### 6. build-rootfs ensure set

1. Ensure selected `APP` overlay tree has `lib/libapp.so` (invoke `build-app` when missing).
2. If `app/factory_test` exists: ensure `/opt/factory_test` likewise.
3. Selecting another `*_hmi` replaces `/opt/hmi` content (same path).

### 7. verify-rootfs-overlay

- Mandatory `/opt/hmi` for product images.
- If `app/factory_test` exists: also require `/opt/factory_test` release layout (no engine/JIT).

## Risks / Trade-offs

- [Switching HMI product leaves stale assets until rebuild] → Mitigation: `APP=<x>_hmi make build-app` replaces `/opt/hmi`.
- [push non-HMI with no service] → Acceptable; unit out of scope.
- [Stale factory_test] → Same as HMI; rebuild with `APP=factory_test make build-app`.

## Migration Plan

- No device migration: `/opt/hmi` unchanged for `lws_hmi`.
- Host: omit `APP` → identical to today.
- Future `cnc_hmi`: `APP=cnc_hmi make build-app` / `build-rootfs`.

## Open Questions

- None blocking; factory_test launch path deferred.
