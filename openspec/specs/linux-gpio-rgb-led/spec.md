# linux-gpio-rgb-led Specification

## Purpose

Side-panel red/yellow/green indicators driven through the product Status LED bank (`hal/gpio`) with bindings from App `gpio.<board_id>.json`. Steady / Blink / Off modes match lws-ui.

## Requirements

### Requirement: RGB pins match lws-ui GpioLedConfig

The Linux GPIO LED path SHALL drive side-panel indicators using the product Status LED bank (`hal/gpio`) with **hardware bindings solely from** App `gpio.<board_id>.json` (or the profile-resolved gpio asset). For the current LWS product on ynh960, the shipped config SHALL map red, yellow, and green to these pads (documented here for the product catalog—not as HAL built-ins):

| Color | Silk / DTS label | SoC pad | gpiochip / offset | Linux GPIO # |
|-------|------------------|---------|-------------------|--------------|
| Red | `GPIO_5` | gpio3 RK_PB1 | `gpiochip3` / 9 | 105 |
| Yellow | `GPIO_4` | gpio3 RK_PB2 | `gpiochip3` / 10 | 106 |
| Green | `GPIO_7` (silk WG_D0) | gpio4 RK_PC5 | `gpiochip4` / 21 | 149 |

Shipping bindings SHALL use scheme `gpiod`. `GPIO_N` names are silk/DTS identifiers only. The adapter MUST NOT use YNHAPI’s 0-based integers (`GPIO_5=4`) as label numbers, and MUST NOT require `/sys/class/gpio_innohi` on cutover boards.

#### Scenario: Config exposes product pins

- **WHEN** an integrator inspects the product GPIO LED configuration in the HMI app
- **THEN** red/yellow/green SHALL map to the ynh960 pads above via gpiod chip/offset
- **AND** MUST NOT require App Dart constants embedding raw sysfs paths as the long-term pattern

### Requirement: Each color supports Steady, Blink, and Off

For each of Red, Yellow, and Green, the driver SHALL support modes:

- **Steady** — output held on (HIGH per vendor active level used by lws-ui)
- **Blink** — 1000 ms on / 1000 ms off cycle (matching lws-ui `LedIndicatorManager` flash timing) unless config overrides blink defaults
- **Off** — output held off (LOW)

Mode changes SHALL cancel any prior blink task for that color before applying the new mode (except same-mode Blink no-op rules in this capability).

#### Scenario: Steady turns lamp on

- **WHEN** the UI sets Red to Steady
- **THEN** the GPIO backend drives the red channel to the steady-on state and stops any Red blink timer

#### Scenario: Blink flashes at one-second cadence

- **WHEN** the UI sets Yellow to Blink
- **THEN** the yellow channel toggles with approximately 1000 ms on and 1000 ms off until the mode changes

#### Scenario: Off extinguishes lamp

- **WHEN** the UI sets Green to Off
- **THEN** the green channel is driven off and any Green blink timer is cancelled

### Requirement: Colors are independently controllable

Setting a mode for one color SHALL NOT force Off/Steady/Blink changes on the other two colors.

#### Scenario: Independent colors

- **WHEN** Red is Steady and the user sets Green to Blink
- **THEN** Red remains Steady and Green begins Blink

### Requirement: Same-mode Blink does not restart flash phase

When a GPIO line is already in Blink mode, a subsequent `setMode(Blink)` without force MUST be a no-op: it MUST NOT cancel the blink timer or force the line logical high. The first transition into Blink from another mode MUST start the 1000 ms on / 1000 ms off cycle from the on phase.

#### Scenario: Repeated Blink keeps phase

- **WHEN** a line is blinking and the off phase is active
- **AND** the caller requests Blink again without force
- **THEN** the line MUST remain in the off phase until the scheduled tick
- **AND** MUST NOT immediately turn on

### Requirement: Forced Off always rewrites the pin

`setMode(Off, force: true)` (or equivalent reset API) MUST cancel blink and write the off level even when the channel's cached mode is already Off, so boot or external HIGH leftovers can be cleared.

#### Scenario: Force Off clears sticky HIGH

- **WHEN** the channel cache reports Off but the hardware line is still high
- **AND** the caller requests Off with force
- **THEN** the backend MUST write the off level through the active binding scheme (gpiod, optional sysfs, or stub)
