## REMOVED Requirements

### Requirement: Home shows temperature readings

**Reason**: Host SoC/GPU thermal (and related engineering FPS metrics) move to the global system status card overlay. Welding-gun / alarm temperatures remain on Monitor Alarm Information and MUST NOT be reintroduced as a Home requirement.

**Migration**: Use `system-status-overlay` for SoC/GPU and host engineering metrics; use Monitor Alarm Information for gun sensor temperatures.

## ADDED Requirements

### Requirement: Home does not host engineering perf HUD

Product Home MUST NOT present the Home-local engineering perf HUD strip (single-line UI/raster/panel FPS + SoC/GPU temperatures). Those host metrics SHALL be provided by the global system status card overlay when Show System Status Overlay is enabled. Home first paint MUST remain free of blocking sysInfo I/O. By default (preference off), Home SHALL NOT show host engineering FPS/thermal chrome.

#### Scenario: Home has no local perf HUD strip

- **WHEN** the user views product Home after this change
- **THEN** Home does not render the former top-left single-line FPS + SoC/GPU engineering strip as a Home-owned widget

#### Scenario: Host metrics available via overlay when enabled

- **WHEN** Show System Status Overlay is enabled
- **AND** the user views any product route
- **THEN** UI/raster/panel FPS and SoC/GPU temperatures are available via the global system status card without opening the Demo route
