## 1. OEM screen pack metadata

- [x] 1.1 Add `default_ui_scale: 1.13` to `oem/screens/panel-ynh960-800x1280/screen.json`
- [x] 1.2 Add `default_ui_scale: 1.28` to `oem/screens/virt/screen.json`

## 2. oem-compose export

- [x] 2.1 Parse optional `default_ui_scale` from `screen.json` in `oem-compose.sh` `write_screen_env` (or helper)
- [x] 2.2 Write `SCREEN_DEFAULT_UI_SCALE=<value>` into `/run/hmi/screen.env` when valid; log and skip when missing or invalid

## 3. Boot seed into display.conf

- [x] 3.1 In `hmi-launch.sh`, when `display.conf` has no `ui_scale` key, read `SCREEN_DEFAULT_UI_SCALE` from `screen.env`
- [x] 3.2 Upsert clamped value (0.5–2.0) into `display.conf`; no-op when operator key already present
- [x] 3.3 Run seed before embedder start so `LinuxUiScale.warmRead()` sees the OEM default

## 4. Verification and docs

- [x] 4.1 Extend `scripts/env-verify.sh` (or OEM verify) to assert ynh960 `default_ui_scale` is `1.13` and virt is `1.28`
- [x] 4.2 Update `docs/hal-portability.md` and `docs/p32-emulator.md` — per-pack OEM defaults (ynh960 `1.13`, `sim_virt` `1.28`); remove wrong QEMU ~113% guidance; factory reset re-seeds
- [x] 4.3 Manual smoke: delete `ui_scale` from `display.conf` → ynh960 shows ~113%; `make emulator` (sim_virt) shows ~128% — HMI matches without manual slider change

## 5. Ship OEM partition

- [x] 5.1 `make build-oem` and `OEM_ONLY=1 make upgrade` (or full `make build-img` + flash) so devices pick up updated `screen.json` in `/oem`
