## ADDED Requirements

### Requirement: Shipping LWS gpio catalog uses gpiod

After cutover, the LWS product App `gpio.json` SHALL set the document default backend and chassis RGB / buzzer channel schemes to `gpiod`, with chip + offset populated. Historical `label` / `path` fields MAY remain as documentation. The catalog MUST NOT select `sysfs_innohi` as the runtime scheme on ynh960 once `gpio_innohi` is removed.

#### Scenario: Chassis RGB scheme is gpiod

- **WHEN** loading `app/lws_hmi/assets/hal/gpio.json` after cutover
- **THEN** device `chassis_rgb` channels SHALL use scheme `gpiod`
- **AND** MUST include chip and offset for each channel
