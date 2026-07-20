# linux-settings-persist Specification

## Purpose

Hardware preference schema split across FHS subsystem directories under `/userdata/{wpa_supplicant,network,bluetooth,hmi}` (via `/var/lib/*` symlinks), wanted markers, and boot restore outside the HMI cgroup.
## Requirements
### Requirement: Hardware settings persist schema

The image SHALL document and use:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi wanted, `wpa_supplicant.conf`, wlan0 IPv4/DNS
- **`/var/lib/network/`** — eth0 wanted, eth0 IPv4/DNS
- **`/var/lib/bluetooth/`** — BT wanted, A2DP sink/volume prefs
- **`/var/lib/hmi/`** — display orientation, backlight, media volume, mouse settings, HTTP proxy, USB debug role, timezone

LAN SSH debug MUST NOT be restored at boot solely due to a prior enable. Mouse preferences MUST be re-applied when flutter-pi / `hmi.service` starts; they do NOT require a separate network-style restore oneshot.

#### Scenario: Cold boot without wifi-wanted

- **WHEN** the board boots and `/var/lib/wpa_supplicant/wifi-wanted` is absent
- **THEN** restore does not start `wlan-wpa.service` solely from restore

#### Scenario: Mouse prefs applied on HMI start

- **WHEN** mouse preference files exist under `/var/lib/hmi/` and `hmi.service` starts flutter-pi
- **THEN** flutter-pi applies those mouse preferences for attached pointer devices without requiring the operator to open Demo

### Requirement: Simple HW prefs written by shell apply helpers

For backlight brightness, media volume, display orientation, and mouse settings, the preference files under `/var/lib/hmi/` SHALL be written by the corresponding verb-noun shell helpers (`change-backlight`, `change-volume`, `change-orientation`, `apply-mouse-settings`). Boot restore and `hmi-launch.sh` MUST continue to consume the same file paths. The HMI app MAY invoke those helpers but MUST NOT rely on Dart-only writes as the persistence path for these four prefs.

#### Scenario: Preference file updated only via helper contract

- **WHEN** brightness, volume, orientation, or mouse settings are changed from Demo or SSH
- **THEN** the matching shell helper performs the preference file update used by restore / launch

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

### Requirement: Full-system A/B upgrade preserves hardware prefs on userdata

A successful or failed **full-system A/B upgrade** (`make upgrade` updating boot and/or rootfs letter pairs) MUST NOT format userdata, MUST NOT delete or rewrite subsystem userdata trees under `/userdata/{wpa_supplicant,network,bluetooth,hmi}` (or the subsystem `/var/lib/*` bind targets), and MUST leave P2.3 preference files intact so boot restore can re-apply them after the new letter boots.

#### Scenario: Prefs survive boot+rootfs letter switch

- **WHEN** Wi‑Fi (or other) prefs exist under `/userdata/{wpa_supplicant,network,bluetooth,hmi}` and a full-system `make upgrade` completes into the other boot/rootfs letter
- **THEN** those preference files are still present after reboot and settings restore can use them without re-entering Demo solely to recreate the files

#### Scenario: Failed upgrade does not wipe prefs

- **WHEN** a full-system upgrade fails verification before letter commit
- **THEN** `/userdata/{wpa_supplicant,network,bluetooth,hmi}` contents remain intact on the still-active letter’s runtime

### Requirement: Sound-effect index preference under hmi prefs

The image / App SHALL persist the UI click sound-effect index (integer `0..2`) under `/var/lib/hmi/` (exact filename chosen at implementation, e.g. `sound-effect` or a field inside an existing HMI prefs file). Cold start of the HMI App SHALL read this preference before registering the Cyber click backend so the first taps use the correct sample. Boot `settings-restore.service` is NOT required to apply sound-effect (App-owned; unlike backlight/volume shell helpers).

#### Scenario: Pref file survives relaunch

- **WHEN** the operator selects Effect 2 and the HMI process restarts
- **THEN** the sound-effect preference under `/var/lib/hmi/` still encodes index `1`

### Requirement: Boot-self-check preference under hmi prefs

The App SHALL persist the “show startup self-check” boolean under `/var/lib/hmi/` (e.g. `/var/lib/hmi/boot-self-check`) using the same userdata-backed prefs layout as other HMI operator preferences. Default when absent SHALL be **enabled** (`true`).

#### Scenario: Default enabled when file missing

- **WHEN** the preference file is absent
- **THEN** boot self-check SHALL treat the preference as enabled

#### Scenario: Disabled value survives restart

- **WHEN** the operator disables Show Startup Self-Check
- **AND** the HMI process restarts
- **THEN** the preference SHALL remain disabled

