## Context

`/usr/libexec/hmi/` accumulated platform helpers under a UI-named tier. Phase 1 moved identity/serial/seal to `board/`. Phases 2–3 finish ownership: USB, A/B, OEM, display, power, LAN ssh, and remaining board appliance helpers leave `hmi/` so that directory only means App/UI.

Constraints: FHS libexec tiers; operator `/usr/bin/<verb-noun>` stable; hard cut + purge Buildroot incremental `target/` leftovers; OEM may keep board-specific wrappers under `/oem/…` that call rootfs libexec.

## Goals / Non-Goals

**Goals:**

- End-state tiers: `wpa`, `network`, `bluetooth`, `board`, `usb`, `ab`, `oem`, `display`, `power`, `ssh`, `hmi`.
- `hmi/` holds only launch/push/debug/diagnose/`extract-video-frame`.
- Document durable placement rule; verify + purge prevent dual homes.

**Non-Goals:**

- Renaming `/var/lib/*` or inventing `/usr/libexec/hal/` for helpers.
- Changing A/B, Vendor Storage, OEM pack, or USB gadget semantics.
- Long-term dual install under `hmi/` and new tiers.
- Renaming operator command basenames.

## Decisions

### D1 — Phase 1 `board/` (done)

Identity read/write + ID map, `read-device-serial`, `secrets-seal` (+ CA).

### D7 — Phase 2 `usb/`

`usb-otg-mode.sh`, `usb-gadget-usb-state.sh`, `usb-plug-ssh-*.sh`, `usb-mtp-*.sh`.  
`/usr/bin`: `start-usb-ssh`, `stop-usb-ssh`, `recover-usb-ssh`, `diagnose-usb-ssh`, `usb-otg-mode`.

### D8 — Phase 2 `ab/` (not `ota/`)

`ab-slot-lib.sh`, `ab-upgrade-apply.sh`, `ab-upgrade-stream.sh`, `ab-boot-confirm.sh`.  
Matches `ab-*` units; product OTA can share or add later.

### D9 — Phase 2 `oem/`

`oem-compose.sh` ← `oem-compose.service`.

### D11 — Phase 3 `display/`

| Artifact | Why |
|----------|-----|
| `ynh960-display-init.sh` | Boot display / userdata mount orchestration stub |
| `weston-hmi-config.sh` | Weston client config |
| `change-orientation.sh` | Display orientation |
| `apply-mouse-settings.sh` | Weston mouse prefs |

`/usr/bin`: `change-orientation`, `apply-mouse-settings`.

### D12 — Phase 3 `power/`

| Artifact | Why |
|----------|-----|
| `pre-poweroff.sh` | Crash-safe pre-poweroff |
| `shutdown.sh` | Shutdown helper |
| `pwrkey-poweroff.sh` | Power-key unit |
| `systemctl-poweroff-wrapper.sh` | `systemctl` poweroff wrapper |

Units / `/usr/bin/systemctl` wrapper retarget as today, paths under `power/`.

### D13 — Phase 3 `ssh/` (LAN OpenSSH; not USB)

| Artifact | Why |
|----------|-----|
| `enable-ssh-debug.sh` / `disable-ssh-debug.sh` | LAN ssh-debug + may call `usb/` plug-ssh |
| `lan-ssh-run.sh` | `ssh-debug-lan.service` |
| `ensure-sshd-hostkeys.sh` | Host-key bake / ensure |

`board_profile` / HAL `ssh_debug` → `/usr/libexec/ssh/enable-ssh-debug.sh`.  
`/usr/bin`: `enable-ssh-debug`, `disable-ssh-debug`.

### D14 — Phase 3 expand `board/`

| Artifact | Why |
|----------|-----|
| `paths.sh` | Shared path helpers (OEM usb-otg sources this) |
| `lws-hostname.sh` | Appliance hostname |
| `device-mdns-advertise.sh` | mDNS advertise |
| `serial-console-stty.sh` | Serial console stty (+ `serial-stty.service` / profile.d) |
| `reboot-loader` | RockUSB loader reboot helper |
| `boot-verify.sh` / `env-verify.sh` | Platform verify (`verify-boot` / `verify-env`) |
| `set-performance-mode.sh` | CPU/DMC/GPU governors + cpuidle |
| `bind-prefs.sh` | `/var/lib/*` → `/userdata/*` state binds (invoked from display-init after userdata mount) |

`/usr/bin`: `set-performance-mode` (among other board operators).

### D15 — End-state `hmi/` only

`hmi-launch.sh`, `hmi-stop-and-wait.sh`, `push-app-apply-and-restart.sh`, `debug-app-*.sh`, `debug-runtime-install.sh`, `diagnose-hmi.sh`, `extract-video-frame`.

### D2 — Tier map

| Tier | Role |
|------|------|
| `wpa` / `network` / `bluetooth` | Dedicated stacks |
| `board` | Board contracts + appliance helpers (identity, seal, paths, hostname, mdns, serial-stty, verify, reboot-loader, performance, bind-prefs) |
| `usb` | USB gadget / OTG / plug-ssh / MTP |
| `ab` | A/B upgrade |
| `oem` | OEM compose |
| `display` | Display / Weston / orientation / mouse apply |
| `power` | Poweroff / shutdown |
| `ssh` | LAN OpenSSH debug / host keys |
| `hmi` | Flutter UI launch, App push/debug, diagnose, frame extract |

Rejected for helpers: `hal/`, `scripts/`, `misc/`, vague `helpers/`.

### D3 / D4 — PATH + hard cut

Keep `/usr/bin/<verb-noun>`; change targets only. No permanent `hmi/` → new-tier symlink farm. Purge retired basenames in `purge-retired-rootfs-artifacts.sh` every phase.

### D5 / D6 — Overlay + docs

Overlay mirrors device. Update `os-path-layout`, `AGENTS.md`, related capability specs, `verify-rootfs-overlay.sh` (all new tiers + stale-under-`hmi/` checks).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Large absolute-path surface (OEM, units, udev, profile.d) | Phased hard lists; grep gates; purge + verify |
| HAL `ssh_debug` / OEM display-init half-upgrade | Ship rootfs + App/OEM together; prefer `/usr/bin` where exists |
| Too many tiers | Prefer clear ownership over fewer catch-alls; merge only if a tier stays empty |

## Migration Plan

1. Phase 1 on tree.
2. Implement Phase 2 then Phase 3 (or one rootfs if applying together): move → retarget → purge → verify.
3. `make apply-overlay` → `make build-rootfs` → `make upgrade`.
4. Confirm operator `readlink`, unit ExecStart, empty stale set under `hmi/` for moved basenames.
5. Rollback: prior rootfs.

## Open Questions

- Whether `diagnose-hmi` later gains a `diag/` sibling with `boot-verify`/`env-verify` (currently verify stays in `board/`, diagnose in `hmi/`).
