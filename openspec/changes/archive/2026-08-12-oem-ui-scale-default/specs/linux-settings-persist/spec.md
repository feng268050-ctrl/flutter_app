## MODIFIED Requirements

### Requirement: UI scale preference under HAL display prefs

The image / HAL SHALL persist operator UI scale at `/var/lib/hal/display.conf` (key `ui_scale`, default `1.0`, supports non-integer values in the same range as HAL `LinuxUiScale`, e.g. `0.5`–`2.0`). **`ui_scale=1.0` SHALL mean physical 1:1** — Flutter MUST NOT apply an additional hard-coded design-density rematch when the value is `1.0`. Values other than `1.0` SHALL be applied as a pure multiplier via `matchEmbedderDensity`. **OS Settings** SHALL expose the UI scale control (factory / after-sales / field service). Product HMI SHALL read the same key at boot and after seat switch — **without** a UI scale slider in HMI Settings Display. This is independent of product text-size (`common-settings.json` `textSize`). When the `ui_scale` key is absent from `display.conf` at HMI launch, the platform SHALL seed it from the active OEM screen pack `default_ui_scale` (via `/run/hmi/screen.env`) before Apps warm-read the preference. Pack-specific defaults include ynh960 panel ~`1.13` and QEMU `sim_virt` ~`1.28` — MUST NOT document or assume a single scale for all form factors (prior QEMU docs that recommended ynh960's ~`1.13` on the virtio guest were incorrect). Once written, operator changes via OS Settings SHALL override the OEM default; factory reset clearing `display.conf` SHALL allow re-seeding on next boot. Apps MUST NOT hard-code panel rematch factors.

#### Scenario: UI scale 1.0 is identity

- **WHEN** `/var/lib/hal/display.conf` has `ui_scale=1.0` (or the key is absent, no OEM default is configured, and runtime falls back to `1.0`)
- **THEN** both OS Settings and product HMI render without FittedBox density rematch from `matchEmbedderDensity`

#### Scenario: UI scale shared across seats

- **WHEN** factory or field service sets UI scale to `1.10` in OS Settings Display
- **AND** switches to product HMI
- **THEN** HMI reads `ui_scale=1.10` from `/var/lib/hal/display.conf` and applies the same density multiplier

#### Scenario: OEM default seeds absent key (ynh960)

- **WHEN** `/var/lib/hal/display.conf` has no `ui_scale` key
- **AND** the active OEM screen pack declares `default_ui_scale=1.13`
- **AND** `hmi-launch` runs after successful `oem-compose`
- **THEN** `display.conf` SHALL contain `ui_scale=1.13` before OS Settings or product HMI warm-read

#### Scenario: OEM default seeds absent key (virt emulator)

- **WHEN** `/var/lib/hal/display.conf` has no `ui_scale` key
- **AND** the active OEM screen pack is `sim_virt` with `default_ui_scale=1.28`
- **AND** `hmi-launch` runs after successful `oem-compose`
- **THEN** `display.conf` SHALL contain `ui_scale=1.28` before OS Settings or product HMI warm-read

#### Scenario: Operator value not overwritten by OEM

- **WHEN** `/var/lib/hal/display.conf` has `ui_scale=1.00` written by the operator
- **AND** the OEM screen pack declares `default_ui_scale=1.13`
- **THEN** subsequent boots SHALL keep `ui_scale=1.00`
