## MODIFIED Requirements

### Requirement: Media volume persisted via change-volume helper

Setting media volume on Linux SHALL go through `change-volume` in `/usr/libexec/hmi/`, persisting to **`/var/lib/hmi/media-volume`**. BT A2DP volume scripts remain under `/usr/libexec/bluetooth/` with prefs under `/var/lib/bluetooth/`.

#### Scenario: Volume percent persisted

- **WHEN** user sets media volume to 55% in Demo
- **THEN** `/var/lib/hmi/media-volume` contains `55`
