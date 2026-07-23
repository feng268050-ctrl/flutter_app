## MODIFIED Requirements

### Requirement: Subsystem state under separate var lib directories

The appliance OS SHALL NOT store Wi‑Fi, Ethernet, Bluetooth, HAL platform, and HMI App mutable state in a single flat directory. Each subsystem MUST use its own FHS `/var/lib/<name>/` tree:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi: `wifi-wanted`, `wpa_supplicant.conf`, `wpa_supplicant.log`, `wlan0-ipv4`, `wlan0-resolv.conf`
- **`/var/lib/network/`** — Ethernet: `eth0-wanted`, `eth0-ipv4`, `eth0-resolv.conf`; system proxy `proxy.conf`
- **`/var/lib/bluetooth/`** — Bluetooth: HMI prefs `bt-wanted`, `bt-a2dp-sink`, `bt-a2dp-volume` at the directory top level alongside BlueZ adapter subdirectories
- **`/var/lib/hal/`** — HAL / system platform prefs: `mouse.conf`, `keyboard.conf`, `display.conf` (keys `backlight` / `auto_sleep` / `orientation`), `sound.conf`, `datetime.conf`, `usb-debug`, `product.ini`
- **`/var/lib/hmi/`** — HMI App-owned state: `misc-settings.json`, `advanced-settings.json`, `alarm-logs.db`, push/debug/A-B staging artifacts

The legacy monolithic path **`/var/lib/lws-hmi/`** MUST NOT exist on shipped rootfs.

#### Scenario: Wi-Fi conf in wpa_supplicant state dir

- **WHEN** P1+ rootfs is produced and Wi‑Fi is configured
- **THEN** `wpa_supplicant.conf` lives under `/var/lib/wpa_supplicant/` not under `/var/lib/lws-hmi/` or a generic monolithic prefs tree

#### Scenario: eth0 prefs in network state dir

- **WHEN** eth0 static config is saved
- **THEN** `eth0-ipv4` lives under `/var/lib/network/`

#### Scenario: Mouse prefs in hal state dir only

- **WHEN** mouse settings are persisted
- **THEN** `mouse.conf` lives under `/var/lib/hal/` and not under `/var/lib/hmi/`, `/var/lib/wpa_supplicant/`, or `/var/lib/network/`

#### Scenario: Datetime prefs in datetime.conf under hal

- **WHEN** sync mode or timezone is persisted by HAL
- **THEN** values live under `/var/lib/hal/datetime.conf` (keys `sync_mode` / `timezone`), not under `/var/lib/hmi/` as the primary write path

#### Scenario: App misc prefs stay under hmi

- **WHEN** Common Settings → Misc preferences are persisted
- **THEN** they live under `/var/lib/hmi/misc-settings.json` and MUST NOT be written under `/var/lib/hal/`

### Requirement: Subsystem helpers under usr libexec tiers

Programs invoked by systemd units or daemons (not user PATH commands) MUST live under **`/usr/libexec/<subsystem>/`**, not `/usr/lib/`:

- **`/usr/libexec/wpa/`** — Wi‑Fi stack scripts
- **`/usr/libexec/network/`** — Ethernet scripts
- **`/usr/libexec/bluetooth/`** — Bluetooth stack scripts
- **`/usr/libexec/hmi/`** — UI launch, HW change helpers, `restore-settings.sh`, `bind-prefs.sh`, push/debug/A-B/USB helpers

Legacy **`/usr/lib/lws-hmi/`** MUST NOT exist on shipped rootfs. Relocating helpers into `/usr/libexec/hal/` is NOT required by this change.

#### Scenario: Wi-Fi helper location

- **WHEN** `wlan-wpa.service` runs
- **THEN** it invokes scripts under `/usr/libexec/wpa/` not `/usr/libexec/lws-hmi/`

#### Scenario: restore-settings orchestrates split paths

- **WHEN** `settings-restore.service` runs after boot
- **THEN** `restore-settings.sh` under `/usr/libexec/hmi/` reads Wi‑Fi markers from `/var/lib/wpa_supplicant/`, eth0 from `/var/lib/network/`, BT from `/var/lib/bluetooth/`, and HAL platform prefs from `/var/lib/hal/`

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

### Requirement: Monolithic legacy userdata migration

On upgrade from images that used `/userdata/lws-hmi/`, the image SHALL split-move files into the subsystem userdata trees per the documented mapping, idempotently, before `settings-restore.service` runs. An empty legacy directory MAY be removed afterward.

On upgrade from images that stored HAL prefs under `/userdata/hmi/`, `bind-prefs.sh` SHALL one-shot fold the known HAL basenames into `/userdata/hal/` when the destination file is absent, then remove those basenames from the HMI tree. Known HAL basenames include at least: `display.conf`, `sound.conf`, `mouse.conf`, `keyboard.conf`, `datetime.conf`, `usb-debug`, `product.ini`, legacy `display-orientation`, and legacy `time-sync-mode` / `timezone` if still present. When folding `display-orientation`, if `/userdata/hal/display.conf` lacks `orientation`, the image SHALL upsert `orientation=<token>` into `display.conf` and remove the standalone file.

#### Scenario: Wi-Fi creds survive split migration

- **WHEN** device had `/userdata/lws-hmi/wpa_supplicant.conf` before upgrade
- **THEN** after `bind-prefs.sh`, `/var/lib/wpa_supplicant/wpa_supplicant.conf` contains the same networks

#### Scenario: Backlight pref lands in hal tree

- **WHEN** device had `/userdata/hmi/display.conf` (or legacy `/userdata/lws-hmi/display.conf` folded into hmi) before upgrade and `/userdata/hal/display.conf` is absent
- **THEN** after migration `/var/lib/hal/display.conf` (key `backlight`) contains the same value and the HMI tree no longer holds that basename as the live preference

#### Scenario: Legacy orientation folds into display.conf

- **WHEN** device had `/userdata/hmi/display-orientation` containing `portrait` and `/userdata/hal/display.conf` lacks `orientation`
- **THEN** after migration `/var/lib/hal/display.conf` contains `orientation=portrait` and the standalone `display-orientation` file is removed
