# hal-gpio-config Specification

## Purpose

Versioned App-owned gpio config schema for `hal/gpio`: device inventory, per-line binding schemes (sysfs and/or gpiod), and capabilities. Pins and paths are never hard-coded in portable HAL.

## Requirements

### Requirement: GPIO config schema
`hal/gpio` SHALL load a versioned config document (JSON preferred) that declares at least: `version`, `backend` (document default scheme or stub), and either a v1 `lines[]` array or a v2+ `devices[]` array (or both during migration). The document SHALL be the **sole** runtime source of which devices/channels exist and how each line is addressed. Each device SHALL have a stable string `id`, a `type` (`status_led`, `buzzer`, `button`, `rotary_encoder`), and line bindings that select a **scheme** (`gpiod`, `sysfs_innohi`, or documented fallback/stub). Gpiod bindings SHALL use chip name/label + line `offset`. Sysfs bindings SHALL use an explicit `path` and/or `label` (path MAY point at any board-specific `/sys/class/…` node, not only a hard-coded Innohi prefix in HAL). The config MAY include `defaults` (blink timings, debounce, long-press, `active_low`) and a `capabilities` object advertising supported device classes. A v1 document that only lists indicator `lines[]` with sysfs bindings SHALL still load: HAL MUST adapt those lines into a Status LED bank.

#### Scenario: Product three indicators
- **WHEN** loading a product App’s gpio config that declares chassis RGB (e.g. `assets/hal/gpio.ynh960.json` for ynh960)
- **THEN** that **config file** SHALL define red/yellow/green as a `status_led` device (or adaptable `led_*` lines) with that board’s bindings
- **AND** HAL SHALL NOT supply those pins from built-in board tables

#### Scenario: Alternate sysfs path
- **WHEN** a board’s gpio config binds an LED channel with scheme `sysfs_innohi` (or sysfs) to a path under a different class directory than another board
- **THEN** HAL SHALL use the configured path/label
- **AND** MUST NOT rewrite it to a package-default `/sys/class/gpio_innohi/…` string

#### Scenario: v2 device document with dual addressing
- **WHEN** loading a version 2 gpio config with a `buzzer` device
- **THEN** the document SHALL include a binding scheme and addressing for that line (e.g. sysfs label `BELL` and/or gpiod chip/offset)
- **AND** MAY record both addressing forms while selecting one scheme for runtime

### Requirement: Open by id
`GpioHal` SHALL expose device open APIs by config `id` (Status LED bank, buzzer, button, rotary encoder as declared). Unknown `id` SHALL fail with a structured error. Device operations SHALL honor declared capabilities. A temporary line-level `openLine(id)` MAY remain for migration but MUST NOT be required for Status LED, buzzer, button, or encoder product use once devices are configured.

#### Scenario: Unknown line id
- **WHEN** the App requests an unknown device or line id such as `led_blue`
- **THEN** HAL SHALL return a structured not-found / unsupported error without requesting gpio lines for that id

### Requirement: No hard-coded product pins in portable API
Portable HAL SHALL NOT require a fixed RGB LED type, fixed channel count, or fixed peripheral set. Product LEDs SHALL be Status LED channels (or ordinary named lines during migration) in config. Different **products** and **boards** SHALL enable fewer, more, or different devices/channels and different path/chip maps **only** by shipping different gpio config files while keeping the same device-oriented `GpioHal` API. Product gpio catalogs SHALL be App-owned assets pointed by `BoardProfile.configs.gpio`, not shipped inside `cyber_hal` as board-named pin tables. `cyber_hal` Dart MUST NOT contain ynh960-specific GPIO number/label/path literals used as the runtime map.

#### Scenario: Alternate board map
- **WHEN** a second motherboard uses different chip/offset or sysfs labels/paths for indicators
- **THEN** only that product’s gpio config SHALL change; App code that uses device/channel ids MAY keep working if ids are preserved

#### Scenario: Same board, different product
- **WHEN** the same motherboard is reused by another App with different LED wiring or roles
- **THEN** that App SHALL ship its own `gpio.<board_id>.json` (or equivalent App asset); `cyber_hal` MUST NOT force a single board-named gpio map for all products

#### Scenario: Board with extra or missing peripherals
- **WHEN** one board’s config adds a second button device and omits rotary encoder, while another board’s config does the opposite
- **THEN** each HAL instance SHALL expose only the devices listed in its loaded config
- **AND** MUST NOT assume a universal pin set

### Requirement: Shipping LWS gpio catalog uses gpiod

After cutover, the LWS product App `gpio.ynh960.json` SHALL set the document default backend and chassis RGB / buzzer channel schemes to `gpiod`, with chip + offset populated. Historical `label` / `path` fields MAY remain as documentation. The catalog MUST NOT select `sysfs_innohi` as the runtime scheme on ynh960 once `gpio_innohi` is removed.

#### Scenario: Chassis RGB scheme is gpiod

- **WHEN** loading `app/lws_hmi/assets/hal/gpio.ynh960.json` after cutover
- **THEN** device `chassis_rgb` channels SHALL use scheme `gpiod`
- **AND** MUST include chip and offset for each channel
