## MODIFIED Requirements

### Requirement: Forget-network actions match Safety Operation Tips primary button styling

The system SHALL present the forget-network confirmation dialog in the same visual style family as the app's Date & Time timezone selection dialog, including dialog container shape, title/body typography hierarchy, and action button layout/spacing, so that the WiFi flow is visually consistent with other settings dialogs.

#### Scenario: Forget confirmation dialog follows app-standard dialog style
- **WHEN** the user triggers `Forget` from the WiFi details page
- **THEN** the confirmation dialog uses the same style pattern as the Date & Time timezone dialog rather than an isolated custom style
- **AND** title and message text follow the app-standard typography hierarchy used by that dialog family

#### Scenario: Confirm and cancel actions follow app-standard button pattern
- **WHEN** the forget confirmation dialog is displayed
- **THEN** both `Confirm` and `Cancel` actions use the app-standard action button styling and spacing used by the Date & Time timezone dialog
- **AND** enabled/disabled states keep consistent contrast and visual affordance with that shared style
