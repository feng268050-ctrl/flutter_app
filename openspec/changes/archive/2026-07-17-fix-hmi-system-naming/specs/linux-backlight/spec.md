## MODIFIED Requirements

### Requirement: Backlight persisted via change-backlight helper

Setting backlight brightness SHALL go through `change-backlight` in `/usr/libexec/hmi/`, persisting to **`/var/lib/hmi/backlight-brightness`**.

#### Scenario: Brightness percent persisted

- **WHEN** user or operator sets backlight to a given percent
- **THEN** `/var/lib/hmi/backlight-brightness` contains that percent
