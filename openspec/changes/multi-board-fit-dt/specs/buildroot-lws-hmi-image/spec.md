## ADDED Requirements

### Requirement: Multi-configuration FIT packaging for family Image

The lws-hmi kernel packaging path SHALL generate dual A/B FITs using a multi-configuration ITS that supports multiple board FDTs sharing one `Image`. Lunch/board config MAY keep a default DTS of `ynh960` for validation, but MUST NOT permanently encode “exactly one anonymous `fdt`/`conf` pair” as the only supported FIT shape. Emulator publication of a bare `Image` alongside FITs remains required.

#### Scenario: build-kernel emits multi-conf-capable FITs

- **WHEN** `make build-kernel` completes after this change
- **THEN** `output/firmware/boot.img` and `boot_b.img` SHALL be FIT images whose configurations are named per board inventory (default `ynh960`)
- **AND** a bare `Image` SHALL still be published for the P3.2 emulator path
