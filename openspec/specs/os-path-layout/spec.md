# os-path-layout Specification

## Purpose

On-device runtime layout for the ynh960 appliance OS: FHS-aligned subsystem state under `/var/lib/*`, helpers under `/usr/libexec/*`, userdata bind mounts, and no `lws-hmi` product prefix on flashed rootfs paths.
## Requirements
### Requirement: Subsystem state under separate var lib directories

The appliance OS SHALL NOT store Wi‑Fi, Ethernet, Bluetooth, HAL platform, and HMI App mutable state in a single flat directory. Each subsystem MUST use its own FHS `/var/lib/<name>/` tree:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi: `wifi-wanted`, `wpa_supplicant.conf`, `wpa_supplicant.log`, `wlan0-ipv4`, `wlan0-resolv.conf`
- **`/var/lib/network/`** — Ethernet: `eth0-wanted`, `eth0-ipv4`, `eth0-resolv.conf`; system proxy `proxy.conf`
- **`/var/lib/bluetooth/`** — Bluetooth: HMI prefs `bt-wanted`, `bt-a2dp-sink`, `bt-a2dp-volume` at the directory top level alongside BlueZ adapter subdirectories
- **`/var/lib/hal/`** — HAL / system platform prefs: `mouse.conf`, `keyboard.conf`, `display.conf` (keys `backlight` / `auto_sleep` / `orientation`), `sound.conf`, `datetime.conf`, `power.conf` (key `mode` = `performance` / `balanced`), `properties.ini`. OTG mode MUST NOT live here: session file is **`/run/usb-otg.mode`**. Stale **`usb-otg.conf`** / **`usb-debug`** MUST be removed by `bind-prefs` when present. Legacy basename **`product.ini`** SHALL be renamed to **`properties.ini`** when the latter is absent (see `properties-ini` migrate requirement).
- **`/var/lib/hmi/`** — HMI App-owned state: `common-settings.json`, `misc-settings.json`, `advanced-settings.json`, `alarm-logs.db`, push/debug/A-B staging artifacts

The legacy monolithic path **`/var/lib/lws-hmi/`** MUST NOT exist on shipped rootfs.

#### Scenario: Wi-Fi conf in wpa_supplicant state dir

- **WHEN** P1+ rootfs is produced and Wi‑Fi is configured
- **THEN** `wpa_supplicant.conf` lives under `/var/lib/wpa_supplicant/` not under `/var/lib/lws-hmi/` or a generic monolithic prefs tree

#### Scenario: Mouse prefs in hal state dir only

- **WHEN** mouse settings are persisted
- **THEN** `mouse.conf` lives under `/var/lib/hal/` and not under `/var/lib/hmi/`, `/var/lib/wpa_supplicant/`, or `/var/lib/network/`

#### Scenario: OTG mode is session tmpfs

- **WHEN** OTG mode is chosen by the App or auto-host
- **THEN** it lives under `/run/usb-otg.mode` as `mode=…` and MUST NOT persist under `/var/lib/hal/usb-otg.conf` or `/var/lib/hal/usb-debug`

#### Scenario: App misc prefs stay under hmi

- **WHEN** Common Settings → Misc preferences are persisted
- **THEN** they live under `/var/lib/hmi/misc-settings.json` and MUST NOT be written under `/var/lib/hal/`

#### Scenario: App common prefs stay under hmi

- **WHEN** Common Settings Language or Unit preferences are persisted
- **THEN** they live under `/var/lib/hmi/common-settings.json` and MUST NOT be written under `/var/lib/hal/` or into `misc-settings.json`

#### Scenario: Power mode uses power.conf under hal

- **WHEN** an operator selects balanced via Power Mode settings or `set-power-mode`
- **THEN** `/var/lib/hal/power.conf` contains `mode=balanced` and MUST NOT rely on App JSON as the sole authority

### Requirement: Subsystem helpers under usr libexec tiers

Programs invoked by systemd units or daemons (not user PATH commands) MUST live under **`/usr/libexec/<subsystem>/`**, not `/usr/lib/`:

- **`/usr/libexec/wpa/`** — Wi‑Fi stack scripts
- **`/usr/libexec/network/`** — Ethernet scripts
- **`/usr/libexec/bluetooth/`** — Bluetooth stack scripts
- **`/usr/libexec/board/`** — Board/platform helpers: product identity + Vendor Storage ID map, `read-device-serial`, Secrets seal helpers, shared `paths.sh`, hostname / mDNS / serial-console stty, `reboot-loader`, `boot-verify` / `env-verify`, `set-performance-mode` / `set-power-mode` (CPU/DMC/GPU power profiles), `bind-prefs` (userdata state binds)
- **`/usr/libexec/usb/`** — USB OTG / gadget / plug-ssh / MTP
- **`/usr/libexec/ab/`** — A/B slot upgrade helpers
- **`/usr/libexec/oem/`** — OEM compose (`oem-compose`)
- **`/usr/libexec/display/`** — Display / Weston / orientation / mouse apply
- **`/usr/libexec/power/`** — Poweroff / shutdown / power-key / systemctl poweroff wrapper
- **`/usr/libexec/ssh/`** — LAN OpenSSH debug helpers and sshd host-key ensure (not USB plug-ssh)
- **`/usr/libexec/hmi/`** — Flutter UI launch / stop, App push/debug, `diagnose-hmi`, `extract-video-frame` only

Legacy **`/usr/lib/lws-hmi/`** MUST NOT exist on shipped rootfs. Helpers listed under `/usr/libexec/{board,usb,ab,oem,display,power,ssh}/` MUST NOT remain installed only under `/usr/libexec/hmi/` as their canonical home (temporary one-release compatibility symlinks MAY exist; dual long-term homes MUST NOT). Relocating into `/usr/libexec/hal/` is NOT part of this layout (HAL **state** remains `/var/lib/hal/`).

#### Scenario: Wi-Fi helper location

- **WHEN** `wlan-wpa.service` runs
- **THEN** it invokes scripts under `/usr/libexec/wpa/` not `/usr/libexec/lws-hmi/`

#### Scenario: Product identity helpers live under board

- **WHEN** inspecting the shipped rootfs after Phase 1+
- **THEN** `read-product-identity.sh`, `write-product-identity.sh`, and `vendor-storage-ids.txt` SHALL exist under `/usr/libexec/board/`
- **AND** `/usr/bin/read-identity` and `/usr/bin/write-identity` SHALL resolve to those scripts (or wrappers that exec them)

#### Scenario: read-serial lives under board

- **WHEN** inspecting `/usr/bin/read-serial` on the shipped rootfs
- **THEN** it SHALL target `/usr/libexec/board/read-device-serial.sh`

#### Scenario: USB plug-ssh helpers live under usb

- **WHEN** inspecting the shipped rootfs after Phase 2
- **THEN** `usb-plug-ssh-start.sh` / `usb-plug-ssh-stop.sh` SHALL exist under `/usr/libexec/usb/`
- **AND** `ssh-debug-usb.service` SHALL ExecStart/Stop those paths

#### Scenario: A/B helpers live under ab

- **WHEN** inspecting `ab-boot-confirm.service` after Phase 2
- **THEN** its ExecStart SHALL target `/usr/libexec/ab/ab-boot-confirm.sh`

#### Scenario: oem-compose lives under oem

- **WHEN** inspecting `oem-compose.service` after Phase 2
- **THEN** its ExecStart SHALL target `/usr/libexec/oem/oem-compose.sh`

#### Scenario: bind-prefs lives under board

- **WHEN** inspecting the shipped rootfs after Phase 3
- **THEN** `bind-prefs.sh` SHALL exist under `/usr/libexec/board/`

#### Scenario: set-performance-mode lives under board

- **WHEN** inspecting `cpu-performance.service` after Phase 3
- **THEN** its ExecStart SHALL target `/usr/libexec/board/set-performance-mode.sh` (or the same script exposed as `set-power-mode.sh`)

#### Scenario: set-power-mode operator command

- **WHEN** inspecting `/usr/bin/set-power-mode` on the shipped rootfs after this change
- **THEN** it SHALL resolve to the board helper that applies `performance` / `balanced` profiles

#### Scenario: poweroff wrapper lives under power

- **WHEN** inspecting `/usr/bin/systemctl` after Phase 3 on images that install the poweroff wrapper
- **THEN** it SHALL resolve to a helper under `/usr/libexec/power/` (not `/usr/libexec/hmi/`)

#### Scenario: LAN ssh-debug lives under ssh

- **WHEN** inspecting `ssh-debug-lan.service` after Phase 3
- **THEN** its ExecStart SHALL target `/usr/libexec/ssh/lan-ssh-run.sh`
- **AND** `/usr/bin/enable-ssh-debug` SHALL target `/usr/libexec/ssh/enable-ssh-debug.sh`

#### Scenario: hmi tier is App/UI only

- **WHEN** listing `/usr/libexec/hmi/` on the shipped rootfs after Phase 3
- **THEN** it SHALL NOT contain USB, A/B, OEM compose, display/Weston, poweroff, LAN ssh-debug, or board identity/verify helpers as canonical homes

### Requirement: Platform helper defaults prefer libexec/board or usr/bin

`cyber_hal` defaults for board helpers that implement platform identity or Secrets seal SHALL use either **`/usr/bin/<verb-noun>`** (preferred for identity) or **`/usr/libexec/board/…`**. They MUST NOT hard-require `/usr/libexec/hmi/…` as the only path for those helpers after this change.

#### Scenario: Secrets seal default under board

- **WHEN** HAL Secrets uses the default on-device seal helper path
- **THEN** that default SHALL be under `/usr/libexec/board/` (or an equivalent `/usr/bin` symlink to it)

#### Scenario: Identity still via PATH names

- **WHEN** HAL loads product brand/model/sn via helpers
- **THEN** it SHALL invoke `/usr/bin/read-identity` and/or `/usr/bin/read-serial` (symlink targets under `/usr/libexec/board/`)

### Requirement: LAN ssh-debug under ssh may call usb

LAN OpenSSH debug helpers live under `/usr/libexec/ssh/`. When they start or stop USB plug-ssh, they MUST invoke canonical helpers under `/usr/libexec/usb/` (or `/usr/bin` symlinks), not a second copy under `hmi/` or `ssh/`.

#### Scenario: enable-ssh-debug starts plug-ssh via usb tier

- **WHEN** `enable-ssh-debug.sh` starts USB plug-ssh
- **THEN** it SHALL exec `/usr/libexec/usb/usb-plug-ssh-start.sh` (or `/usr/bin/start-usb-ssh`)

### Requirement: HAL ssh_debug helper path

`board_profile` / HAL `ssh_debug` enable helper SHALL default to `/usr/libexec/ssh/enable-ssh-debug.sh` (or `/usr/bin/enable-ssh-debug`) after Phase 3. It MUST NOT require `/usr/libexec/ssh/enable-ssh-debug.sh` as the only path.

#### Scenario: sim/ynh960 profile ssh_debug

- **WHEN** inspecting shipped or sim `board_profile` ssh_debug after Phase 3
- **THEN** the enable helper path SHALL be under `/usr/libexec/ssh/` or `/usr/bin/enable-ssh-debug`

### Requirement: Userdata bind per subsystem

After `/userdata` is mounted, the image SHALL bind each subsystem state directory to a persistent userdata subtree via symlink:

- `/var/lib/wpa_supplicant` → `/userdata/wpa_supplicant`
- `/var/lib/network` → `/userdata/network`
- `/var/lib/bluetooth` → `/userdata/bluetooth`
- `/var/lib/hal` → `/userdata/hal`
- `/var/lib/hmi` → `/userdata/hmi`

Full-system A/B upgrade MUST NOT format userdata or delete these trees.

#### Scenario: Five bind symlinks after boot

- **WHEN** userdata is mounted and `bind-prefs.sh` completes
- **THEN** all five `/var/lib/*` paths above are symlinks into `/userdata/`

### Requirement: No lws-hmi prefix on device runtime

No on-device path segment, systemd unit basename, udev rule, or config drop-in filename SHALL use the **`lws-hmi`** product prefix. Product/repo identity is reserved for build host, Git, and Buildroot defconfig only.

#### Scenario: Overlay verify rejects legacy layout

- **WHEN** `verify-rootfs-overlay.sh` runs
- **THEN** it fails if `/var/lib/lws-hmi`, `/usr/lib/lws-hmi`, or any `lws-hmi-*.service` is present

### Requirement: OS integration systemd units use functional names

systemd units for CPU governors, settings restore, network stacks, USB debug, A/B confirm, and serial setup SHALL use functional basenames (`wlan-wpa.service`, `settings-restore.service`, …). The primary UI daemon unit SHALL remain **`hmi.service`**.

#### Scenario: Wi-Fi unit functional name

- **WHEN** rootfs overlay is inspected
- **THEN** `wlan-wpa.service` exists and `lws-hmi-wpa.service` does not

### Requirement: Operator commands remain FHS user binaries

Operator commands SHALL remain **`/usr/bin/<verb-noun>`** without product prefix. Symlinks MAY target scripts in any `/usr/libexec/<subsystem>/` tier.

#### Scenario: change-backlight on PATH

- **WHEN** operator runs `change-backlight 75`
- **THEN** `/usr/bin/change-backlight` invokes `/usr/libexec/hmi/change-backlight.sh`

### Requirement: Monolithic legacy userdata migration

On upgrade from images that used `/userdata/lws-hmi/`, the image SHALL split-move files into the subsystem userdata trees per the documented mapping, idempotently, before `settings-restore.service` runs. An empty legacy directory MAY be removed afterward.

On upgrade from images that stored HAL prefs under `/userdata/hmi/`, `bind-prefs.sh` SHALL one-shot fold the known HAL basenames into `/userdata/hal/` when the destination file is absent, then remove those basenames from the HMI tree. Known HAL basenames include at least: `display.conf`, `sound.conf`, `mouse.conf`, `keyboard.conf`, `datetime.conf`, `properties.ini`, legacy `product.ini` (folded then renamed to `properties.ini` when needed), legacy `display-orientation`, and legacy `time-sync-mode` / `timezone` if still present. When folding `display-orientation`, if `/userdata/hal/display.conf` lacks `orientation`, the image SHALL upsert `orientation=<token>` into `display.conf` and remove the standalone file. Stale OTG files **`usb-otg.conf`** and **`usb-debug`** under HMI or HAL userdata SHALL be deleted (OTG mode is session-only).

#### Scenario: Stale usb-debug removed

- **WHEN** device had `/userdata/hal/usb-debug` or `/userdata/hal/usb-otg.conf`
- **THEN** after migration those files are removed and OTG mode is not restored from them

#### Scenario: product.ini renamed to properties.ini

- **WHEN** `/userdata/hal/product.ini` exists and `properties.ini` does not
- **THEN** after bind-prefs the live file SHALL be `/userdata/hal/properties.ini`

### Requirement: Build overlay uses neutral OS build names

Build-time overlay source SHALL be named `rootfs-overlay/` with neutral post-build hook basenames. Product prefixes MUST NOT appear in flashed rootfs paths.

#### Scenario: Repository overlay path

- **WHEN** developer inspects board overlay directory
- **THEN** it is named `rootfs-overlay/` not `lws-hmi-fs-overlay/`

### Requirement: Board usb-otg policy ini + runtime session

The image SHALL ship **`/etc/usb-otg.ini`** in rootfs with at least **`debug_only=true|false`** and **`auto_host_support=true|false`**. Boot/udev `usb-otg-mode.sh apply` and HAL SHALL read this file directly; the boot unit MUST NOT rewrite it. Chosen OTG mode for the current cable session SHALL live at **`/run/usb-otg.mode`** and MUST NOT survive reboot. Legacy **`/run/usb-otg-auto-support`** MUST NOT remain the ongoing policy file.

#### Scenario: ynh960 ships picker defaults

- **WHEN** ynh960 rootfs is produced
- **THEN** `/etc/usb-otg.ini` exists with `debug_only=false` and `auto_host_support=false`

