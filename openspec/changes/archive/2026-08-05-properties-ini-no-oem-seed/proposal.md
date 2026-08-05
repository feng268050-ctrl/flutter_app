## Why

OEM is board×screen hardware only; per-unit identity already lives in Vendor Storage. Remaining `product.ini` seeds (`camera_ip`, `camera_type`) are product/deployment state that changes when devices ship with different cameras—baking them into `oem.img` (and re-filling blanks on compose) fights that. Rename the runtime file to `properties.ini` so the on-disk name matches host `set-prop` / `del-prop`.

## What Changes

- **BREAKING:** Runtime path `/var/lib/hal/product.ini` → `/var/lib/hal/properties.ini` (HAL, host scripts, bind-prefs, docs).
- **BREAKING:** Remove OEM board `product.ini` seeds and `oem-compose` merge of those seeds. No pack ships default camera/tunable keys.
- Tunables remain operator/factory-owned via `make set-prop` / `del-prop` (and optional future Settings UI writes) into `properties.ini` only.
- Empty / missing `properties.ini` means **unconfigured** for camera host/type: remove App soft default `192.168.1.100` and board_profile `helpers.camera_ip` so blank does not silently reconnect to a stale LAN address.
- One-shot migrate: if runtime `product.ini` exists and `properties.ini` does not, rename/fold on bind-prefs (or first HAL/host read) so existing userdata survives upgrade.
- Retire OpenSpec capability name `product-ini` in favor of `properties-ini`; update cross-specs that still say `product.ini` for tunables (identity wording stays Vendor Storage).

## Capabilities

### New Capabilities

- `properties-ini`: Runtime factory/operator tunables at `/var/lib/hal/properties.ini`; HAL accessors; Device Information empty→`-`; host `set-prop` / `del-prop`; **no** OEM seed; migrate-from-`product.ini`; empty camera keys = unconfigured (no App/profile soft IP default).

### Modified Capabilities

- `product-ini`: **Superseded** — remove requirements (replaced by `properties-ini`).
- `oem-pack`: Drop OEM `product.ini` seed / “not identity authority” seed wording; OEM MUST NOT ship properties/product ini seeds.
- `os-path-layout`: `/var/lib/hal/` basename `product.ini` → `properties.ini`; bind-prefs fold list + migrate old name.
- `linux-settings-persist`: Same HAL prefs basename update.
- `dart-hal`: SysInfo / ProductInfo tunable path and docs refer to `properties.ini`; identity remains Vendor Storage.
- `settings-ui`: Focus scale / device info rows read tunables from `properties.ini` via HAL (identity still Vendor Storage).
- `ip-camera` / `camera-osd-overlay`: Camera host from trimmed `properties.ini` `camera_ip`; absent/empty MUST NOT invent `192.168.1.100` as a silent default (explicit unconfigured / fail-closed or UI prompt—see design).
- `hal-modbus-config`: `control_card_comm_alarm_mode` override sourced from `properties.ini`.
- `host-upgrade-process-library` / `process-library-source-layout` / `host-push-hmi` / `p2-device-demo-ui` / `device-api-origin-selection`: Path and naming updates where they still cite `product.ini` for tunables or stale identity-from-ini wording (identity → Vendor Storage where still wrong).

## Impact

- **OEM:** delete `oem/boards/*/product.ini`; `oem-compose.sh` drop `merge_product_ini`.
- **Overlay:** `bind-prefs.sh` basename list; any prefs bind of `product.ini`.
- **Host:** `scripts/product-ini-common.sh` → properties naming; `set-product-prop.sh` / `del-product-prop.sh`; device listing / docs that mention the path.
- **HAL:** `kProductIniPath` → properties path; reader type names may stay or rename for clarity; tests.
- **App:** `effectiveCameraHost` / OSD / AI camera_type defaults; remove `helpers.camera_ip` from board profiles (App + OEM/sim copies); `OsPaths` comments.
- **Docs:** AGENTS.md rebuild table, README, make-commands, storage-layout, platform-os-oem plan §3.5 closure note.
- **Devices in field:** userdata with old `product.ini` migrated once; after `del-prop CAMERA_IP`, compose no longer re-seeds.
