## MODIFIED Requirements

### Requirement: Full-system A/B upgrade preserves hardware prefs on userdata

A successful or failed **full-system A/B upgrade** (`make upgrade` updating boot and/or rootfs letter pairs) MUST NOT format userdata, MUST NOT delete or rewrite subsystem userdata trees under `/userdata/{wpa_supplicant,network,bluetooth,hal,hmi}` (or the subsystem `/var/lib/*` bind targets), and MUST leave preference files intact so boot restore can re-apply them after the new letter boots. Cold reboot and `make push-app` MUST follow the same non-wipe contract unless the operator explicitly runs factory-reset. **Factory tunables** (`properties.ini`) live on the **provision** partition per `gpt-provision-partition` and are outside userdata — factory-reset and flash userdata wipe MUST NOT erase them.

#### Scenario: Prefs survive boot+rootfs letter switch

- **WHEN** Wi‑Fi (or other) prefs exist under `/userdata/{wpa_supplicant,network,bluetooth,hal,hmi}` and a full-system `make upgrade` completes into the other boot/rootfs letter
- **THEN** those preference files are still present after reboot and settings restore can use them without re-entering Demo solely to recreate the files

#### Scenario: Failed upgrade does not wipe prefs

- **WHEN** a full-system upgrade fails verification before letter commit
- **THEN** `/userdata/{wpa_supplicant,network,bluetooth,hal,hmi}` contents remain intact on the still-active letter’s runtime

#### Scenario: properties.ini survives factory reset

- **WHEN** `/mnt/provision/properties.ini` contains factory keys before factory-reset
- **AND** factory-reset completes with full userdata wipe
- **THEN** provision `properties.ini` SHALL still contain the same factory keys

#### Scenario: Operator display prefs wiped with userdata

- **WHEN** `/var/lib/hal/display.conf` (userdata-bound operator file) exists before factory-reset
- **AND** factory-reset completes
- **THEN** operator display prefs under userdata SHALL be gone
