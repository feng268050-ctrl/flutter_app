## ADDED Requirements

### Requirement: Factory reset clears operator prefs but preserves properties.ini

A completed **user factory-reset** (board `/usr/bin/factory-reset` via product HMI Settings 恢复出厂设置, or any optional mirror of that helper) MUST clear **operator** preference state under `/userdata/{wpa_supplicant,network,bluetooth,hmi}` and operator files under `/userdata/hal/` so boot restore finds no prior wanted markers or UI/network preference files. It MUST **preserve** `/userdata/hal/properties.ini` (`/var/lib/hal/properties.ini`) because that file is **non-user device provisioning** (`make set-prop` / 产线), not something the user’s reset is allowed to destroy. This MUST NOT apply to cold reboot, `make push-app`, or full-system A/B upgrade / OTA. User factory-reset is a Settings feature for end users — not a 产线 procedure.

#### Scenario: Factory reset removes wifi-wanted

- **WHEN** `/userdata/wpa_supplicant/wifi-wanted` exists and factory-reset completes
- **AND** the board reboots
- **THEN** restore MUST NOT bring Wi‑Fi up solely from a leftover wanted marker
- **AND** the operator MUST re-enable / reconfigure Wi‑Fi to connect

#### Scenario: properties.ini survives factory reset

- **WHEN** `/var/lib/hal/properties.ini` contains `camera_ip=192.168.1.50` set by factory tooling
- **AND** factory-reset completes
- **THEN** that file still contains `camera_ip=192.168.1.50`

#### Scenario: Upgrade still preserves prefs

- **WHEN** prefs exist under `/userdata/{wpa_supplicant,network,bluetooth,hal,hmi}` and a full-system `make upgrade` completes
- **THEN** those preference files remain intact (factory-reset is a separate operation)

## MODIFIED Requirements

### Requirement: Full-system A/B upgrade preserves hardware prefs on userdata

A successful or failed **full-system A/B upgrade** (`make upgrade` updating boot and/or rootfs letter pairs) MUST NOT format userdata, MUST NOT delete or rewrite subsystem userdata trees under `/userdata/{wpa_supplicant,network,bluetooth,hal,hmi}` (or the subsystem `/var/lib/*` bind targets), and MUST leave preference files intact so boot restore can re-apply them after the new letter boots. Clearing **operator** trees is reserved for **factory-reset** and the compliant **factory flash** operator-prefs path — not for upgrade or OTA. Factory-reset MUST still preserve `properties.ini` under the hal tree.

#### Scenario: Prefs survive boot+rootfs letter switch

- **WHEN** Wi‑Fi (or other) prefs exist under `/userdata/{wpa_supplicant,network,bluetooth,hal,hmi}` and a full-system `make upgrade` completes into the other boot/rootfs letter
- **THEN** those preference files are still present after reboot and settings restore can use them without re-entering Demo solely to recreate the files

#### Scenario: Failed upgrade does not wipe prefs

- **WHEN** a full-system upgrade fails verification before letter commit
- **THEN** `/userdata/{wpa_supplicant,network,bluetooth,hal,hmi}` contents remain intact on the still-active letter’s runtime
