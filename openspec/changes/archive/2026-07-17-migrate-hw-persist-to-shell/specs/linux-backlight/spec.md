## MODIFIED Requirements

### Requirement: Persist backlight brightness percent

Setting backlight brightness (from the HMI Demo or from the board shell) SHALL go through `change-backlight` / `change-backlight.sh`, which MUST apply sysfs brightness and persist the clamped percent (0–100) to `/var/lib/lws-hmi/backlight-brightness` so boot restore can re-apply it. The Linux Flutter backlight backend MUST NOT write that preference file directly.

#### Scenario: Set writes preference

- **WHEN** the operator sets backlight brightness to a valid percent via Demo or `change-backlight`
- **THEN** `/var/lib/lws-hmi/backlight-brightness` contains that percent

#### Scenario: Shell and Demo share persist path

- **WHEN** brightness is set to 60 via `change-backlight` and later the Demo reads brightness
- **THEN** get returns approximately 60 and the preference file still contains `60`
