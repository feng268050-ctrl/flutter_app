## MODIFIED Requirements

### Requirement: Persist backlight brightness percent

Setting backlight brightness from the HMI SHALL apply via the Linux HAL backlight backend, which MUST write remapped sysfs values and persist the **logical** clamped percent (0–100, including 0) to `/var/lib/hal/display.conf` (key `backlight`). Restoring a persisted `0` MUST re-apply the hardware floor (not absolute zero).

#### Scenario: Set writes logical preference including zero

- **WHEN** the operator sets backlight brightness to 0 via Demo / HAL
- **THEN** `/var/lib/hal/display.conf` (key `backlight`) contains `0` and sysfs brightness is the hardware floor (not 0)

#### Scenario: Mid value still round-trips

- **WHEN** brightness is set to 60 via HAL and later the Demo reads brightness
- **THEN** get returns approximately 60 and the preference file still contains `60`
