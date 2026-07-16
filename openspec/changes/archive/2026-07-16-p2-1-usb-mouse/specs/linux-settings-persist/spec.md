## MODIFIED Requirements

### Requirement: Hardware settings persist schema

The image SHALL document and use preference files under `/var/lib/lws-hmi/` for Wi‑Fi wanted, eth0 wanted, wlan0/eth0 IPv4, `wpa_supplicant.conf`, HTTP proxy, display orientation, backlight brightness, BT A2DP Sink preference, and **mouse settings** (natural scroll, scroll speed, pointer speed, primary button). LAN SSH debug MUST NOT be restored at boot solely due to a prior enable. Mouse preferences MUST be re-applied when flutter-pi / `hmi.service` starts; they do NOT require a separate network-style restore oneshot.

#### Scenario: Cold boot without wifi-wanted

- **WHEN** the board boots and `/var/lib/lws-hmi/wifi-wanted` is absent
- **THEN** restore does not start `lws-hmi-wpa.service` solely from restore

#### Scenario: Mouse prefs applied on HMI start

- **WHEN** mouse preference files exist under `/var/lib/lws-hmi/` and `hmi.service` starts flutter-pi
- **THEN** flutter-pi applies those mouse preferences for attached pointer devices without requiring the operator to open Demo
