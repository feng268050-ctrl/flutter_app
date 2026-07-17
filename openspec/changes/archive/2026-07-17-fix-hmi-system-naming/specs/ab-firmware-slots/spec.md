## MODIFIED Requirements

### Requirement: A/B upgrade preserves all subsystem userdata trees

Helpers MUST NOT delete **`/userdata/wpa_supplicant`**, **`/userdata/network`**, **`/userdata/bluetooth`**, or **`/userdata/hmi`**.

#### Scenario: Upgrade does not wipe prefs

- **WHEN** full-system upgrade completes successfully
- **THEN** split userdata trees remain intact
