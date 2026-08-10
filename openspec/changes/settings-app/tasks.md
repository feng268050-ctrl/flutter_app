## 1. Scaffold and multi-app slot

- [ ] 1.1 Create Flutter project `app/settings` (API 3.41.9) with path deps on `cyber_hal`, `cyber_ui`, `cyber_ime`
- [ ] 1.2 Implement minimal shell: flat top-level list placeholders + Exit stub; landscape master-detail / portrait push breakpoint
- [ ] 1.3 Update `ensure-rootfs-apps.sh` / `app-select` docs paths: auto-include `settings` instead of `factory_test`
- [ ] 1.4 Update `verify-rootfs-overlay.sh` to require `/opt/settings` AOT layout (no engine/ICU/JIT) when `app/settings` exists
- [ ] 1.5 Update `Makefile` help, `README.md`, `docs/make-commands.md`, `AGENTS.md` rebuild table, `app/README.md` for `APP=settings`
- [ ] 1.6 Verify `APP=settings make build-app` installs overlay `/opt/settings` without touching `/opt/hmi`

## 2. Lifecycle overlay and HMI entry

- [ ] 2.1 Add `settings-launch.sh` (reuse `hmi-launch.sh` preflight; `BUNDLE=/opt/settings`)
- [ ] 2.2 Add static `settings.service` with `Conflicts=hmi.service`; add reciprocal `Conflicts=settings.service` on `hmi.service`
- [ ] 2.3 Add `/usr/bin/settings` CLI (refuse if HMI active; `--stop-hmi` foreground; Ctrl+C does not start HMI)
- [ ] 2.4 Add `/usr/bin/switch-to-settings` and `/usr/bin/switch-to-hmi`; wire `post-build.sh` symlinks
- [ ] 2.5 Wire Settings Exit → `switch-to-hmi`
- [ ] 2.6 Add HMI explicit System Settings entry → `switch-to-settings` with failure Toast staying on HMI

## 3. HAL probes (Basic Info support)

- [ ] 3.1 Extend `cyber_hal` SysInfo / PlatformVersions for OS page probes (os-release, SELinux, BusyBox, glibc, wpa, BlueZ, OpenSSL, OpenSSH, GStreamer, Flutter pin, Buildroot); soft-fail each field
- [ ] 3.2 Expose Secrets backend status query (`software` | `op-tee`) for Storage without seal/unseal
- [ ] 3.3 Add package unit tests for version string parsers / soft-fail behavior

## 4. Phase B — About / OS / Storage

- [ ] 4.1 Implement About page (Brand / Model / SN from product identity)
- [ ] 4.2 Implement Operating System list summary + 12-row detail page using HAL probes (`—` on missing)
- [ ] 4.3 Implement Storage summary + capacity UI + Secrets Seal status row

## 5. Phase C — Network

- [ ] 5.1 Copy Wi‑Fi settings UI into Settings (shared package or clone; same HAL store)
- [ ] 5.2 Copy Proxy settings UI into Settings
- [ ] 5.3 Implement Ethernet in Settings (from HMI/Demo); then remove HMI Ethernet page/nav/Demo orphans
- [ ] 5.4 Implement Bluetooth in Settings with alias `Brand + " " + Model`; then remove HMI Bluetooth page/nav
- [ ] 5.5 Implement SSH (LAN debug) in Settings; then remove HMI SSH row/nav

## 6. Phase D — Date/time and locale

- [ ] 6.1 Copy Date & Time into Settings
- [ ] 6.2 Copy Country/Region, Language, Unit into Settings (HAL `/var/lib/hal/locale.conf`)

## 7. Phase E — Display, Sound, and Power Mode

- [ ] 7.1 Copy Display (brightness / auto-sleep) into Settings
- [ ] 7.2 Copy Sound (volume / sound effect) into Settings
- [ ] 7.3 Copy Power Mode from HMI General into Settings (performance / balanced; HAL `/var/lib/hal/power.conf`; HMI keeps its copy)

## 8. Phase F — Input migration

- [ ] 8.1 Migrate Keyboard into Settings (Segment + preview); Restart applies Settings seat only (not `start hmi`)
- [ ] 8.2 Migrate Mouse into Settings; remove from HMI
- [ ] 8.3 Migrate USB OTG into Settings; remove from HMI
- [ ] 8.4 Remove HMI Keyboard/Mouse/USB OTG pages, Common Settings Input rows, and related routes

## 9. Phase G — Cleanup and acceptance

- [ ] 9.1 Grep and delete dead HMI routes / Demo sections for migrated features; optionally remove P2 Demo if empty
- [ ] 9.2 Sync `openspec/specs` consumers / related docs (`platform-os-oem-sdk-plan.md` W6 links) for Settings vs factory_test wording
- [ ] 9.3 Run `flutter analyze` on `app/settings`; smoke landscape + portrait navigation
- [ ] 9.4 On-device: HMI → System Settings → Exit round-trip; confirm `/userdata` untouched; confirm migrated rows absent from HMI and present in Settings
- [ ] 9.5 Confirm Bluetooth alias and Secrets Seal status on device; confirm rootfs verify with both `/opt/hmi` and `/opt/settings`
