# hal-gpio-config Specification

## Purpose
TBD - created by archiving change dart-hal-package. Update Purpose after archive.
## Requirements
### Requirement: GPIO config schema
`hal/gpio` SHALL load a versioned config document (JSON preferred) that declares at least: `version`, `backend`, and a `lines[]` array. Each line SHALL have a stable string `id`, a backend binding (`path` and/or label/`fallback_linux_gpio`), and MAY include `roles` and human `label`. The config MAY include `defaults` (e.g. blink timings, `active_low`) and a `capabilities` object advertising supported operations (`set_level`, `blink`, `read_level`).

#### Scenario: Product three indicators
- **WHEN** loading the product App’s gpio config (e.g. `assets/hal/gpio.json`)
- **THEN** it SHALL define lines for red/yellow/green indicators bound to gpio_innohi paths (GPIO_5 / GPIO_4 / GPIO_7) with linux GPIO fallbacks 105 / 106 / 149

### Requirement: Open by id
`GpioHal` SHALL expose `openLine(id)` (or equivalent) returning a line handle. Unknown `id` SHALL fail with a structured error. Line operations SHALL honor declared capabilities (e.g. blink only if advertised).

#### Scenario: Unknown line id
- **WHEN** the App requests `openLine("led_blue")` and that id is absent
- **THEN** HAL SHALL return a structured not-found / unsupported error without writing any sysfs path

### Requirement: No hard-coded product pins in portable API
Portable HAL SHALL NOT require a fixed RGB LED type. Product LEDs SHALL be ordinary named lines in config. Different **products** (and boards) SHALL ship different config files while keeping the same `GpioHal` API. Product gpio catalogs SHALL be App-owned assets pointed by `BoardProfile.configs.gpio`, not shipped inside `cyber_hal` keyed by motherboard name alone.

#### Scenario: Alternate board map
- **WHEN** a second motherboard uses different sysfs labels for indicators
- **THEN** only that product’s gpio config SHALL change; App code that uses line ids MAY keep working if ids are preserved

#### Scenario: Same board, different product
- **WHEN** the same motherboard is reused by another App with different LED wiring or roles
- **THEN** that App SHALL ship its own `gpio.json`; `cyber_hal` MUST NOT force a single board-named gpio map for all products

