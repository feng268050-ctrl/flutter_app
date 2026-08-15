## MODIFIED Requirements

### Requirement: RGB pins match lws-ui GpioLedConfig

The Linux GPIO LED path SHALL drive side-panel indicators using the product Status LED bank (`hal/gpio`) with **hardware bindings solely from** App `gpio.json` (or the profile-resolved gpio asset). For the current LWS product on ynh960, the shipped config SHALL map red, yellow, and green to these pads (documented here for the product catalog—not as HAL built-ins):

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

### Requirement: Forced Off always rewrites the pin

`setMode(Off, force: true)` (or equivalent reset API) MUST cancel blink and write the off level even when the channel's cached mode is already Off, so boot or external HIGH leftovers can be cleared.

#### Scenario: Force Off clears sticky HIGH

- **WHEN** the channel cache reports Off but the hardware line is still high
- **AND** the caller requests Off with force
- **THEN** the backend MUST write the off level through the active binding scheme (gpiod, optional sysfs, or stub)
