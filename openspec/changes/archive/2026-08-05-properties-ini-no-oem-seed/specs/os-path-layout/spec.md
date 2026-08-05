## MODIFIED Requirements

### Requirement: Subsystem state under separate var lib directories

The appliance OS SHALL NOT store Wi‑Fi, Ethernet, Bluetooth, HAL platform, and HMI App mutable state in a single flat directory. Each subsystem MUST use its own FHS `/var/lib/<name>/` tree:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi: `wifi-wanted`, `wpa_supplicant.conf`, `wpa_supplicant.log`, `wlan0-ipv4`, `wlan0-resolv.conf`
- **`/var/lib/network/`** — Ethernet: `eth0-wanted`, `eth0-ipv4`, `eth0-resolv.conf`; system proxy `proxy.conf`
- **`/var/lib/bluetooth/`** — Bluetooth: HMI prefs `bt-wanted`, `bt-a2dp-sink`, `bt-a2dp-volume` at the directory top level alongside BlueZ adapter subdirectories
- **`/var/lib/hal/`** — HAL / system platform prefs: `mouse.conf`, `keyboard.conf`, `display.conf` (keys `backlight` / `auto_sleep` / `orientation`), `sound.conf`, `datetime.conf`, `properties.ini`. OTG mode MUST NOT live here: session file is **`/run/usb-otg.mode`**. Stale **`usb-otg.conf`** / **`usb-debug`** MUST be removed by `bind-prefs` when present. Legacy basename **`product.ini`** SHALL be renamed to **`properties.ini`** when the latter is absent (see `properties-ini` migrate requirement).
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

### Requirement: Monolithic legacy userdata migration

On upgrade from images that used `/userdata/lws-hmi/`, the image SHALL split-move files into the subsystem userdata trees per the documented mapping, idempotently, before `settings-restore.service` runs. An empty legacy directory MAY be removed afterward.

On upgrade from images that stored HAL prefs under `/userdata/hmi/`, `bind-prefs.sh` SHALL one-shot fold the known HAL basenames into `/userdata/hal/` when the destination file is absent, then remove those basenames from the HMI tree. Known HAL basenames include at least: `display.conf`, `sound.conf`, `mouse.conf`, `keyboard.conf`, `datetime.conf`, `properties.ini`, legacy `product.ini` (folded then renamed to `properties.ini` when needed), legacy `display-orientation`, and legacy `time-sync-mode` / `timezone` if still present. When folding `display-orientation`, if `/userdata/hal/display.conf` lacks `orientation`, the image SHALL upsert `orientation=<token>` into `display.conf` and remove the standalone file. Stale OTG files **`usb-otg.conf`** and **`usb-debug`** under HMI or HAL userdata SHALL be deleted (OTG mode is session-only).

#### Scenario: Stale usb-debug removed

- **WHEN** device had `/userdata/hal/usb-debug` or `/userdata/hal/usb-otg.conf`
- **THEN** after migration those files are removed and OTG mode is not restored from them

#### Scenario: product.ini renamed to properties.ini

- **WHEN** `/userdata/hal/product.ini` exists and `properties.ini` does not
- **THEN** after bind-prefs the live file SHALL be `/userdata/hal/properties.ini`
