# hal-gpio-gpiod-backend Specification

## Purpose

Dual Linux GPIO line backends for `hal/gpio`: character-device gpiod (`flutter_gpiod` / `/dev/gpiochip*`) and sysfs (`gpio_innohi` or arbitrary configured path), plus stub/sim. Per-binding scheme selection and input observation rules.

## Requirements

### Requirement: Dual Linux line backends

`hal/gpio` Linux implementations SHALL support **both**:

1. **Character-device gpiod** (`/dev/gpiochip*` via the Dart gpiod client `flutter_gpiod`) when a binding’s scheme is `gpiod`.
2. **Sysfs value nodes** (`path` and/or `label` under a configured `/sys/class/…` tree, historically `gpio_innohi`) when a binding’s scheme is `sysfs_innohi` / `sysfs`.

Classic `/sys/class/gpio` export MAY remain an engineering fallback (`sysfs_export` / `fallback_linux_gpio`). The portable device API (Status LED, Buzzer, Button, RotaryEncoder) MUST work with either primary scheme. After the ynh960 cutover, HAL MUST NOT require `gpio_innohi` or `/sys/class/gpio_innohi` to ship the device API on that board.

#### Scenario: Sysfs-bound Status LED

- **WHEN** a Status LED channel binding uses scheme `sysfs_innohi` with an explicit path or label
- **AND** the channel is set to Steady
- **THEN** HAL SHALL write the logical on level to that sysfs value node
- **AND** MUST NOT be required to open `/dev/gpiochip*` for that channel

#### Scenario: Gpiod-bound Status LED

- **WHEN** a Status LED channel binding uses scheme `gpiod` with chip `gpiochip3` and offset `9`
- **AND** the channel is set to Steady
- **THEN** HAL SHALL drive that line through the character-device client

#### Scenario: Cutover board without Innohi class

- **WHEN** product config uses scheme `gpiod` and `/sys/class/gpio_innohi` is absent
- **THEN** HAL SHALL still drive Status LED / buzzer through gpiod
- **AND** MUST NOT fail solely because the Innohi sysfs class is missing

### Requirement: Per-binding scheme selection

Each configured line binding SHALL declare which scheme to use at runtime (explicitly, or via document default backend). Optional alternate addressing fields (e.g. both `label` and `gpiod` chip/offset) MAY appear in config for documentation or future switch; runtime SHALL follow the selected scheme only. If gpiod request fails because the line is busy (kernel hog), HAL SHALL surface a structured I/O error and MUST NOT silently corrupt sysfs state.

#### Scenario: Default gpiod with recorded silk label

- **WHEN** product config sets scheme `gpiod` for red and also records silk label `GPIO_5`
- **THEN** HAL SHALL use gpiod for control
- **AND** MUST NOT open a sysfs value node unless scheme is `sysfs_innohi` / `sysfs`

### Requirement: Chip and offset bindings (gpiod scheme)

When scheme is `gpiod`, each binding SHALL identify a GPIO chip (device name and/or label) and a **line offset** within that chip. Global classic linux gpio numbers MAY appear as reference only.

#### Scenario: Resolve ynh960 red via gpiod

- **WHEN** config binds channel `red` to chip `gpiochip3` offset `9` with scheme `gpiod`
- **THEN** HAL SHALL request that chip’s line at offset `9` for the channel

### Requirement: Stub and sim without hardware

When config/backend selects stub, or hardware is unavailable (host unit tests, documented sim), HAL SHALL provide in-memory device behavior that preserves the portable device APIs without requiring `/dev/gpiochip*` or `gpio_innohi`.

#### Scenario: Host unit test Status LED

- **WHEN** tests construct gpio HAL with stub backend
- **AND** set a channel to Blink
- **THEN** the stub SHALL accept the mode and expose observable logical level changes without opening a real gpiochip or sysfs node

### Requirement: Input observation by scheme

Button and rotary encoder devices SHALL obtain level changes according to the binding scheme:

- **gpiod:** consume character-device **signal edge** events (preferred).
- **sysfs_innohi:** MAY use debounced **polling** (or an equivalently documented sysfs observation method) when edges are unavailable; product configs that need reliable encoder steps SHOULD use `gpiod` for those lines.

#### Scenario: Button on gpiod uses edges

- **WHEN** a button device is opened with scheme `gpiod`
- **THEN** HAL SHALL request input with edge triggers and deliver debounced events from that stream

#### Scenario: Button on sysfs uses debounced observation

- **WHEN** a button device is opened with scheme `sysfs_innohi`
- **THEN** HAL SHALL deliver debounced press/release/long-press events from sysfs value observation
- **AND** MUST NOT claim gpiod edge support for that binding
