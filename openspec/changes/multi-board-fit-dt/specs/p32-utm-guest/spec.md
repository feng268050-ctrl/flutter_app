## ADDED Requirements

### Requirement: Emulator does not use product FIT multi-conf

The P3.2 emulator SHALL continue to boot the bare kernel `Image` with QEMU `-machine virt` providing the guest device tree. It MUST NOT require a `conf-sim` (or similar) entry inside the product `boot.img` FIT for guest boot.

#### Scenario: Emulator ignores product FIT DT list

- **WHEN** an operator runs `make build-emulator` / `make emulator` after multi-configuration product FITs exist
- **THEN** the guest SHALL still start from the published bare `Image` + QEMU virt DT
- **AND** MUST NOT depend on extracting a board FDT from `boot.img` for the virt machine
