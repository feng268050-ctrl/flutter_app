# linux-backlight Specification

## Purpose

Reusable percent-based backlight controller writing `/sys/class/backlight/*/brightness` on Linux, without blocking first frame.
## Requirements
### Requirement: Backlight controller API is percent-based

The HMI SHALL provide a reusable `BacklightController` / `Backlight` that gets and sets display brightness as an integer **logical percent in 0–100** (clamped). Callers MUST NOT depend on Android `Settings.System` brightness integers. Logical **0 MUST be allowed** by the API and means “dimmest usable level,” not “panel off.”

#### Scenario: Brightness clamp high and low

- **WHEN** the client sets brightness to 120 or −5
- **THEN** the applied logical value is clamped to 100 or 0 respectively

#### Scenario: Logical zero is accepted

- **WHEN** the client sets brightness to 0 via HAL `setBrightnessPercent`
- **THEN** get returns 0 (approximately) and the call succeeds without treating 0 as invalid

### Requirement: Linux backend writes sysfs backlight

On Linux, the backlight implementation SHALL read/write a `/sys/class/backlight/*/brightness` node (auto-discovered when multiple exist), mapping **logical** percent onto a hardware range that never uses absolute zero for HAL-driven sets. Logical 0–100 SHALL map linearly onto `[hwFloor, max_brightness]` where `hwFloor` is derived from a HAL product constant (default 5% of `max_brightness`, at least 1). Get SHALL reverse-map so `hwFloor` reports as logical 0 and `max_brightness` as 100.

#### Scenario: Set brightness changes panel

- **WHEN** the user sets brightness from a mid value to a distinctly lower logical percent on ynh960
- **THEN** the panel backlight visibly dims and a subsequent get returns approximately the requested logical percent

#### Scenario: Missing backlight node does not crash app

- **WHEN** no backlight sysfs node is available or write fails
- **THEN** the app remains running and set/get fail gracefully without an unhandled UI isolate error

#### Scenario: Logical zero does not extinguish panel

- **WHEN** HAL applies logical brightness 0
- **THEN** the written sysfs `brightness` value is ≥ 1 and equals the configured hardware floor for that device, and the panel remains visible enough to operate

#### Scenario: Get reverse-maps hardware floor to logical zero

- **WHEN** sysfs brightness equals the hardware floor after a HAL set of 0
- **THEN** `getBrightnessPercent` returns 0

### Requirement: Backlight init stays off the critical first-frame path

The app SHALL NOT block `runApp` / first frame on a successful backlight open or read.

#### Scenario: First frame without backlight ready

- **WHEN** the app starts before backlight sysfs is readable
- **THEN** the first home frame still renders; the brightness control may show a default until a later successful read

### Requirement: Persist backlight brightness percent

Setting backlight brightness from the HMI SHALL apply via the Linux HAL backlight backend, which MUST write remapped sysfs values and persist the **logical** clamped percent (0–100, including 0) to `/var/lib/hal/display.conf` (key `backlight`). Restoring a persisted `0` MUST re-apply the hardware floor (not absolute zero).

#### Scenario: Set writes logical preference including zero

- **WHEN** the operator sets backlight brightness to 0 via Demo / HAL
- **THEN** `/var/lib/hal/display.conf` (key `backlight`) contains `0` and sysfs brightness is the hardware floor (not 0)

#### Scenario: Mid value still round-trips

- **WHEN** brightness is set to 60 via HAL and later the Demo reads brightness
- **THEN** get returns approximately 60 and the preference file still contains `60`

### Requirement: Demo brightness UI allows logical zero

The Demo (or product) brightness slider SHALL use minimum **0** and maximum 100 (logical). Setting the slider to minimum MUST invoke HAL with logical 0 and MUST NOT black out the panel.

#### Scenario: Slider minimum is logical zero

- **WHEN** the operator drags the brightness slider to its minimum
- **THEN** the UI value is 0, HAL is requested with 0, and the panel stays above absolute hardware zero

