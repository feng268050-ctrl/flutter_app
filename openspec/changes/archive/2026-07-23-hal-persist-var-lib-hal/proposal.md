## Why

HAL-owned platform preferences (display/sound, input, datetime, USB debug role, product identity) currently live under `/var/lib/hmi` → `/userdata/hmi`, which conflates **system/HAL state** with **HMI App-only** data. As more Apps share `cyber_hal`, those configs must be subsystem state under `/var/lib/hal` → `/userdata/hal`, not tied to the HMI product App tree. Panel orientation is also shared OS policy (flutter-pi `-o` **or** Weston `transform`) and must live in the same HAL display surface rather than an App-only façade.

## What Changes

- **BREAKING (on-device paths):** Relocate HAL platform preference files from `/var/lib/hmi/` to `/var/lib/hal/` (bound to `/userdata/hal`).
- **BREAKING (file shape):** Fold standalone `display-orientation` into `/var/lib/hal/display.conf` key `orientation` (`portrait` | `landscape`), matching existing `backlight` / `auto_sleep` keys; one-shot import from the legacy file.
- **BREAKING (HAL API):** Reverse the prior “no portable orientation HAL” rule. Add portable **`Orientation`** (panel orientation) under `hal/output/display`, with a Linux backend that persists via `change-orientation` / `display.conf` and applies by restarting `hmi.service` so **both** flutter-pi and Weston stacks pick up the mapping in `hmi-launch.sh`.
- **BREAKING (display-stack stamps):** Move image/runtime embedder stamps from `/etc/hmi/display-stack` and `/run/hmi/display-stack` to **`/etc/display-stack`** and **`/run/display-stack`** (OS/HAL identity, not HMI App paths).
- Add FHS layout + userdata bind for `/var/lib/hal` ↔ `/userdata/hal` alongside existing wpa / network / bluetooth / hmi binds.
- Keep **HMI App-owned** durable state under `/var/lib/hmi/` (e.g. `misc-settings.json`, `advanced-settings.json`, `alarm-logs.db`, push/debug/A-B staging).
- One-shot, idempotent migration: copy known HAL files from `/var/lib/hmi/` (or `/userdata/hmi/`) into `/var/lib/hal/` when the new path is missing, then leave or remove legacy copies per design.
- Migrate App `DisplayOrientationController` façades to `cyber_hal` (thin re-export or delete after cutover).
- Update board shell helpers, `OsPaths`, docs, and OpenSpec path contracts.
- Do **not** move network/Wi‑Fi/BT trees; do **not** relocate App JSON/SQLite stores.

## Capabilities

### New Capabilities

- `hal-display-orientation`: Portable HAL panel orientation API under `hal/output/display` (get/set portrait|landscape; Linux apply is stack-agnostic via launch).

### Modified Capabilities

- `os-path-layout`: Introduce `/var/lib/hal` + `/userdata/hal` bind; reclassify HAL prefs out of `/var/lib/hmi`; extend migration rules; fold orientation into `display.conf`.
- `linux-settings-persist`: Document HAL prefs under `/var/lib/hal/`; App prefs remain under `/var/lib/hmi/`.
- `shell-hw-persist`: Shell apply helpers write HAL prefs under `/var/lib/hal/` (`orientation` in `display.conf`).
- `dart-hal`: Persist cohesion under `/var/lib/hal/`; **remove** “no portable orientation HAL”; include `Orientation` in `hal/output/display`; DisplayStack stamps at `/etc/display-stack` + `/run/display-stack`.
- `boot-splash-display`: Weston stamp path `/etc/display-stack`.
- `linux-datetime`: `datetime.conf` (and legacy import sources) under `/var/lib/hal/`.
- `linux-mouse-settings`: `mouse.conf` under `/var/lib/hal/`.
- `linux-backlight`: `display.conf` backlight key under `/var/lib/hal/`.
- `linux-media-audio`: `sound.conf` volume key under `/var/lib/hal/`.
- `linux-display-orientation`: Preference + launch mapping owned by HAL/`change-orientation`; `display.conf` key `orientation`; applies for flutter-pi **and** Weston.
- `hal-auto-sleep`: `display.conf` `auto_sleep` under `/var/lib/hal/`.
- `hal-button-feedback`: `sound.conf` `button_feedback` under `/var/lib/hal/`.
- `usb-otg-id-role`: `usb-debug` preference under `/var/lib/hal/`.
- `product-ini`: `product.ini` under `/var/lib/hal/`.
- `p2-device-demo-ui`: Device SN / product identity reads `/var/lib/hal/product.ini` (Demo need not expose orientation UI).
- `buildroot-lws-hmi-image`: flutter-pi mouse prefs read from `/var/lib/hal/`.

## Impact

- **Overlay / rootfs:** `paths.sh`, `bind-prefs.sh`, `restore-settings.sh`, `hmi-launch.sh`, `post-build.sh` display-stack stamp, `apply-mouse-settings.sh`, `change-orientation.sh`, USB OTG helpers, `read-device-serial.sh`, MediaMTX product.ini readers, diagnose scripts; `verify-rootfs-overlay.sh`.
- **`packages/cyber_hal`:** New `Orientation` API + Linux/stub backends; `DisplayStackProbe` defaults → `/run/display-stack` + `/etc/display-stack`; preference paths → `/var/lib/hal/…`; README + `docs/hal-portability.md`.
- **`app/hmi`:** `OsPaths.varHal`; replace or thin-wrap `lib/platform/display/*` orientation types; host `set-prop` / `del-prop` / product.ini tooling paths.
- **Unchanged:** App stores under `/var/lib/hmi/`; network/wpa/BT trees; helper location stays `/usr/libexec/hmi/` for this change; in-App temporary media layout rotation (not panel orientation); other `/run/hmi/` App runtime markers (e.g. boot-self-check) stay under `/run/hmi/`.
- **Devices in field:** Need one boot through updated `bind-prefs` / migration so existing prefs survive the rename; new rootfs rewrites display-stack stamps at the non-HMI paths.
