## Context

**Today:** one symlink `/var/lib/lws-hmi` → `/userdata/lws-hmi/` holds ~30+ unrelated files — Wi‑Fi creds, eth0 config, BT prefs, mouse.conf, push-app staging, debug logs, etc. Helpers all sit in `/usr/libexec/hmi/`. This is a product junk drawer, not an OS layout.

**Target:** behave like a small Linux distro — each long-lived stack owns its **FHS state directory** and **libexec helpers**, same pattern as `/var/lib/bluetooth` + `bluetoothd`, `/var/lib/wpa_supplicant` on Debian-derived images.

## Goals / Non-Goals

**Goals:**

- Split monolithic prefs into **`/var/lib/wpa_supplicant/`**, **`/var/lib/network/`**, **`/var/lib/bluetooth/`**, **`/var/lib/hmi/`**.
- Split helpers into matching **`/usr/libexec/{wpa,network,bluetooth,hmi}/`**.
- Functional systemd unit names; remove all `lws-hmi` runtime branding.
- Multi-tree userdata bind + idempotent migration from legacy flat tree.
- Update verify, Dart, docs, specs in one wave.

**Non-Goals:**

- Git repo / defconfig / chip config renames.
- Replacing custom Wi‑Fi/eth scripts with NetworkManager or connman.

## Decisions

### 1. `/var/lib/` subsystem map

| Path | Owner / precedent | Contents |
|------|-------------------|----------|
| `/var/lib/wpa_supplicant/` | Matches common Linux wpa_supplicant state dir | Wi‑Fi wanted marker, `wpa_supplicant.conf`, log, wlan0 IPv4/DNS |
| `/var/lib/network/` | Embedded ifupdown/systemd-network convention | eth0 wanted, IPv4, resolv |
| `/var/lib/bluetooth/` | **BlueZ upstream** (already used for adapter cache) | Add HMI prefs (`bt-wanted`, `bt-a2dp-*`) as **top-level files** beside `XX:XX:…/` adapter dirs — no collision |
| `/var/lib/hmi/` | Primary UI daemon (FHS `/var/lib/<app>`) | Orientation, mouse, backlight, media volume, http-proxy, usb-debug, timezone, push/debug/A-B artifacts |

**Rejected:** keeping a second flat `/var/lib/hmi/` for network state — perpetuates the junk-drawer model under a shorter name.

**Rejected:** `/var/lib/wpa/` — prefer **`wpa_supplicant`** to align with upstream/tooling expectations.

### 2. `/usr/libexec/` subsystem map

| Path | Scripts |
|------|---------|
| `/usr/libexec/wpa/` | `run-wpa.sh`, `wifi-stack-up.sh`, `wifi-stack-down.sh`, `wlan0-dhcp.sh`, `wlan0-static.sh` |
| `/usr/libexec/network/` | `apply-eth0.sh`, `eth0-dhcp.sh`, `eth0-static.sh`, `eth0-link.sh` |
| `/usr/libexec/bluetooth/` | `bt-stack-up.sh`, `bt-stack-down.sh`, `bt-a2dp-*.sh`, `bt-*-agent*.sh`, `bt-trust-paired.sh`, … |
| `/usr/libexec/hmi/` | `hmi-launch.sh`, `change-*.sh`, `apply-mouse-settings.sh`, `restore-settings.sh`, `bind-prefs.sh`, push/debug/A-B/USB-OTG/verify/ssh helpers |

`restore-settings.sh` stays in **`/usr/libexec/hmi/`** as cross-subsystem orchestrator; it reads from each `/var/lib/*` path.

`/usr/bin/<verb-noun>` symlinks created by `post-build.sh` point to the correct libexec tier per command.

### 3. Userdata bind strategy

After `/userdata` is mounted, `bind-prefs.sh` ensures:

```
/userdata/wpa_supplicant/  →  /var/lib/wpa_supplicant
/userdata/network/         →  /var/lib/network
/userdata/bluetooth/       →  /var/lib/bluetooth
/userdata/hmi/             →  /var/lib/hmi
```

Each pair is a symlink (same pattern as today, multiplied). OTA must never wipe `/userdata/{wpa_supplicant,network,bluetooth,hmi}`.

**Side effect:** BlueZ pairing cache now survives rootfs letter swap (today only HMI BT *prefs* on userdata survived; adapter cache was on rootfs).

### 4. Legacy migration (`/userdata/lws-hmi/` → split)

Idempotent file moves (preserve content, do not overwrite newer split files):

| Legacy file | Destination |
|-------------|-------------|
| `wifi-wanted`, `wpa_supplicant.conf`, `wpa_supplicant.log`, `wlan0-ipv4`, `wlan0-resolv.conf` | `/userdata/wpa_supplicant/` |
| `eth0-wanted`, `eth0-ipv4`, `eth0-resolv.conf` | `/userdata/network/` |
| `bt-wanted`, `bt-a2dp-sink`, `bt-a2dp-volume` | `/userdata/bluetooth/` |
| Everything else (orientation, mouse, backlight, volume, http-proxy, usb-debug, push/debug/A-B, `audio/`, …) | `/userdata/hmi/` |

After migration: remove empty `/userdata/lws-hmi/`, drop `/var/lib/lws-hmi` symlink.

### 5. systemd + build naming

Unchanged from prior proposal: functional unit names (`wlan-wpa.service`, …); neutral build tree (`rootfs-overlay/`, `post-build.sh`).

Three-tier model:

| Tier | Scope | Examples |
|------|-------|----------|
| **FHS runtime** | Device | `/var/lib/wpa_supplicant/`, `/usr/libexec/network/` |
| **Functional units** | Device | `wlan-wpa.service`, `settings-restore.service` |
| **Build / repo** | Host | `lws-hmi/`, `*_lws_hmi_defconfig` |

### 6. Dart / env constants

Introduce small path constants (or shared module) per subsystem to avoid scattered string literals:

- `WpaStateDir = '/var/lib/wpa_supplicant'`
- `NetworkStateDir = '/var/lib/network'`
- `BluetoothStateDir = '/var/lib/bluetooth'`
- `HmiStateDir = '/var/lib/hmi'`

### 7. Verification

`verify-rootfs-overlay.sh` SHALL fail if:

- `/var/lib/lws-hmi` or `/usr/lib/lws-hmi` present in overlay
- Any `lws-hmi-*.service` remains
- Expected subsystem dirs/libexec tiers missing
- Seed files still under old monolithic overlay path

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Missed path literal after split | Grep + verify script; Dart constants |
| Migration mis-files edge-case | Explicit mapping table in `bind-prefs.sh`; device test plan |
| BlueZ dir layout clash | HMI prefs only as **top-level** files in `/var/lib/bluetooth/` |
| Larger diff than rename-only | Mechanical; tasks grouped by subsystem |
| Downgrade to old firmware | One-way migration doc; factory flash to reset |

## Migration Plan

1. Restructure overlay directory layout (var/lib/*, usr/libexec/*).
2. Rewrite `bind-prefs.sh` + migration.
3. Update all scripts, units, Dart, verify, docs.
4. `make apply-overlay` → `make build-rootfs` → `make upgrade`.
5. Validate: prefs in split dirs; Wi‑Fi/eth/BT/backlight survive upgrade.

## Open Questions

- **`http-proxy` in `/var/lib/hmi/` vs `/etc/hmi/`** — keep in `/var/lib/hmi/` (writable, may contain credentials); revisit if we add root-only `/etc/hmi/` defaults.
- **Preset filename** — `99-appliance.preset` vs numbered only.
