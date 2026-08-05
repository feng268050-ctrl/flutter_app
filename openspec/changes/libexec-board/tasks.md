## Phase 1 — board/ identity cluster (done)

- [x] 1.1 Create `rootfs-overlay/usr/libexec/board/` and move design D1 scripts (`read-product-identity.sh`, `write-product-identity.sh`, `vendor-storage-ids.txt`, `read-device-serial.sh`, `secrets-seal` / CA helper if present under hmi)
- [x] 1.2 Update internal defaults inside moved scripts to `/usr/libexec/board/…`
- [x] 1.3 Update `post-build.sh` `/usr/bin` symlink targets for `read-serial`, `read-identity`, `write-identity`
- [x] 1.4 Grep overlay for absolute `/usr/libexec/hmi/` refs to Phase 1 basenames; retarget
- [x] 2.1 Update `cyber_hal` secrets-seal default / tests
- [x] 2.2 OEM / board JSON only where pointing at Phase 1 moved scripts
- [x] 2.3 Host scripts for identity/serial/secrets
- [x] 3.1–3.3 Docs / vendor-storage path alignment for `board/`
- [x] 4.1–4.4 Verify Phase 1 + purge incremental leftovers

## Phase 2 — usb/ + ab/ + oem/

### 5. Overlay moves

- [x] 5.1 Create `usr/libexec/usb/` and move D7 scripts
- [x] 5.2 Create `usr/libexec/ab/` and move D8 scripts
- [x] 5.3 Create `usr/libexec/oem/` and move `oem-compose.sh`
- [x] 5.4 Update internal cross-calls (incl. ssh-debug → `usb/` plug-ssh once Phase 3 moves ssh, or temporarily from `hmi/`)

### 6. Units, udev, post-build, purge, verify

- [x] 6.1 Retarget units (`usb-otg-role*.service`, `ssh-debug-usb.service`, `ab-boot-confirm.service`, `oem-compose.service`) and udev `99-usb-gadget-state.rules`
- [x] 6.2 Update `post-build.sh` USB operator symlinks
- [x] 6.3 Extend purge for Phase 2 basenames left under `hmi/`
- [x] 6.4 Extend `verify-rootfs-overlay.sh` for `usb/` / `ab/` / `oem/` + stale checks

### 7. Callers and docs (Phase 2)

- [x] 7.1 OEM `usb-otg-mode.sh` calls → `usb/` (and `board/paths.sh` after Phase 3, or keep `hmi/paths.sh` until 9.x)
- [x] 7.2 Host scripts hardcoded `hmi/ab-*` / `hmi/usb-*` / `hmi/oem-compose`
- [x] 7.3–7.4 Partial `AGENTS.md` / `os-path-layout` for Phase 2 tiers (full convention after Phase 3)

## Phase 3 — display/ + power/ + ssh/ + expand board/

### 8. Overlay moves

- [x] 8.1 Create `usr/libexec/display/` and move D11 scripts
- [x] 8.2 Create `usr/libexec/power/` and move D12 scripts
- [x] 8.3 Create `usr/libexec/ssh/` and move D13 scripts
- [x] 8.4 Move D14 scripts into existing `usr/libexec/board/` (`paths.sh`, hostname, mdns, serial-stty, reboot-loader, boot-verify, env-verify)
- [x] 8.5 Update cross-calls (display-init → `display/bind-prefs`; ssh-debug → `usb/` plug-ssh; power wrappers; profile.d serial-stty)

### 9. Units, post-build, purge, verify (Phase 3)

- [x] 9.1 Retarget units (`pwrkey-poweroff`, `ssh-debug-lan`, `serial-stty`, `cpu-performance` if any, systemctl wrapper install path) and profile.d
- [x] 9.2 Update `post-build.sh` symlinks (`change-orientation`, `apply-mouse-settings`, `set-performance-mode`, `enable-ssh-debug`, `disable-ssh-debug`, `verify-boot`, `verify-env`, `reboot-loader`, systemctl wrapper)
- [x] 9.3 Extend purge for all Phase 3 basenames left under `hmi/`
- [x] 9.4 Extend `verify-rootfs-overlay.sh` for `display/` / `power/` / `ssh/` + expanded `board/` + end-state `hmi/` allowlist (or stale denylist)

### 10. Callers and docs (Phase 3)

- [x] 10.1 Update HAL/OEM `ssh_debug` → `/usr/libexec/ssh/enable-ssh-debug.sh`; OEM display-init → `display/bind-prefs` (+ `board/paths` if sourced)
- [x] 10.2 Grep host/docs for remaining hardcoded `hmi/` paths of moved Phase 3 scripts
- [x] 10.3 Finalize `AGENTS.md` convention: `{wpa,network,bluetooth,board,usb,ab,oem,display,power,ssh,hmi}`
- [x] 10.4 Finalize living `os-path-layout` + related specs; archive notes as needed

### 11. End-state verification

- [x] 11.1 Overlay `hmi/` contains only D15 App/UI set
- [x] 11.2 `make apply-overlay` + `make build-rootfs` passes verify with no stale moved basenames under `hmi/`
- [x] 11.3 Spot-check operator `readlink` + key unit ExecStart paths for all new tiers
