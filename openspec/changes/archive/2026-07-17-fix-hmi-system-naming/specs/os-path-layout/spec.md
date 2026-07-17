## ADDED Requirements

### Requirement: Subsystem state under separate var lib directories

The appliance OS SHALL NOT store Wi‑Fi, Ethernet, Bluetooth, and HMI platform mutable state in a single flat directory. Each subsystem MUST use its own FHS `/var/lib/<name>/` tree:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi: `wifi-wanted`, `wpa_supplicant.conf`, `wpa_supplicant.log`, `wlan0-ipv4`, `wlan0-resolv.conf`
- **`/var/lib/network/`** — Ethernet: `eth0-wanted`, `eth0-ipv4`, `eth0-resolv.conf`
- **`/var/lib/bluetooth/`** — Bluetooth: HMI prefs `bt-wanted`, `bt-a2dp-sink`, `bt-a2dp-volume` at the directory top level alongside BlueZ adapter subdirectories
- **`/var/lib/hmi/`** — UI platform: `display-orientation`, `mouse.conf`, `backlight-brightness`, `media-volume`, `http-proxy`, `usb-debug`, `timezone`, and push/debug/A-B staging artifacts

The legacy monolithic path **`/var/lib/hmi/`** MUST NOT exist on shipped rootfs.

#### Scenario: Wi-Fi conf in wpa_supplicant state dir

- **WHEN** P1+ rootfs is produced and Wi‑Fi is configured
- **THEN** `wpa_supplicant.conf` lives under `/var/lib/wpa_supplicant/` not under `/var/lib/hmi/` or a generic `/var/lib/hmi/`

#### Scenario: eth0 prefs in network state dir

- **WHEN** eth0 static config is saved
- **THEN** `eth0-ipv4` lives under `/var/lib/network/`

#### Scenario: Mouse prefs in hmi state dir only

- **WHEN** mouse settings are persisted
- **THEN** `mouse.conf` lives under `/var/lib/hmi/` and not under `/var/lib/wpa_supplicant/` or `/var/lib/network/`

### Requirement: Subsystem helpers under usr libexec tiers

Programs invoked by systemd units or daemons (not user PATH commands) MUST live under **`/usr/libexec/<subsystem>/`**, not `/usr/lib/`:

- **`/usr/libexec/wpa/`** — Wi‑Fi stack scripts
- **`/usr/libexec/network/`** — Ethernet scripts
- **`/usr/libexec/bluetooth/`** — Bluetooth stack scripts
- **`/usr/libexec/hmi/`** — UI launch, HW change helpers, `restore-settings.sh`, `bind-prefs.sh`, push/debug/A-B/USB helpers

Legacy **`/usr/libexec/hmi/`** MUST NOT exist on shipped rootfs.

#### Scenario: Wi-Fi helper location

- **WHEN** `wlan-wpa.service` runs
- **THEN** it invokes scripts under `/usr/libexec/wpa/` not `/usr/libexec/hmi/`

#### Scenario: restore-settings orchestrates split paths

- **WHEN** `settings-restore.service` runs after boot
- **THEN** `restore-settings.sh` under `/usr/libexec/hmi/` reads Wi‑Fi markers from `/var/lib/wpa_supplicant/`, eth0 from `/var/lib/network/`, BT from `/var/lib/bluetooth/`, and HW/UI prefs from `/var/lib/hmi/`

### Requirement: Userdata bind per subsystem

After `/userdata` is mounted, the image SHALL bind each subsystem state directory to a persistent userdata subtree via symlink:

- `/var/lib/wpa_supplicant` → `/userdata/wpa_supplicant`
- `/var/lib/network` → `/userdata/network`
- `/var/lib/bluetooth` → `/userdata/bluetooth`
- `/var/lib/hmi` → `/userdata/hmi`

Full-system A/B upgrade MUST NOT format userdata or delete these trees.

#### Scenario: Four bind symlinks after boot

- **WHEN** userdata is mounted and `bind-prefs.sh` completes
- **THEN** all four `/var/lib/*` paths above are symlinks into `/userdata/`

### Requirement: No lws-hmi prefix on device runtime

No on-device path segment, systemd unit basename, udev rule, or config drop-in filename SHALL use the **`lws-hmi`** product prefix. Product/repo identity is reserved for build host, Git, and Buildroot defconfig only.

#### Scenario: Overlay verify rejects legacy layout

- **WHEN** `verify-rootfs-overlay.sh` runs
- **THEN** it fails if `/var/lib/lws-hmi`, `/usr/lib/lws-hmi`, or any `lws-hmi-*.service` is present

### Requirement: OS integration systemd units use functional names

systemd units for CPU governors, settings restore, network stacks, USB debug, A/B confirm, and serial setup SHALL use functional basenames (`wlan-wpa.service`, `settings-restore.service`, …). The primary UI daemon unit SHALL remain **`hmi.service`**.

#### Scenario: Wi-Fi unit functional name

- **WHEN** rootfs overlay is inspected
- **THEN** `wlan-wpa.service` exists and `wlan-wpa.service` does not

### Requirement: Operator commands remain FHS user binaries

Operator commands SHALL remain **`/usr/bin/<verb-noun>`** without product prefix. Symlinks MAY target scripts in any `/usr/libexec/<subsystem>/` tier.

#### Scenario: change-backlight on PATH

- **WHEN** operator runs `change-backlight 75`
- **THEN** `/usr/bin/change-backlight` invokes `/usr/libexec/hmi/change-backlight.sh`

### Requirement: Monolithic legacy userdata migration

On upgrade from images that used `/userdata/lws-hmi/`, the image SHALL split-move files into the subsystem userdata trees per the documented mapping, idempotently, before `settings-restore.service` runs. An empty legacy directory MAY be removed afterward.

#### Scenario: Wi-Fi creds survive split migration

- **WHEN** device had `/userdata/lws-hmi/wpa_supplicant.conf` before upgrade
- **THEN** after `bind-prefs.sh`, `/var/lib/wpa_supplicant/wpa_supplicant.conf` contains the same networks

#### Scenario: Backlight pref lands in hmi tree

- **WHEN** device had `/userdata/lws-hmi/backlight-brightness` before upgrade
- **THEN** after migration `/var/lib/hmi/backlight-brightness` contains the same value

### Requirement: Build overlay uses neutral OS build names

Build-time overlay source SHALL be named `rootfs-overlay/` with neutral post-build hook basenames. Product prefixes MUST NOT appear in flashed rootfs paths.

#### Scenario: Repository overlay path

- **WHEN** developer inspects board overlay directory
- **THEN** it is named `rootfs-overlay/` not `rootfs-overlay/`
