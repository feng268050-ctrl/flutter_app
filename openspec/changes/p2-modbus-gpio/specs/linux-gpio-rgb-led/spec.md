## ADDED Requirements

### Requirement: RGB pins match lws-ui GpioLedConfig

The Linux GPIO LED adapter SHALL drive three side-panel indicators using the same abstract pin numbers as lws-ui `GpioLedConfig`:

| Color | Pin |
|-------|-----|
| Red | 4 |
| Yellow | 3 |
| Green | 6 |

#### Scenario: Config exposes product pins

- **WHEN** an integrator inspects the P2 GPIO LED configuration in the HMI app
- **THEN** red/yellow/green map to pins 4/3/6 respectively

### Requirement: Each color supports Steady, Blink, and Off

For each of Red, Yellow, and Green, the driver SHALL support modes:

- **Steady** — output held on (HIGH per vendor active level used by lws-ui)
- **Blink** — 1000 ms on / 1000 ms off cycle (matching lws-ui `LedIndicatorManager` flash timing)
- **Off** — output held off (LOW)

Mode changes SHALL cancel any prior blink task for that color before applying the new mode.

#### Scenario: Steady turns lamp on

- **WHEN** the UI sets Red to Steady
- **THEN** the GPIO backend drives pin 4 to the steady-on state and stops any Red blink timer

#### Scenario: Blink flashes at one-second cadence

- **WHEN** the UI sets Yellow to Blink
- **THEN** pin 3 toggles with approximately 1000 ms on and 1000 ms off until the mode changes

#### Scenario: Off extinguishes lamp

- **WHEN** the UI sets Green to Off
- **THEN** pin 6 is driven off and any Green blink timer is cancelled

### Requirement: Colors are independently controllable

Setting a mode for one color SHALL NOT force Off/Steady/Blink changes on the other two colors.

#### Scenario: Independent colors

- **WHEN** Red is Steady and the user sets Green to Blink
- **THEN** Red remains Steady and Green begins Blink
