## MODIFIED Requirements

### Requirement: Shell helpers apply and persist hardware prefs under var lib hmi

Verb-noun board helpers under **`/usr/libexec/hmi/`** SHALL persist UI/HW integration prefs under **`/var/lib/hmi/`**:

- `backlight-brightness`
- `media-volume`
- `display-orientation`
- `mouse.conf`

Network and wireless prefs MUST NOT be written under `/var/lib/hmi/`.

#### Scenario: Backlight persisted via helper

- **WHEN** operator or HMI runs `change-backlight 75`
- **THEN** `/var/lib/hmi/backlight-brightness` contains `75`

#### Scenario: Volume not in wpa_supplicant dir

- **WHEN** media volume is set to 40%
- **THEN** `/var/lib/hmi/media-volume` contains `40` and `/var/lib/wpa_supplicant/` has no media-volume file

#### Scenario: Orientation under hmi state

- **WHEN** display orientation is set to portrait
- **THEN** `/var/lib/hmi/display-orientation` contains `portrait`

#### Scenario: Mouse conf under hmi state

- **WHEN** mouse settings change
- **THEN** `/var/lib/hmi/mouse.conf` is updated
