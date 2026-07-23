## MODIFIED Requirements

### Requirement: Hardware settings persist schema

The image SHALL document and use:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi wanted, `wpa_supplicant.conf`, wlan0 IPv4/DNS
- **`/var/lib/network/`** — eth0 wanted, eth0 IPv4/DNS
- **`/var/lib/bluetooth/`** — BT wanted, A2DP sink/volume prefs
- **`/var/lib/hmi/`** — display orientation, `display.conf` / `sound.conf`, mouse settings, `datetime.conf` (sync mode + timezone), HTTP proxy, USB debug role

LAN SSH debug MUST NOT be restored at boot solely due to a prior enable. Mouse preferences MUST be re-applied when flutter-pi / `hmi.service` starts; they do NOT require a separate network-style restore oneshot.

#### Scenario: Cold boot without wifi-wanted

- **WHEN** the board boots and `/var/lib/wpa_supplicant/wifi-wanted` is absent
- **THEN** restore does not start `wlan-wpa.service` solely from restore

#### Scenario: Mouse prefs applied on HMI start

- **WHEN** mouse preference files exist under `/var/lib/hmi/` and `hmi.service` starts flutter-pi
- **THEN** flutter-pi applies those mouse preferences for attached pointer devices without requiring the operator to open Demo

#### Scenario: Datetime prefs use datetime.conf

- **WHEN** an operator changes sync mode or timezone via Settings / Demo
- **THEN** HAL persists under `/var/lib/hmi/datetime.conf` (`sync_mode` / `timezone`) rather than separate `time-sync-mode` / `timezone` files
