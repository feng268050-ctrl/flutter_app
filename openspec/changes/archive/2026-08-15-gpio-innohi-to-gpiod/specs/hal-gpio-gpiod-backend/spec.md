## MODIFIED Requirements

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
