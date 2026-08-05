## Why

`/usr/libexec/hmi/` became a catch-all while the name implies Flutter/`hmi.service` ownership. Phase 1 carved **`board/`** (identity / serial / seal). Phase 2 carves **`usb/`**, **`ab/`**, **`oem/`**. Remaining clusters—display/Weston, poweroff, LAN ssh-debug, hostname/mdns/serial/verify—are still not UI-owned. Finish the split so **`hmi/`** only holds App/UI helpers.

## What Changes

### Phase 1 — done

- **`/usr/libexec/board/`**: identity + serial + secrets-seal; purge incremental leftovers.

### Phase 2 — usb / ab / oem

- **`/usr/libexec/usb/`**: OTG / gadget / plug-ssh / MTP.
- **`/usr/libexec/ab/`**: A/B slot helpers (`ab-slot-lib`, apply/stream, boot-confirm).
- **`/usr/libexec/oem/`**: `oem-compose`.

### Phase 3 — display / power / ssh + expand board

- **`/usr/libexec/display/`**: display-init, Weston config, orientation, mouse prefs apply.
- **`/usr/libexec/power/`**: `pre-poweroff`, `shutdown`, `pwrkey-poweroff`, `systemctl-poweroff-wrapper`.
- **`/usr/libexec/ssh/`**: LAN OpenSSH debug (`enable-ssh-debug`, `disable-ssh-debug`, `lan-ssh-run`, `ensure-sshd-hostkeys`). USB plug-ssh stays under **`usb/`**.
- **Expand `/usr/libexec/board/`**: `paths.sh`, `lws-hostname`, `device-mdns-advertise`, `serial-console-stty`, `reboot-loader`, `boot-verify`, `env-verify`, `set-performance-mode`, `bind-prefs`.

Hard cut + purge incremental `target/` leftovers each phase. Operator `/usr/bin/<verb-noun>` names stay; only symlink / unit targets move.

### What remains under `/usr/libexec/hmi/` (end state)

Only App/UI-adjacent:

- `hmi-launch.sh`, `hmi-stop-and-wait.sh`
- `push-app-apply-and-restart.sh`
- `debug-app-apply.sh`, `debug-app-run.sh`, `debug-runtime-install.sh`
- `diagnose-hmi.sh`
- `extract-video-frame`

## Capabilities

### New Capabilities

- _(none — extends path-layout ownership)_

### Modified Capabilities

- `os-path-layout`: Full libexec tier set `{wpa,network,bluetooth,board,usb,ab,oem,display,power,ssh,hmi}`; narrow `hmi/` to App/UI only.
- USB / A/B / OEM / ssh-debug / display / poweroff specs that hardcode `/usr/libexec/hmi/…` for moved helpers: retarget.

## Impact

- Overlay: `rootfs-overlay/usr/libexec/{board,usb,ab,oem,display,power,ssh,hmi}/`; units; udev; `post-build.sh`; `purge-retired-rootfs-artifacts.sh`; `verify-rootfs-overlay.sh`.
- OEM helpers / `board_profile` (`ssh_debug` → `ssh/enable-ssh-debug`; display-init calls `board/bind-prefs`; usb-otg calls `usb/*` + `board/paths.sh`).
- Host scripts: prefer `/usr/bin`; retarget remaining absolute libexec paths.
- Docs: `AGENTS.md` convention one-liner; living docs only where they cite moved paths.
- Does **not** rename `/var/lib/*`; does **not** use `/usr/libexec/hal/` for helpers.
