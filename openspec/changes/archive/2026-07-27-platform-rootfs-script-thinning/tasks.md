## 1. Slice A — hmi-launch reads /run/hmi

- [x] 1.1 Update `hmi-launch.sh` orientation resolution: display.conf → `/run/hmi/screen.env` → last-resort default
- [x] 1.2 Review `weston-hmi-config.sh`; change only if it hardcodes board orientation independently

## 2. Slice B — screen pack LCD dual-read

- [x] 2.1 Add `oem/screens/panel-ynh960-800x1280/lcd/` with LCD param files from `board/`
- [x] 2.2 Update `screen.json` `lcd_param_files` to pack-relative `lcd/` paths
- [x] 2.3 Teach display-init to require OEM screen `lcd/` via `/oem/manifest.json` (fail hard; no `/system/etc` seed)
- [x] 2.4 Update `docs/storage-layout.md` (and related notes) for OEM-only lcd authority
- [x] 2.5 Remove `/usr/share/hmi/oem-fallback`; oem-compose / device App fail without `/oem`

## 3. Slice C — helpers → OEM

- [x] 3.1 Copy `wifibt-bringup.sh`, `usb-otg-mode.sh`, display-init into `oem/boards/ynh960/helpers/`
- [x] 3.2 Point OEM `board_profile.json` helpers at `/oem/boards/ynh960/helpers/...`
- [x] 3.3 Retarget `wifi-stack-up` / `bt-stack-up` to resolve modem helper from profile/oem.env
- [x] 3.4 Replace rootfs full scripts with thin wrappers (or update systemd) so units still start
- [x] 3.5 Update `env-verify.sh` paths for OEM helpers

## 4. Docs and verify

- [x] 4.1 Mark W2 in-progress/done notes in `docs/platform-os-oem-sdk-plan.md` as appropriate
- [x] 4.3 Document `OEM_IMG` / `OEM_ONLY` as env vars (`.env`, WITH_DOTENV, host-remote-upgrade spec)
- [x] 4.4 Host `set-prop` / `del-prop` refuse `brand` / `model` / `sn` (OEM identity only)
