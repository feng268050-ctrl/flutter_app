## Context

- **UI scale** is persisted at `/var/lib/hal/display.conf` key `ui_scale` (`1.0` = physical 1:1; range ~0.5–2.0). OS Settings writes it; product HMI and OS Settings read it via `LinuxUiScale.warmRead()`.
- **OEM screen packs** already declare panel geometry and `default_orientation` in `screen.json`. `oem-compose` writes `/run/hmi/screen.env`; `hmi-launch` uses OEM orientation when `display.conf` has no `orientation` key (runtime fallback; legacy keys are migrated into `display.conf`).
- **Factory reset** deletes operator HAL prefs under `/userdata/hal/` (including `display.conf`) but preserves `properties.ini` and OEM partition. After reset, devices should return to panel-appropriate defaults without manual OS Settings visits.
- **Constraints:** OEM MUST NOT ship `properties.ini` / product tunables; screen defaults are pack metadata, not per-unit identity. Apps MUST NOT hard-code ynh960 rematch factors when `ui_scale=1.0`.

## Goals / Non-Goals

**Goals:**

- Per-screen-pack factory default for `ui_scale`, shipped in OEM and applied automatically on first boot, post–factory-reset, and when `display.conf` exists but omits `ui_scale`.
- Operator / field override via OS Settings remains authoritative once written.
- ynh960 800×1280 pack ships `1.13`; virt emulator pack ships `1.28`.

**Non-Goals:**

- Per-board (non-screen) UI scale — scale follows **screen** pack, not `board_profile.json`.
- Runtime auto-detection of panel size to compute scale (values are curated per `screen_id`).
- Changing `cyber_hal` read path or adding OEM reads inside Dart.
- Migrating existing devices that already have `ui_scale=1.0` written by an operator (one-time manual value is preserved).
- UI Scale slider or HMI Settings exposure.

## Decisions

### 1. `default_ui_scale` in `screen.json`

**Choice:** Optional numeric field `default_ui_scale` on each screen pack (e.g. `1.13`). Omit or set `1.0` when physical 1:1 is correct.

**Alternatives:**

- `ui_scale` without `default_` prefix — rejected; collides mentally with runtime `display.conf` key and breaks parallel with `default_orientation`.
- Put scale in `board_profile.json` — rejected; different panels on the same board may need different scale.

### 2. Export via `screen.env`

**Choice:** `oem-compose` parses `default_ui_scale` and writes `SCREEN_DEFAULT_UI_SCALE=<value>` into `/run/hmi/screen.env` alongside existing `SCREEN_*` keys. Empty / missing → do not export the variable (runtime default remains `1.0`).

**Rationale:** Matches existing OEM→runtime env pattern; keeps compose read-only for `/var/lib/hal` (no ordering fight with `bind-prefs`).

### 3. Seed into `display.conf` before HMI start

**Choice:** In `hmi-launch.sh` (reusing existing `conf_get` / `upsert_conf_key`), when `display.conf` has **no** `ui_scale=` line, read `SCREEN_DEFAULT_UI_SCALE` from `screen.env` and upsert `ui_scale=` if present and valid (clamp 0.5–2.0, same as `LinuxUiScale`).

**Alternatives:**

- Seed in `oem-compose` — rejected; `/var/lib/hal` may not be bound to userdata yet; compose should stay stateless.
- Seed inside `LinuxUiScale.warmRead()` — rejected; mixes OEM shell contract into Dart HAL.
- Runtime-only fallback without persisting — rejected; OS Settings would show 100% while HMI looked scaled until the operator touched the slider.

**Operator wins:** If `ui_scale` is already set (any value), seed step is a no-op.

### 4. Pack values

| Screen pack | `default_ui_scale` | Notes |
|-------------|-------------------|-------|
| `panel-ynh960-800x1280` | `1.13` | Former design-density rematch parity on physical panel |
| `virt` | `1.28` | QEMU virtio 1536×960 — **not** the ynh960 `1.13` value; prior `docs/p32-emulator.md` guidance was wrong |

**Docs:** Replace erroneous “set ~113% on QEMU” copy with `sim_virt` OEM `default_ui_scale=1.28` and first-boot seed behavior.

Future screen packs set their own value at pack authoring time.

### 5. Factory reset interaction

No new factory-reset logic: wiping `display.conf` is sufficient. Next `hmi-launch` re-seeds from OEM when the key is absent.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Devices with stale `ui_scale=1.0` already saved keep old look | Document one-time OS Settings adjustment or delete `ui_scale` line to pick up OEM default; do not overwrite non-empty operator values |
| Invalid JSON number in `screen.json` | Compose logs warning and omits `SCREEN_DEFAULT_UI_SCALE`; device falls back to `1.0` |
| OEM upgrade changes default but operator never set scale | Only applies when key absent — intentional for unset devices |
| Seed runs only at HMI launch | OS Settings launched before first HMI boot on a fresh image is rare; both seats start after `oem-compose`; acceptable |

## Migration Plan

1. Land overlay script + OEM `screen.json` updates; `make build-oem` + `OEM_ONLY=1 make upgrade` (or full flash) for OEM partition refresh.
2. Existing field units: optional `OEM_ONLY=1 make upgrade` + delete `ui_scale` from `display.conf` once if operators want the new default without full reset.
3. Rollback: remove seed block in `hmi-launch` and `default_ui_scale` keys; devices keep last written `display.conf`.

## Open Questions

- None for v1. Per-SKU tuning remains a screen-pack authoring concern when new panels ship.
