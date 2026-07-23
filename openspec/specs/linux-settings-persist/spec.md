# linux-settings-persist Specification

## Purpose

Hardware preference schema split across FHS subsystem directories under `/userdata/{wpa_supplicant,network,bluetooth,hmi}` (via `/var/lib/*` symlinks), wanted markers, and boot restore outside the HMI cgroup.
## Requirements
### Requirement: Hardware settings persist schema

The image SHALL document and use:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi wanted, `wpa_supplicant.conf`, wlan0 IPv4/DNS
- **`/var/lib/network/`** — eth0 wanted, eth0 IPv4/DNS; system proxy
- **`/var/lib/bluetooth/`** — BT wanted, A2DP sink/volume prefs
- **`/var/lib/hal/`** — `display.conf` / `sound.conf`, mouse/keyboard settings, `datetime.conf` (sync mode + timezone), USB debug role, `product.ini` (`display.conf` keys include `backlight`, `auto_sleep`, `orientation`)
- **`/var/lib/hmi/`** — HMI App stores (`misc-settings.json`, `advanced-settings.json`, alarm history DB) and push/debug/A-B staging

LAN SSH debug MUST NOT be restored at boot solely due to a prior enable. Mouse preferences MUST be re-applied when flutter-pi / `hmi.service` starts; they do NOT require a separate network-style restore oneshot.

#### Scenario: Cold boot without wifi-wanted

- **WHEN** the board boots and `/var/lib/wpa_supplicant/wifi-wanted` is absent
- **THEN** restore does not start `wlan-wpa.service` solely from restore

#### Scenario: Mouse prefs applied on HMI start

- **WHEN** mouse preference files exist under `/var/lib/hal/` and `hmi.service` starts flutter-pi
- **THEN** flutter-pi applies those mouse preferences for attached pointer devices without requiring the operator to open Demo

#### Scenario: Datetime prefs use datetime.conf under hal

- **WHEN** an operator changes sync mode or timezone via Settings / Demo
- **THEN** HAL persists under `/var/lib/hal/datetime.conf` (`sync_mode` / `timezone`) rather than under `/var/lib/hmi/` or separate `time-sync-mode` / `timezone` primary writes

#### Scenario: Orientation uses display.conf key

- **WHEN** an operator sets portrait via `change-orientation`
- **THEN** `/var/lib/hal/display.conf` contains `orientation=portrait` and MUST NOT rely on a standalone `display-orientation` primary write

### Requirement: Simple HW prefs written by shell apply helpers

For backlight brightness, media volume, display orientation, and mouse settings, the preference files under `/var/lib/hal/` SHALL be written by the corresponding verb-noun shell helpers (`change-backlight`, `change-volume`, `change-orientation`, `apply-mouse-settings`) and/or the HAL Linux backends that own those paths. Boot restore and `hmi-launch.sh` MUST continue to consume the same file paths under `/var/lib/hal/`. The HMI app MAY invoke those helpers but MUST NOT rely on Dart-only writes as the sole persistence path for orientation/mouse when shell helpers are the contract.

#### Scenario: Preference file updated only via helper contract

- **WHEN** brightness, volume, orientation, or mouse settings are changed from Demo or SSH
- **THEN** the matching helper / HAL backend performs the preference file update under `/var/lib/hal/` used by restore / launch

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

A successful or failed **full-system A/B upgrade** (`make upgrade` updating boot and/or rootfs letter pairs) MUST NOT format userdata, MUST NOT delete or rewrite subsystem userdata trees under `/userdata/{wpa_supplicant,network,bluetooth,hal,hmi}` (or the subsystem `/var/lib/*` bind targets), and MUST leave preference files intact so boot restore can re-apply them after the new letter boots.

#### Scenario: Prefs survive boot+rootfs letter switch

- **WHEN** Wi‑Fi (or other) prefs exist under `/userdata/{wpa_supplicant,network,bluetooth,hal,hmi}` and a full-system `make upgrade` completes into the other boot/rootfs letter
- **THEN** those preference files are still present after reboot and settings restore can use them without re-entering Demo solely to recreate the files

#### Scenario: Failed upgrade does not wipe prefs

- **WHEN** a full-system upgrade fails verification before letter commit
- **THEN** `/userdata/{wpa_supplicant,network,bluetooth,hal,hmi}` contents remain intact on the still-active letter’s runtime

### Requirement: Sound-effect asset preference under hmi prefs

The image / HAL SHALL persist the UI click **asset key** via `ButtonFeedback` at `/var/lib/hal/sound.conf` (key `button_feedback`). Cold start of the HMI App SHALL warm-read this preference before registering the Cyber click backend so the first taps play the correct sample. Boot `settings-restore.service` is NOT required to apply sound-effect / ButtonFeedback (unlike backlight/volume shell helpers). Sound-effect MUST NOT be relocated into `misc-settings.json` solely because Misc prefs were unified (Sound Effect is Display & Sound, not Misc).

#### Scenario: Pref file survives relaunch

- **WHEN** the operator selects Effect 2 and the HMI process restarts
- **THEN** `/var/lib/hal/sound.conf` (key `button_feedback`) still encodes Effect 2’s asset key

### Requirement: AutoSleep preference under hmi prefs

The image / HAL SHALL persist the AutoSleep / screen-off policy at `/var/lib/hal/display.conf` (key `auto_sleep`). Cold start SHALL restore the last policy for the idle watchdog. Boot `settings-restore.service` is NOT required to apply AutoSleep. AutoSleep MUST NOT be stored inside `misc-settings.json`.

#### Scenario: AutoSleep pref survives relaunch

- **WHEN** the operator selects Screen-off Time 30 min and the HMI process restarts
- **THEN** `/var/lib/hal/display.conf` (key `auto_sleep`) still encodes the 30-minute policy

### Requirement: Boot-self-check preference under hmi prefs

The App SHALL persist the “show startup self-check” boolean as a key inside `/var/lib/hmi/misc-settings.json` (unified Common Settings → Misc store), not as a standalone long-term preference file. Default when the JSON file is absent or the key is missing SHALL be **enabled** (`true`). If a legacy `/var/lib/hmi/boot-self-check` file exists and the JSON file does not yet contain the key, the App SHALL import that value into `misc-settings.json` on first read.

#### Scenario: Default enabled when file missing

- **WHEN** `/var/lib/hmi/misc-settings.json` is absent (and no legacy boot-self-check value applies)
- **THEN** boot self-check SHALL treat the preference as enabled

#### Scenario: Disabled value survives restart

- **WHEN** the operator disables Show Startup Self-Check
- **AND** the HMI process restarts
- **THEN** the preference SHALL remain disabled in `misc-settings.json`

### Requirement: Misc settings JSON under hmi prefs

The App SHALL persist Common Settings → Misc operator preferences in `/var/lib/hmi/misc-settings.json`. At minimum the file SHALL be able to store Show Startup Self-Check and Show System Status Overlay. Additional Misc keys MAY be added to the same JSON object without creating new per-toggle files. `settings-restore.service` is NOT required to apply these Misc keys (App-owned warm-read).

#### Scenario: System status overlay key in misc JSON

- **WHEN** the operator enables Show System Status Overlay
- **AND** the HMI process restarts
- **THEN** `/var/lib/hmi/misc-settings.json` still encodes the overlay as enabled

### Requirement: Advanced settings persist under dedicated var file

App-owned Advanced Settings preferences (AI assistance and dangerous-operation booleans, and optional cached numeric thresholds) SHALL persist in a dedicated JSON file under `/var/lib/hmi/` (e.g. `advanced-settings.json` via `OsPaths.varHmi`). They MUST NOT be stored in `misc-settings.json`. Missing or corrupt files MUST soft-fail to documented defaults without crashing the App.

#### Scenario: Soft-fail corrupt file

- **WHEN** `advanced-settings.json` is corrupt
- **THEN** the App applies defaults for AI (both ON) and dangerous ops (all OFF)
- **AND** the Settings UI remains usable

#### Scenario: Not Misc

- **WHEN** the operator changes Lens Contamination Detection
- **THEN** the value is written to the advanced-settings file
- **AND** MUST NOT appear as a key inside `misc-settings.json`

### Requirement: Advanced settings JSON may cache numeric thresholds

`/var/lib/hmi/advanced-settings.json` MAY store numeric threshold fields (zero offset, swing, powers, pressure, temperatures, recovery interval) in addition to AI/dangerous booleans. Missing numeric keys MUST soft-fail to documented defaults without wiping boolean keys.

#### Scenario: Numerics and booleans coexist

- **WHEN** the file contains both `keepLaserOnWhileAlarmed` and `laserStartPower`
- **THEN** both are loaded on warm-read

