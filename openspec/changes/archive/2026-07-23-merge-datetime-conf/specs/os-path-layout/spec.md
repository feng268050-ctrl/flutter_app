## MODIFIED Requirements

### Requirement: Subsystem state under separate var lib directories

The appliance OS SHALL NOT store Wi‑Fi, Ethernet, Bluetooth, and HMI platform mutable state in a single flat directory. Each subsystem MUST use its own FHS `/var/lib/<name>/` tree:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi: `wifi-wanted`, `wpa_supplicant.conf`, `wpa_supplicant.log`, `wlan0-ipv4`, `wlan0-resolv.conf`
- **`/var/lib/network/`** — Ethernet: `eth0-wanted`, `eth0-ipv4`, `eth0-resolv.conf`
- **`/var/lib/bluetooth/`** — Bluetooth: HMI prefs `bt-wanted`, `bt-a2dp-sink`, `bt-a2dp-volume` at the directory top level alongside BlueZ adapter subdirectories
- **`/var/lib/hmi/`** — UI platform: `display-orientation`, `mouse.conf`, `display.conf`, `sound.conf`, `datetime.conf`, `http-proxy`, `usb-debug`, and push/debug/A-B staging artifacts

The legacy monolithic path **`/var/lib/lws-hmi/`** MUST NOT exist on shipped rootfs.

#### Scenario: Wi-Fi conf in wpa_supplicant state dir

- **WHEN** P1+ rootfs is produced and Wi‑Fi is configured
- **THEN** `wpa_supplicant.conf` lives under `/var/lib/wpa_supplicant/` not under `/var/lib/lws-hmi/` or a generic monolithic prefs tree

#### Scenario: eth0 prefs in network state dir

- **WHEN** eth0 static config is saved
- **THEN** `eth0-ipv4` lives under `/var/lib/network/`

#### Scenario: Mouse prefs in hmi state dir only

- **WHEN** mouse settings are persisted
- **THEN** `mouse.conf` lives under `/var/lib/hmi/` and not under `/var/lib/wpa_supplicant/` or `/var/lib/network/`

#### Scenario: Datetime prefs in datetime.conf

- **WHEN** sync mode or timezone is persisted by HAL
- **THEN** values live under `/var/lib/hmi/datetime.conf` (keys `sync_mode` / `timezone`), not as standalone `/var/lib/hmi/time-sync-mode` or `/var/lib/hmi/timezone` primary writes
