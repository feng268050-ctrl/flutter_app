## Context

Today HAL platform prefs share `/var/lib/hmi` → `/userdata/hmi` with HMI App state (misc/advanced JSON, alarm SQLite, push/debug staging). Network/Wi‑Fi/BT already use separate `/var/lib/{network,wpa_supplicant,bluetooth}` trees. `cyber_hal` is the shared Linux HAL for multiple Apps; keeping system prefs under the HMI tree blocks that sharing and mislabels ownership.

Panel orientation was previously declared “not a portable HAL API” and left as an App façade (`DisplayOrientationController` → `change-orientation`). That is wrong for multi-App: both flutter-pi (`-o`) and Weston (`transform`) already share one preference + `hmi-launch.sh` mapping; the shared owner is HAL.

Shell helpers under `/usr/libexec/hmi/` and `cyber_hal` Linux backends both hardcode `/var/lib/hmi/…` for display/sound/input/datetime/USB/product paths. `bind-prefs.sh` creates four userdata binds; there is no `hal` tree yet.

## Goals / Non-Goals

**Goals:**

- Introduce `/var/lib/hal` → `/userdata/hal` as the durable home for HAL/system platform preferences.
- Leave HMI App-only durable state under `/var/lib/hmi`.
- Fold orientation into `display.conf` and expose portable HAL `Orientation` under `hal/output/display`, stack-agnostic for flutter-pi and Weston.
- Relocate display-stack stamps to `/etc/display-stack` and `/run/display-stack`.
- Migrate existing devices idempotently on first boot with the new image.
- Update Dart defaults, shell helpers, host product tooling, docs, and OpenSpec contracts so one path is the source of truth.

**Non-Goals:**

- Moving helpers from `/usr/libexec/hmi/` to `/usr/libexec/hal/` (optional follow-up).
- Changing other preference formats beyond the orientation fold (`product.ini`, `usb-debug`, existing `*.conf` key styles).
- Moving App stores (`misc-settings.json`, `advanced-settings.json`, `alarm-logs.db`) or debug/push/A-B staging.
- Relocating network/Wi‑Fi/BT state or HTTP proxy (`/var/lib/network/proxy.conf`).
- Android / non-Linux HAL backends.
- Hot-reload of panel orientation without HMI restart (v1 still restarts `hmi.service`).
- Requiring P2 Demo UI controls for orientation (product Settings MAY use the HAL API).

## Decisions

### D1 — Ownership split: HAL vs HMI App

| Under `/var/lib/hal/` | Under `/var/lib/hmi/` (unchanged) |
|----------------------|-----------------------------------|
| `display.conf` (`backlight`, `auto_sleep`, `orientation`) | `misc-settings.json` |
| `sound.conf` | `advanced-settings.json` |
| `mouse.conf`, `keyboard.conf` | `alarm-logs.db` |
| `datetime.conf` (+ one-shot import from legacy `time-sync-mode` / `timezone` if still present under old tree) | `push-app-staging/`, `debug-*`, A-B confirm logs |
| `usb-debug` | |
| `product.ini` | |

**Rationale:** Anything `cyber_hal` (or board restore) applies as OS/platform policy is HAL-owned. Product App UX prefs and App databases stay HMI-owned.

**Alternative:** Keep everything under `/var/lib/hmi` with a `hal/` subdirectory — rejected; peers are already top-level subsystem dirs (`network`, `wpa_supplicant`, `bluetooth`).

### D2 — Canonical constants: `VAR_HAL` / `OsPaths.varHal`

- Shell: add `VAR_HAL=/var/lib/hal`, `USERDATA_HAL=/userdata/hal` to `paths.sh`; helpers source those instead of hardcoding.
- App: add `OsPaths.varHal`; keep `OsPaths.varHmi` for App stores.
- `cyber_hal`: default preference path strings use `/var/lib/hal/…` (injectable for tests).

**Alternative:** Single shared path module package — deferred; App + shell + HAL already have parallel constants.

### D3 — Bind + migrate in `bind-prefs.sh`

1. `bind_one "$VAR_HAL" "$USERDATA_HAL"` with the other four binds.
2. After binds, **fold HAL files** from `$USERDATA_HMI` / `$VAR_HMI` into `$USERDATA_HAL` when the destination file is absent (`cp -an` style for the known basename list). Do not overwrite newer HAL files.
3. Optionally remove migrated basenames from the HMI tree after successful copy (prefer remove to avoid dual writers); if remove is risky on first cut, leave orphans but all writers MUST target HAL only.

**Chosen:** migrate-then-remove known HAL basenames from HMI tree after successful copy (idempotent; missing source is OK). Known list includes `display.conf`, `sound.conf`, `mouse.conf`, `keyboard.conf`, `datetime.conf`, `usb-debug`, `product.ini`, legacy `display-orientation` / `time-sync-mode` / `timezone` (orientation and datetime keys folded into conf files when needed).

### D4 — Shell helpers stay under `/usr/libexec/hmi/` for this change

Apply/restore/launch scripts keep location; only preference **directories** change to `VAR_HAL`. Avoids a wide rename of units and PATH symlinks.

### D5 — Host tooling (`set-prop` / `del-prop` / `read-device-serial`)

Product identity path becomes `/var/lib/hal/product.ini`. Host scripts and Makefile help/README/AGENTS path mentions update in the same change.

### D6 — No parallel “hal-alt” tree

`cyber_hal` README currently warns against inventing `/var/lib/hal-alt/...`. Replace that guidance with the real `/var/lib/hal/` contract; boot restore remains `BoardBindings.restorePersistedSettings` / `settings-restore.service` reading the new paths.

### D7 — Fold `display-orientation` into `display.conf` key `orientation`

Standalone file `display-orientation` (raw `portrait` / `landscape` token) becomes `orientation=<token>` inside `display.conf`, alongside `backlight` and `auto_sleep`.

- **Writers:** `change-orientation.sh` upserts `orientation=` (mouse-style `key=value`); MUST NOT recreate the standalone file as the primary path.
- **Readers:** `hmi-launch.sh` reads `orientation` from `display.conf`; if missing, one-shot import from legacy `display-orientation` (under `/var/lib/hal/` or leftover `/var/lib/hmi/`), then default `landscape`.
- **Migration in `bind-prefs`:** when folding trees, if `display.conf` lacks `orientation` and a legacy `display-orientation` file exists, append/upsert into `display.conf` and remove the standalone file.

**Rationale:** Same cohesion as `datetime.conf` / existing display keys; one display policy file for launch and HAL output.

**Alternative:** Keep standalone under `/var/lib/hal/display-orientation` — rejected; user preference and existing conf pattern favor merge.

### D8 — Portable HAL `Orientation` under `hal/output/display`

Reverse D19 / “No portable orientation HAL”.

| Piece | Choice |
|-------|--------|
| Public type | `Orientation` (modes `landscape` / `portrait`) under `package:cyber_hal/output/display/orientation.dart`, exported from `output/display.dart` |
| Linux backend | Call `change-orientation` (injectable); warm-read `display.conf` key `orientation` (legacy file import OK); apply via restart `hmi.service` (same as today’s App façade) |
| Stack mapping | **Not** in Dart — `hmi-launch.sh` already maps preference → flutter-pi `-o` **or** Weston `transform`; HAL MUST NOT branch on `DisplayStack` for set/get |
| Stub | `StubOrientation` for host/sim |
| App | Delete or thin-wrap `app/hmi/lib/platform/display/*` after cutover |
| Capability | Optional; omit on headless / no-display profiles |

**Rationale:** Cross-App, cross-stack panel policy is exactly HAL’s job; shell+launch already implement the compatibility layer.

**Alternatives:** Keep App-only controller — rejected (user decision). Put API under `hal/sys_info` — rejected (it is output/display policy, not inventory). Hot-apply without restart — deferred.

### D9 — Display-stack stamps leave `/etc/hmi` and `/run/hmi`

Embedder identity is OS/HAL, not HMI App state:

| Role | New path | Writer |
|------|----------|--------|
| Image stamp | `/etc/display-stack` | rootfs `post-build.sh` |
| Runtime stamp | `/run/display-stack` | `hmi-launch.sh` (or future non-HMI launcher) |

`DisplayStackProbe` defaults SHALL use these paths (priority: runtime → image → `WAYLAND_DISPLAY` fallback unchanged). Probe MAY one-shot fall back to legacy `/run/hmi/display-stack` and `/etc/hmi/display-stack` when the new files are absent (partial upgrade). New writers MUST NOT create stamps under `/etc/hmi/` or `/run/hmi/`.

**Rationale:** Same ownership story as `/var/lib/hal` — stack choice is appliance-wide.

**Alternative:** Keep under `/etc/hmi` because launch is still `hmi-launch.sh` — rejected; path namespace should not imply App ownership.

## Risks / Trade-offs

- **[Risk] Dual-path reads during partial upgrade** (old App + new overlay or vice versa) → Mitigation: migration copies into HAL; new code only writes HAL; document that App and rootfs should ship together (`build-app` + `build-rootfs` / `upgrade`).
- **[Risk] Missed hardcodes** leave some writers on HMI tree → Mitigation: ripgrep `/var/lib/hmi` for HAL filenames; add verify script checks for expected HAL paths where practical; unit tests assert default paths.
- **[Risk] Removing migrated files breaks a forgotten reader** → Mitigation: keep migration list explicit and small; diagnose script lists both trees during transition if needed.
- **[Trade-off] Helpers remain under `libexec/hmi`** while state is `var/lib/hal` → Acceptable inconsistency short-term; naming follow-up separate.
- **[Trade-off] Orientation apply still restarts HMI** → Acceptable for v1; document like keyboard layout.

## Migration Plan

1. Ship overlay with `VAR_HAL` bind + migrate list + updated helpers (including orientation upsert into `display.conf`).
2. Ship `cyber_hal` Orientation API + path defaults; migrate App façades.
3. On device: `apply-overlay` → `build-rootfs` → `upgrade` (prefer rootfs when bind/migration changes); `build-app` + `push-app` for App/HAL.
4. First boot: `bind-prefs` creates `/userdata/hal`, copies known files from `/userdata/hmi`, folds orientation, removes sources.
5. Rollback: older image still reads `/var/lib/hmi`; if migration removed files, operator would need to copy back from `/userdata/hal` — document that downgrade after migration requires manual copy. Prefer not downgrading across this change without backup.

## Open Questions

None blocking — migration remove-vs-keep resolved as remove-after-copy for the known HAL basename list; Orientation API naming locked to `Orientation` under `output/display`.
