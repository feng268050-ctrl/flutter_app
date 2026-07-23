## MODIFIED Requirements

### Requirement: Forget-network actions match Safety Operation Tips primary button styling

The system SHALL present the forget-network confirmation dialog using `FrostedGlassDialog` (雾化玻璃设计 shell with live backdrop blur), with title, message, and Confirm/Cancel actions in the standard frosted-glass action slot or equivalent custom action bar consistent with other migrated settings prompts.

#### Scenario: Forget confirmation dialog uses FrostedGlass shell

- **WHEN** the user triggers `Forget` from the WiFi details page
- **THEN** the confirmation dialog MUST be shown via `FrostedGlassDialog.prompt(...)`
- **AND** MUST NOT use a standalone legacy `Dialog` window as the primary visual container

#### Scenario: Confirm and cancel actions follow app-standard button pattern

- **WHEN** the forget-network confirmation dialog is displayed
- **THEN** both `Confirm` and `Cancel` actions use frosted-glass action button styling
- **AND** enabled/disabled states keep consistent contrast and visual affordance with other migrated settings dialogs
