## ADDED Requirements

### Requirement: Product GPIO lines are free for gpiod

After cutover, the shipping kernel Image SHALL NOT include the Innohi `gpio_innohi` driver hogging product pads. Product lines used by HAL (ynh960: GPIO_4 / GPIO_5 / GPIO_7 / BELL) SHALL be requestable on `/dev/gpiochip*` (chip + offset as documented in the product gpio catalog). The kernel MUST NOT hold those lines via `gpio_innohi`, `gpio-hog`, or `gpio-leds` in a way that causes userspace gpiod request to fail with busy.

Silk **WG_D0 / WG_D1** are the former Wiegand D0/D1 pads, remuxed as **GPIO_7 / GPIO_8**. They SHALL be treated as ordinary GPIO after cutover. The kernel MUST NOT restore Wiegand character devices for these pads. GPIO_7 SHALL remain the green Status LED binding; GPIO_8 SHALL remain unclaimed (no HAL device required) unless a later product catalog adds it.

#### Scenario: Userspace can request green LED pad

- **WHEN** the cutover kernel is running on ynh960
- **AND** HMI (or `gpioget`/`gpioset`) requests `gpiochip4` offset `21`
- **THEN** the request SHALL succeed
- **AND** `/sys/class/gpio_innohi/GPIO_7/value` MUST NOT be required

#### Scenario: Former Wiegand D1 pad is free GPIO

- **WHEN** the cutover kernel is running on ynh960
- **AND** userspace requests `gpiochip4` offset `22` (silk WG_D1 / `GPIO_8`)
- **THEN** the request SHALL succeed
- **AND** `/dev/wiegand_input` and `/dev/wiegand_output` MUST NOT be required
- **AND** shipping LWS `gpio.json` MUST NOT be required to declare a device for GPIO_8

### Requirement: Board enable lines stay kernel-owned without gpio_innohi

USB host VBUS enables (ynh960 `USB_HOST_PWREN*`) SHALL remain asserted by a **standard** DT mechanism (`gpio-hog` output-high or regulator/fixed-gpio). HAL MUST NOT be required to toggle those lines for host ports to work.

#### Scenario: Host VBUS without Innohi class

- **WHEN** `gpio_innohi` is absent
- **THEN** 1 mm USB host VBUS enables SHALL still be driven as in the current product DT defaults
- **AND** MUST NOT depend on `/sys/class/gpio_innohi`

### Requirement: Indicators off at halt

When the system halts or powers off, product Status LED and buzzer pads SHALL be driven inactive (logical off / line low for active-high ynh960 indicators). Ownership MAY be userspace (`hmi.service` stop plus a shutdown oneshot) rather than `gpio_innohi` syscore.

#### Scenario: Halt clears chassis lamps

- **WHEN** the device reaches halt/poweroff after cutover
- **THEN** red/yellow/green indicator pads SHALL be low (off)
- **AND** MUST NOT remain latched high solely because HMI already exited
