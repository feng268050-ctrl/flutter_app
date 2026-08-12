## MODIFIED Requirements

### Requirement: Operator prefs survive cold reboot and full-system upgrade

Cold reboot, `make push-app`, and full-system A/B upgrade / OTA MUST NOT format userdata and MUST NOT delete subsystem userdata trees under `/userdata/{wpa_supplicant,network,bluetooth,hmi}` (or `/var/lib/*` bind targets) unless the operator explicitly runs factory-reset. **Factory tunables** (`properties.ini`) live on the **provision** partition per `gpt-provision-partition` and are outside userdata — factory-reset and flash userdata wipe MUST NOT erase them.

#### Scenario: properties.ini survives factory reset

- **WHEN** `/mnt/provision/properties.ini` contains factory keys before factory-reset
- **AND** factory-reset completes with full userdata wipe
- **THEN** provision `properties.ini` SHALL still contain the same factory keys

#### Scenario: Operator display prefs wiped with userdata

- **WHEN** `/var/lib/hal/display.conf` (userdata-bound operator file) exists before factory-reset
- **AND** factory-reset completes
- **THEN** operator display prefs under userdata SHALL be gone
