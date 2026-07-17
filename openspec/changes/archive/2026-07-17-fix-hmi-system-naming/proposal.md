## Why

This firmware is an **embedded appliance OS** (Buildroot rootfs + systemd + flutter-pi). Today runtime layout has two problems:

1. **Product branding on-device** — paths and units use `lws-hmi`, coupling the OS to the LWS Git repo.
2. **Monolithic state tree** — Wi‑Fi, Bluetooth, Ethernet, backlight, volume, mouse, USB debug, and app staging all live in one flat **`/var/lib/hmi/`** directory. Real Linux images store mutable state under **`/var/lib/<subsystem>/`** (e.g. `/var/lib/wpa_supplicant/`, `/var/lib/bluetooth/`, `/var/lib/network/`).

We must fix **both** in one change: remove product prefixes **and** split state/helpers by OS subsystem, following FHS 3.0 + systemd conventions.

## What Changes

### A. Subsystem `/var/lib/` split (**BREAKING**)

Replace the single `/var/lib/hmi/` tree with **per-subsystem FHS state directories**, each bind-mounted from `/userdata/<subsystem>/`:

| Subsystem | Runtime state path | Files (from legacy flat tree) |
|-----------|-------------------|-------------------------------|
| **Wi‑Fi / wpa** | `/var/lib/wpa_supplicant/` | `wifi-wanted`, `wpa_supplicant.conf`, `wpa_supplicant.log`, `wlan0-ipv4`, `wlan0-resolv.conf` |
| **Ethernet** | `/var/lib/network/` | `eth0-wanted`, `eth0-ipv4`, `eth0-resolv.conf` |
| **Bluetooth** | `/var/lib/bluetooth/` | `bt-wanted`, `bt-a2dp-sink`, `bt-a2dp-volume` (+ existing BlueZ adapter trees) |
| **HMI / UI platform** | `/var/lib/hmi/` | `display-orientation`, `mouse.conf`, `backlight-brightness`, `media-volume`, `http-proxy`, `usb-debug`, `timezone`, push/debug/A-B staging logs |

`/var/run/wpa_supplicant` (ctrl socket) unchanged.

### B. Subsystem `/usr/libexec/` split (**BREAKING**)

Move helpers out of `/usr/libexec/hmi/` into subsystem libexec tiers:

| Tier | Path | Examples |
|------|------|----------|
| Wi‑Fi | `/usr/libexec/wpa/` | `run-wpa.sh`, `wifi-stack-up.sh`, `wlan0-dhcp.sh` |
| Ethernet | `/usr/libexec/network/` | `apply-eth0.sh`, `eth0-dhcp.sh`, `eth0-link.sh` |
| Bluetooth | `/usr/libexec/bluetooth/` | `bt-stack-up.sh`, `bt-a2dp-sink-up.sh`, `bt-pair-agent.sh` |
| HMI platform | `/usr/libexec/hmi/` | `hmi-launch.sh`, `change-backlight.sh`, `restore-settings.sh`, `bind-prefs.sh`, push/debug/A-B/USB-OTG |

Operator **`/usr/bin/<verb-noun>`** commands unchanged; symlinks may target any libexec tier.

### C. Config + app bundle (unchanged paths, de-branded)

- `/etc/hmi/` → **`/etc/hmi/`** (e.g. `flutter-engine.version`)
- `/opt/hmi/` — keep

### D. Functional systemd units (**BREAKING**)

| Legacy | Target |
|--------|--------|
| `cpu-performance.service` | `cpu-performance.service` |
| `pwrkey-poweroff.service` | `pwrkey-poweroff.service` |
| `settings-restore.service` | `settings-restore.service` |
| `wlan-wpa.service` | `wlan-wpa.service` |
| `wlan-dhcp.service` | `wlan-dhcp.service` |
| `eth0-network.service` | `eth0-network.service` |
| `ssh-debug-lan.service` | `ssh-debug-lan.service` |
| `ssh-debug-usb.service` | `ssh-debug-usb.service` |
| `lws-hmi-usb-otg-role*.service` | `usb-otg-role.service` / `usb-otg-role-boot.service` |
| `ab-boot-confirm.service` | `ab-boot-confirm.service` |
| `serial-stty.service` | `serial-stty.service` |

Only the primary UI daemon remains **`hmi.service`**.

### E. Build tree neutral names

- `rootfs-overlay/` → **`rootfs-overlay/`**
- Board/SDK hooks de-prefixed (`post-build.sh`, `06-systemd.sh`, `patch-*.sh`, …)

### F. OTA migration

`bind-prefs.sh` SHALL (idempotent, before restore):

1. If legacy **`/userdata/lws-hmi/`** exists → split-move files into `/userdata/wpa_supplicant/`, `/userdata/network/`, `/userdata/bluetooth/`, `/userdata/hmi/` per mapping table.
2. Create symlinks: `/var/lib/wpa_supplicant`, `/var/lib/network`, `/var/lib/bluetooth`, `/var/lib/hmi` → corresponding userdata trees.
3. Remove stale `/var/lib/lws-hmi` symlink.

### G. Docs + verify

Update `AGENTS.md`, `docs/storage-layout.md`, `verify-rootfs-overlay.sh`, `env-verify.sh`, Dart platform paths, flutter-pi patches, active OpenSpec deltas.

**Keep unchanged:** Git repo name, Buildroot defconfig (`*_lws_hmi_defconfig`), chip configs, host "lws-hmi device" debug phrasing, archived OpenSpec.

## Capabilities

### New Capabilities

- `os-path-layout`: FHS subsystem layout (`/var/lib/*`, `/usr/libexec/*`), functional systemd units, build-vs-runtime naming, monolithic-tree migration.

### Modified Capabilities

- `linux-settings-persist`: Multi-subsystem bind-mounts; `settings-restore.service` reads split paths.
- `linux-wifi`: State under `/var/lib/wpa_supplicant/`; helpers under `/usr/libexec/wpa/`.
- `linux-ethernet`: State under `/var/lib/network/`; helpers under `/usr/libexec/network/`.
- `linux-bluetooth`: Prefs under `/var/lib/bluetooth/`; helpers under `/usr/libexec/bluetooth/`.
- `shell-hw-persist`, `linux-backlight`, `linux-display-orientation`, `linux-media-audio`, `linux-mouse-settings`, `linux-datetime`: HW/UI prefs under `/var/lib/hmi/`; helpers under `/usr/libexec/hmi/`.
- `hmi-systemd-boot`, `buildroot-lws-hmi-image`, `host-push-hmi`, `linux-lan-ssh-debug`, `usb-plug-ssh-debug`, `usb-otg-id-role`, `ab-firmware-slots`: paths + unit names.

## Impact

- **Device runtime**: Four `/var/lib/*` bind targets; four libexec tiers; 12 renamed units; all scripts/Dart/tests updated.
- **Bluetooth persistence**: Binding `/var/lib/bluetooth` to userdata also preserves BlueZ pairing cache across rootfs upgrade (improvement over today).
- **OTA**: File-level split migration from monolithic `/userdata/lws-hmi/`.
- **Kernel build**: DTSI and Kconfig fragments renamed `lws-hmi-*` → `ynh960-*` (tasks §7).
- **Out of scope**: NetworkManager/connman adoption.
