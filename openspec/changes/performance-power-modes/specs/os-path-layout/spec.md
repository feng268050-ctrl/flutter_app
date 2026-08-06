## MODIFIED Requirements

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

- **WHEN** an operator selects balanced via Display settings or `set-power-mode`
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
