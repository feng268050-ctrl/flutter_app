## ADDED Requirements

### Requirement: Hardware settings persist schema

The image SHALL document and use:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi wanted, `wpa_supplicant.conf`, wlan0 IPv4/DNS
- **`/var/lib/network/`** — eth0 wanted, eth0 IPv4/DNS
- **`/var/lib/bluetooth/`** — BT wanted, A2DP sink/volume prefs
- **`/var/lib/hmi/`** — display orientation, backlight brightness, HTTP proxy

LAN SSH debug MUST NOT be restored at boot solely due to a prior enable.

#### Scenario: Cold boot without wifi-wanted

- **WHEN** the board boots and `/var/lib/wpa_supplicant/wifi-wanted` is absent
- **THEN** restore does not start `wlan-wpa.service` solely from restore

### Requirement: Boot restore oneshot

The image SHALL provide `settings-restore.service` (oneshot) linked from `multi-user.target.wants`, ordered **`After=hmi.service`** (and after `param-update.service`). It MUST NOT be ordered `Before=hmi.service`. Restore of Wi‑Fi / Ethernet / Bluetooth MUST start only after the HMI process is up, run at lowered scheduling priority (`Nice` / idle I/O), and MUST NOT compete with first-frame UI for boot CPU/IO. The HMI Demo / platform controllers SHALL observe `*-wanted` markers and present the same **starting / connecting** UI as a manual enable while restore completes (poll live state; do not block first paint waiting for association). Individual restore steps MAY soft-fail without failing `hmi.service`.

#### Scenario: Reboot restores Wi-Fi when wanted

- **WHEN** `wifi-wanted` exists with valid wpa config and the board reboots
- **THEN** after `hmi.service` is active, restore brings Wi‑Fi up via helpers; the Demo radio switch and connection phase update without requiring a touch to re-Apply

#### Scenario: HMI before network restore

- **WHEN** multi-user starts
- **THEN** `hmi.service` becomes active before `settings-restore.service` starts Wi‑Fi/BT/DHCP bring-up

### Requirement: HMI restart isolation invariant

Restarting or stopping `hmi.service` MUST NOT stop `wlan-wpa.service`, `wlan-dhcp.service`, `eth0-network.service`, or `ssh-debug-lan.service` solely because HMI stopped.

#### Scenario: stop hmi leaves wpa running

- **WHEN** `wlan-wpa.service` is active and the operator runs `systemctl stop hmi`
- **THEN** `wlan-wpa.service` remains active
