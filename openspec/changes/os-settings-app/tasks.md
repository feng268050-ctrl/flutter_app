## 1. Scaffold and multi-app slot

- [x] 1.1 Create Flutter project `app/os_settings` (API 3.41.9) with path deps on `cyber_hal`, `cyber_ui`, `cyber_ime`
- [x] 1.2 Implement shell: flat top-level list (HMI Device Info / General card+nav chrome) + Exit; same list→push layout landscape and portrait (no master-detail)
- [x] 1.3 Update `ensure-rootfs-apps.sh` / `app-select` docs paths: auto-include `os_settings` instead of `factory_test`
- [x] 1.4 Update `verify-rootfs-overlay.sh` to require `/opt/os_settings` AOT layout (no engine/ICU/JIT) when `app/os_settings` exists
- [x] 1.5 Update `Makefile` help, `README.md`, `docs/make-commands.md`, `AGENTS.md` rebuild table, `app/README.md` for `APP=os_settings`
- [x] 1.6 Verify `APP=os_settings make build-app` installs overlay `/opt/os_settings` without touching `/opt/hmi`

## 2. Lifecycle overlay and HMI entry

- [x] 2.1 Add `os-settings-launch.sh` (reuse `hmi-launch.sh` preflight; `BUNDLE=/opt/os_settings`)
- [x] 2.2 Add static `os-settings.service` with `Conflicts=hmi.service`; add reciprocal `Conflicts=os-settings.service` on `hmi.service`
- [x] 2.3 Add `/usr/bin/os-settings` CLI (refuse if HMI active; `--stop-hmi` foreground; Ctrl+C does not start HMI)
- [x] 2.4 Add `/usr/bin/switch-to-os-settings` and `/usr/bin/switch-to-hmi`; wire `post-build.sh` symlinks
- [x] 2.5 Wire OS Settings Exit → `switch-to-hmi`
- [x] 2.6 HMI Device Info → Device SN 5× → `switch-to-os-settings` (failure Toast, stay on HMI); no Common Settings row

## 3. HAL probes (Basic Info support)

- [x] 3.1 Extend `cyber_hal` SysInfo / PlatformVersions for OS page probes (os-release, SELinux, BusyBox, glibc, wpa, BlueZ, OpenSSL, OpenSSH, GStreamer, Flutter pin, Buildroot); soft-fail each field
- [x] 3.2 Expose Secrets backend status query (`software` | `op-tee`) for Storage without seal/unseal
- [x] 3.3 Add package unit tests for version string parsers / soft-fail behavior

## 4. Phase B — About / OS / Storage

- [x] 4.1 Implement About page (Brand / Model / SN from product identity)
- [x] 4.2 Implement Operating System list summary + 12-row detail page using HAL probes (`—` on missing)
- [x] 4.3 Implement Storage summary + capacity UI; Secrets Seal status row on Operating System → Security

## 5. Phase C — Network

- [x] 5.1 Copy Wi‑Fi settings UI into OS Settings (shared package or clone; same HAL store)
- [x] 5.2 Copy Proxy settings UI into OS Settings
- [x] 5.3 Implement Ethernet in OS Settings (from HMI/Demo); then remove HMI Ethernet page/nav/Demo orphans
- [x] 5.4 Implement Bluetooth in OS Settings with alias `Brand + " " + Model`; then remove HMI Bluetooth page/nav
- [x] 5.5 Implement SSH (LAN debug) in OS Settings; then remove HMI SSH row/nav

## 6. Phase D — Date/time and locale

- [x] 6.1 Copy Date & Time into OS Settings
- [x] 6.2 Copy Country/Region, Language, Unit into OS Settings (HAL `/var/lib/hal/locale.conf`)

## 7. Phase E — Display, Sound, and Power Mode

- [x] 7.1 Copy Display (brightness / auto-sleep) into OS Settings
- [x] 7.2 Copy Sound volume into OS Settings; HMI retains volume + sound-effect picker (product installs click samples; OS Settings volume-only per `docs/settings-apps-roles.md`)
- [x] 7.3 Migrate Power Mode from HMI General into OS Settings (performance / balanced; HAL `/var/lib/hal/power.conf`; HMI Settings entry removed; HMI still reads for continuous-paint)

## 8. Phase F — Input migration

- [x] 8.1 Migrate Keyboard into OS Settings (Segment + preview); Restart applies OS Settings seat only (not `start hmi`)
- [x] 8.2 Migrate Mouse into OS Settings; remove from HMI
- [x] 8.3 Migrate USB OTG into OS Settings; remove from HMI
- [x] 8.4 Remove HMI Keyboard/Mouse/USB OTG pages, Common OS Settings Input rows, and related routes

## 9. Phase G — Cleanup and acceptance

- [x] 9.1 Grep and delete dead HMI routes / Demo sections for migrated features; optionally remove P2 Demo if empty
- [x] 9.2 Sync `openspec/specs` consumers / related docs (`platform-os-oem-sdk-plan.md` W6 links) for OS Settings vs factory_test wording
- [x] 9.3 Run `flutter analyze` on `app/os_settings`; smoke list→push navigation (landscape and portrait same shell)
- [ ] 9.4 On-device: HMI → OS Settings → Exit round-trip; confirm `/userdata` untouched; confirm migrated rows absent from HMI and present in OS Settings
- [ ] 9.5 Confirm Bluetooth alias and Secrets Seal status on device; confirm rootfs verify with both `/opt/hmi` and `/opt/os_settings`

## 10. Phase H — Product decisions after initial ship

- [x] 10.1 Ethernet: Wi‑Fi Details–parity IPv4 Address / DNS groups; cable link under switch; remove Configure IP nav pattern; share UI with Wi‑Fi Details
- [x] 10.2 Migrate Power Mode to OS Settings only; HMI removes Settings entry; HMI still reads `power.conf` for continuous-paint
- [x] 10.3 HMI Common regroup: Date & Time before Country/Region; Display + Sound + Camera one card; hide RGB LED row (keep code)
- [x] 10.4 UI Scale: `ui_scale=1.0` = physical 1:1 / no rematch (incl. simulator); OS Settings Display owns write; document ~113% for QEMU/ynh960 parity
- [x] 10.5 Cloud Environment in OS Settings Network; persist `/var/lib/network/cloud.conf`; not in HMI picker
- [x] 10.6 Document persistence boundary: OS Settings MUST NOT use `common-settings.json` (HMI `textSize` only)
- [x] 10.7 Refresh `openspec/changes/os-settings-app` proposal/design/specs/tasks + roles/plan cross-links for the above
