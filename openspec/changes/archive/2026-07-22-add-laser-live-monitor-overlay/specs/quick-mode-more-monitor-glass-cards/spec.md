## ADDED Requirements

### Requirement: More Monitor opens shared Live Monitor overlay body

The quick-mode **More Monitor** entry MUST open the shared Live Monitor overlay body (PR1 preview + detection boxes + compact gauges sidebar) rather than a gauges-only machine-status fragment. Confirm-bar / FrostButton dismiss behavior MUST remain. Dialog-variant frosted gauge and status-tile chrome requirements in this capability MUST continue to apply to the Live Monitor sidebar gauges/tiles.

#### Scenario: More Monitor shows Live Monitor body

- **WHEN** the operator taps **More Monitor** on the quick-mode laser dashboard
- **THEN** the work-status dialog MUST host the Live Monitor overlay body
- **AND** the confirm dismiss control MUST remain available when `showButton=true`
- **AND** sidebar gauges/tiles MUST still satisfy dialog-variant frosted glass chrome

#### Scenario: Engineer gun auto popup shares Live Monitor body

- **WHEN** engineer mode auto-opens the work-status dialog without the confirm button
- **THEN** the dialog MUST host the same Live Monitor overlay body as More Monitor
- **AND** sidebar gauges MUST use the same dialog-variant frosted glass chrome
