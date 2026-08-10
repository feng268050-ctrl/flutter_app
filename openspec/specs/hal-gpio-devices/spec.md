# hal-gpio-devices Specification

## Purpose

Use-case GPIO device APIs in `cyber_hal` (`StatusLedBank`, buzzer, tactile button with long-press, rotary encoder with debounce). Device and channel inventory come solely from App-owned gpio config.

## Requirements

### Requirement: Status LED bank device

`hal/gpio` SHALL expose a Status LED bank device (e.g. `StatusLedBank`) opened by config `id`. The bank’s channels SHALL be exactly the named entries in that device’s config `channels[]` (zero or more; ids are opaque strings). HAL MUST NOT require a fixed red/yellow/green trio or any board-specific channel set. Each configured channel SHALL support modes **Off**, **Steady**, and **Blink**. Blink timing SHALL come from config defaults (or per-channel overrides) and MUST preserve idempotent same-mode Blink (no phase restart) and forced Off rewrite semantics already required for product indicators. Hardware addressing for each channel SHALL come from that channel’s binding in gpio config, not from HAL constants.

#### Scenario: Open chassis RGB bank

- **WHEN** gpio config declares a `status_led` device `chassis_rgb` with channels `red`, `yellow`, `green`
- **AND** the App opens that device id
- **THEN** HAL SHALL return a Status LED bank handle with those three channels

#### Scenario: Board with fewer channels

- **WHEN** gpio config declares a `status_led` device with only channel `fault`
- **AND** the App opens that device id
- **THEN** HAL SHALL expose only `fault`
- **AND** MUST NOT invent red/yellow/green channels

#### Scenario: Independent channel modes

- **WHEN** channel `red` is Steady and the caller sets `green` to Blink
- **THEN** `red` SHALL remain Steady and `green` SHALL begin Blink

### Requirement: Buzzer device

`hal/gpio` SHALL expose a Buzzer device opened by config `id`. The device SHALL support turning the buzzer on and off and issuing a finite **beep** (duration and optional simple on/off pattern from config or call arguments). A new beep or `setOn(false)` SHALL cancel any in-progress pattern. Logical on/off SHALL honor line `active_low`.

#### Scenario: Finite beep

- **WHEN** the App calls beep with a 100 ms duration on an available buzzer device
- **THEN** HAL SHALL drive the line logically on, then off after approximately 100 ms
- **AND** SHALL NOT leave the buzzer on after the beep completes

#### Scenario: Missing buzzer capability

- **WHEN** config does not advertise buzzer / has no buzzer device
- **AND** the App requests a buzzer by id
- **THEN** HAL SHALL fail with a structured not-found or unsupported error without claiming the line

### Requirement: Tactile button with long-press

`hal/gpio` SHALL expose a Button device opened by config `id`. The device SHALL emit a stream (or equivalent observer API) of press, release, and **long-press** events. HAL SHALL apply configurable debounce and a configurable long-press threshold (defaults allowed). Active level / `active_low` SHALL be taken from config. Contact bounce shorter than the debounce window MUST NOT produce duplicate press/release pairs.

#### Scenario: Short press

- **WHEN** a debounced press is followed by release before the long-press threshold
- **THEN** HAL SHALL emit press then release
- **AND** MUST NOT emit long-press

#### Scenario: Long press

- **WHEN** a debounced press is held at least the configured long-press duration
- **THEN** HAL SHALL emit long-press (in addition to the initial press)
- **AND** a later release SHALL still be observable

### Requirement: Rotary encoder with debounce

`hal/gpio` SHALL expose a RotaryEncoder device opened by config `id`, bound to quadrature **A** and **B** lines in config. The device SHALL emit clockwise and counter-clockwise step events after software debounce. Spurious edges within the debounce window MUST NOT produce extra steps. Config MAY invert direction.

#### Scenario: One detent clockwise

- **WHEN** A/B edges correspond to one valid clockwise detent after debounce
- **THEN** HAL SHALL emit exactly one clockwise step event

#### Scenario: Bounce suppressed

- **WHEN** contact bounce produces multiple edges within the debounce window that do not complete an additional detent
- **THEN** HAL MUST NOT emit an extra step for that bounce

### Requirement: Device open by id and capabilities

`GpioHal` SHALL open GPIO **devices** by stable string `id` according to config. The set of present devices (and whether buzzer / button / encoder / status LED exist) SHALL be determined solely by gpio config / capabilities. Unknown ids SHALL fail with a structured not-found error. Operations SHALL honor advertised capabilities. Portable HAL and product Dart MUST NOT hard-code SoC pin numbers, chip offsets, or sysfs paths; those bindings live only in App-owned gpio config (or tests’ fixtures).

#### Scenario: Unknown device id

- **WHEN** the App opens device id `panel_knob` and it is absent from config
- **THEN** HAL SHALL return a structured not-found / unsupported error
- **AND** MUST NOT request unrelated gpio lines

#### Scenario: Board omits buzzer

- **WHEN** gpio config has no buzzer device and does not advertise buzzer
- **THEN** HAL MUST NOT open or claim a default buzzer line
- **AND** App code that only opens configured device ids SHALL run without requiring a bell pin
