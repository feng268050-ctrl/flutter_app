## MODIFIED Requirements

### Requirement: Hardware settings persist schema

The image SHALL document and use:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi wanted, `wpa_supplicant.conf`, wlan0 IPv4/DNS
- **`/var/lib/network/`** — eth0 wanted, eth0 IPv4/DNS; system proxy
- **`/var/lib/bluetooth/`** — BT wanted, A2DP sink/volume prefs
- **`/var/lib/hal/`** — `display.conf` / `sound.conf`, mouse/keyboard settings, `datetime.conf` (sync mode + timezone), `power.conf` (`mode` = `performance` / `balanced`), **`locale.conf`** (`language`, `unit`, `region`), `properties.ini` (`display.conf` keys include `backlight`, `auto_sleep`, `orientation`). Legacy `product.ini` SHALL be migrated to `properties.ini` when the latter is absent.
- **`/var/lib/hmi/`** — HMI App stores (`common-settings.json` for non-locale future peers if any, `misc-settings.json`, `advanced-settings.json`, alarm history DB) and push/debug/A-B staging

LAN SSH debug MUST NOT be restored at boot solely due to a prior enable. Mouse preferences MUST be re-applied when `hmi.service` starts; they do NOT require a separate network-style restore oneshot. **`locale.conf` is HAL-owned and is NOT applied by `settings-restore.service`** (PreferredLanguage / UnitSystem / Region are read by the HMI process on start; Region side effects are applied by HAL locale). Leftover `common-settings.json` Language / Unit / Country keys MUST be ignored. Load / thermal profile MUST be restored by the early `cpu-performance.service` oneshot (board helper), not by `settings-restore.service` alone.

#### Scenario: Cold boot without wifi-wanted

- **WHEN** the board boots and `/var/lib/wpa_supplicant/wifi-wanted` is absent
- **THEN** restore does not start `wlan-wpa.service` solely from restore

#### Scenario: Mouse prefs applied on HMI start

- **WHEN** mouse preference files exist under `/var/lib/hal/` and `hmi.service` starts the HMI
- **THEN** the compositor applies those mouse preferences for attached pointer devices without requiring the operator to open Demo

#### Scenario: Datetime prefs use datetime.conf under hal

- **WHEN** an operator changes sync mode or timezone via Settings / Demo
- **THEN** HAL persists under `/var/lib/hal/datetime.conf` (`sync_mode` / `timezone`) rather than under `/var/lib/hmi/` or separate `time-sync-mode` / `timezone` primary writes

#### Scenario: Orientation uses display.conf key

- **WHEN** an operator sets portrait via `change-orientation`
- **THEN** `/var/lib/hal/display.conf` contains `orientation=portrait` and MUST NOT rely on a standalone `display-orientation` primary write

#### Scenario: Locale prefs use locale.conf under hal

- **WHEN** an operator changes Language, Unit, or Country/Region via General Settings
- **THEN** HAL persists under `/var/lib/hal/locale.conf` (`language` / `unit` / `region`) rather than under `/var/lib/hmi/common-settings.json` as the primary store

#### Scenario: Load profile uses power.conf

- **WHEN** an operator selects balanced
- **THEN** `/var/lib/hal/power.conf` contains `mode=balanced`
- **AND** cold boot restores that mode via the board load-profile oneshot before HMI start
