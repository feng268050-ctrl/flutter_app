## ADDED Requirements

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
