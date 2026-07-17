## MODIFIED Requirements

### Requirement: Documented preference schema under userdata

Hardware preference schema SHALL be split across FHS subsystem directories under `/userdata/*` (via `/var/lib/*` symlinks), with wanted markers and boot restore outside the HMI cgroup.

The image SHALL document and use:

- **`/var/lib/wpa_supplicant/`** — Wi‑Fi wanted, `wpa_supplicant.conf`, wlan0 IPv4/DNS
- **`/var/lib/network/`** — eth0 wanted, eth0 IPv4/DNS
- **`/var/lib/bluetooth/`** — BT wanted, A2DP sink/volume prefs (alongside BlueZ adapter state)
- **`/var/lib/hmi/`** — display orientation, backlight, media volume, mouse settings, HTTP proxy, USB debug role, timezone

LAN SSH debug MUST NOT be restored at boot solely due to a prior enable. Mouse preferences MUST be re-applied when `hmi.service` starts flutter-pi.

#### Scenario: Wi-Fi wanted absent at boot

- **WHEN** the board boots and `/var/lib/wpa_supplicant/wifi-wanted` is absent
- **THEN** restore does not start `wlan-wpa.service` solely from restore

#### Scenario: Mouse prefs applied at HMI start

- **WHEN** `/var/lib/hmi/mouse.conf` exists and `hmi.service` starts flutter-pi
- **THEN** flutter-pi applies mouse preferences from that file

### Requirement: Shell helpers own persistence for simple hardware prefs

Backlight, media volume, display orientation, and mouse settings files under **`/var/lib/hmi/`** SHALL be written by verb-noun helpers in `/usr/libexec/hmi/`. Boot restore and `hmi-launch.sh` MUST consume those paths. The HMI app MUST NOT use Dart-only writes as the sole persistence path.

#### Scenario: Backlight file under hmi state dir

- **WHEN** HMI Demo sets backlight on Linux
- **THEN** `/var/lib/hmi/backlight-brightness` is updated via `change-backlight` helper

### Requirement: Settings restore runs after HMI is up

The image SHALL provide `settings-restore.service` (oneshot) linked from `multi-user.target.wants`, ordered **`After=hmi.service`**. Restore of Wi‑Fi / Ethernet / Bluetooth MUST start only after the HMI process is up.

#### Scenario: HMI starts before network restore

- **WHEN** device boots with saved Wi‑Fi wanted marker
- **THEN** `hmi.service` becomes active before `settings-restore.service` starts Wi‑Fi/BT/DHCP bring-up

### Requirement: Stopping HMI does not tear down network stacks

Restarting or stopping `hmi.service` MUST NOT stop `wlan-wpa.service`, `wlan-dhcp.service`, `eth0-network.service`, or `ssh-debug-lan.service` solely because HMI stopped.

#### Scenario: push-app stop hmi keeps Wi-Fi

- **WHEN** `wlan-wpa.service` is active and the operator runs `systemctl stop hmi`
- **THEN** `wlan-wpa.service` remains active

### Requirement: Full-system upgrade preserves userdata prefs

Full-system A/B upgrade MUST NOT format userdata or delete `/userdata/wpa_supplicant`, `/userdata/network`, `/userdata/bluetooth`, or `/userdata/hmi` (or their `/var/lib/*` bind targets).

#### Scenario: Upgrade with existing Wi-Fi prefs

- **WHEN** Wi‑Fi prefs exist under `/userdata/wpa_supplicant/` and `make upgrade` completes
- **THEN** after reboot boot restore finds the same files and re-applies stacks
