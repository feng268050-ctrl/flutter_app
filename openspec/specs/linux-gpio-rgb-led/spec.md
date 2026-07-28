# linux-gpio-rgb-led Specification

## Purpose

Linux GPIO driver for the side-panel red/yellow/green indicators via Innohi `gpio_innohi` labels, with Steady / Blink / Off modes matching lws-ui.
## Requirements
### Requirement: RGB pins match lws-ui GpioLedConfig

The Linux GPIO LED adapter SHALL drive three side-panel indicators using Innohi **`gpio_innohi` labels** (red=`GPIO_5`, yellow=`GPIO_4`, green=`GPIO_7`). Prefer `/sys/class/gpio_innohi/GPIO_N/value`. Do **not** use YNHAPI’s 0-based integers (`GPIO_5=4` …) as label numbers. Classic SoC `/sys/class/gpio` lines from `&own_gpio` are fallback only when `gpio_innohi` is absent.

| Color | gpio_innohi label | SoC pad | Linux GPIO # (fallback) |
|-------|-------------------|---------|-------------------------|
| Red | `GPIO_5` | gpio3 RK_PB1 | 105 |
| Yellow | `GPIO_4` | gpio3 RK_PB2 | 106 |
| Green | `GPIO_7` | gpio4 RK_PC5 | 149 |

The adapter MUST address lines by **label** (`/sys/class/gpio_innohi/GPIO_N/value`). It MUST NOT use YNHAPI’s 0-based integers (`GPIO_5=4`) as label numbers, and MUST NOT treat labels as `/sys/class/gpio/gpioN`.

#### Scenario: Config exposes product pins

- **WHEN** an integrator inspects the P2 GPIO LED configuration in the HMI app
- **THEN** red/yellow/green map to `GPIO_5` / `GPIO_4` / `GPIO_7` (Linux SoC 105/106/149 only as fallback)

### Requirement: Each color supports Steady, Blink, and Off

For each of Red, Yellow, and Green, the driver SHALL support modes:

- **Steady** — output held on (HIGH per vendor active level used by lws-ui)
- **Blink** — 1000 ms on / 1000 ms off cycle (matching lws-ui `LedIndicatorManager` flash timing)
- **Off** — output held off (LOW)

Mode changes SHALL cancel any prior blink task for that color before applying the new mode.

#### Scenario: Steady turns lamp on

- **WHEN** the UI sets Red to Steady
- **THEN** the GPIO backend drives `GPIO_5` to the steady-on state and stops any Red blink timer

#### Scenario: Blink flashes at one-second cadence

- **WHEN** the UI sets Yellow to Blink
- **THEN** `GPIO_4` toggles with approximately 1000 ms on and 1000 ms off until the mode changes

#### Scenario: Off extinguishes lamp

- **WHEN** the UI sets Green to Off
- **THEN** `GPIO_7` is driven off and any Green blink timer is cancelled

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

`setMode(Off, force: true)` (or equivalent reset API) MUST cancel blink and write the off level even when the line's cached mode is already Off, so boot or external HIGH leftovers can be cleared.

#### Scenario: Force Off clears sticky HIGH

- **WHEN** the line cache reports Off but the sysfs value is still high
- **AND** the caller requests Off with force
- **THEN** the backend MUST write the off level

