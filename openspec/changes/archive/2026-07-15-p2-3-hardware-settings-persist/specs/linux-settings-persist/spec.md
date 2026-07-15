## ADDED Requirements

### Requirement: Hardware settings persist schema

The image SHALL document and use preference files under `/var/lib/lws-hmi/` for Wi‑Fi wanted, eth0 wanted, wlan0/eth0 IPv4, `wpa_supplicant.conf`, HTTP proxy, display orientation, backlight brightness, and BT A2DP Sink preference. LAN SSH debug MUST NOT be restored at boot solely due to a prior enable.

#### Scenario: Cold boot without wifi-wanted

- **WHEN** the board boots and `/var/lib/lws-hmi/wifi-wanted` is absent
- **THEN** restore does not start `lws-hmi-wpa.service` solely from restore

### Requirement: Boot restore oneshot

The image SHALL provide `lws-hmi-settings-restore.service` (oneshot) linked from `multi-user.target.wants`, ordered **`After=hmi.service`** (and after `param-update.service`). It MUST NOT be ordered `Before=hmi.service`. Restore of Wi‑Fi / Ethernet / Bluetooth MUST start only after the HMI process is up, run at lowered scheduling priority (`Nice` / idle I/O), and MUST NOT compete with first-frame UI for boot CPU/IO. The HMI Demo / platform controllers SHALL observe `*-wanted` markers and present the same **starting / connecting** UI as a manual enable while restore completes (poll live state; do not block first paint waiting for association). Individual restore steps MAY soft-fail without failing `hmi.service`.

#### Scenario: Reboot restores Wi-Fi when wanted

- **WHEN** `wifi-wanted` exists with valid wpa config and the board reboots
- **THEN** after `hmi.service` is active, restore brings Wi‑Fi up via helpers; the Demo radio switch and connection phase update without requiring a touch to re-Apply

#### Scenario: HMI before network restore

- **WHEN** multi-user starts
- **THEN** `hmi.service` becomes active before `lws-hmi-settings-restore.service` starts Wi‑Fi/BT/DHCP bring-up

### Requirement: HMI restart isolation invariant

Restarting or stopping `hmi.service` MUST NOT stop `lws-hmi-wpa.service`, `lws-hmi-wlan0-dhcp.service`, `lws-hmi-eth0.service`, or `lws-hmi-lan-ssh.service` solely because HMI stopped.

#### Scenario: stop hmi leaves wpa running

- **WHEN** `lws-hmi-wpa.service` is active and the operator runs `systemctl stop hmi`
- **THEN** `lws-hmi-wpa.service` remains active
