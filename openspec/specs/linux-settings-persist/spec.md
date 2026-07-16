# linux-settings-persist Specification

## Purpose

Hardware preference schema under `/userdata/lws-hmi` (via `/var/lib/lws-hmi`), wanted markers, and boot restore outside the HMI cgroup.
## Requirements
### Requirement: Hardware settings persist schema

The image SHALL document and use preference files under `/var/lib/lws-hmi/` for Wi‑Fi wanted, eth0 wanted, wlan0/eth0 IPv4, `wpa_supplicant.conf`, HTTP proxy, display orientation, backlight brightness, BT A2DP Sink preference, and **mouse settings** (natural scroll, scroll speed, pointer speed, primary button). LAN SSH debug MUST NOT be restored at boot solely due to a prior enable. Mouse preferences MUST be re-applied when flutter-pi / `hmi.service` starts; they do NOT require a separate network-style restore oneshot.

#### Scenario: Cold boot without wifi-wanted

- **WHEN** the board boots and `/var/lib/lws-hmi/wifi-wanted` is absent
- **THEN** restore does not start `lws-hmi-wpa.service` solely from restore

#### Scenario: Mouse prefs applied on HMI start

- **WHEN** mouse preference files exist under `/var/lib/lws-hmi/` and `hmi.service` starts flutter-pi
- **THEN** flutter-pi applies those mouse preferences for attached pointer devices without requiring the operator to open Demo

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

### Requirement: Full-system A/B upgrade preserves hardware prefs on userdata

A successful or failed **full-system A/B upgrade** (`make upgrade` updating boot and/or rootfs letter pairs) MUST NOT format userdata, MUST NOT delete or rewrite `/userdata/lws-hmi` (or the `/var/lib/lws-hmi` bind target), and MUST leave P2.3 preference files intact so boot restore can re-apply them after the new letter boots.

#### Scenario: Prefs survive boot+rootfs letter switch

- **WHEN** Wi‑Fi (or other) prefs exist under `/userdata/lws-hmi` and a full-system `make upgrade` completes into the other boot/rootfs letter
- **THEN** those preference files are still present after reboot and settings restore can use them without re-entering Demo solely to recreate the files

#### Scenario: Failed upgrade does not wipe prefs

- **WHEN** a full-system upgrade fails verification before letter commit
- **THEN** `/userdata/lws-hmi` contents remain intact on the still-active letter’s runtime

