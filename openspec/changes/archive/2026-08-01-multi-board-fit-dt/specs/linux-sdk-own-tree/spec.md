## ADDED Requirements

### Requirement: Multi-board DTS inventory in overlay SoT

Until S4 commit of `linux-sdk/`, git SoT under `overlay/kernel/` SHALL support **multiple** product board DTS/DTSI sets for the SoC family (not only `ynh960-*` includes). `apply-overlay` / squash SHALL install all inventoried board device-tree sources needed to build the corresponding DTBs for the shared family `Image`. Colleagues MUST sync board DT changes via overlay PRs the same way as today’s ynh960 fragments.

#### Scenario: Overlay lists more than one board target

- **WHEN** the SoC-family board inventory contains more than one board id
- **THEN** `overlay/kernel/` (and apply-overlay wiring) SHALL provide the DTS/DTSI inputs for each listed board
- **AND** `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` SHALL install those inputs into the owned SDK tree used by `make build-kernel`
