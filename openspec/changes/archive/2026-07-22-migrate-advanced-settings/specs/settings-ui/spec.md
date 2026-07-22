## ADDED Requirements

### Requirement: Advanced Settings tab is live product content

Once Advanced Settings migration for this change is applied, the Advanced Settings tab SHALL present the live Advanced Settings UI (sections and CyberUI toggles) rather than a placeholder-only pane. Custom Home Page MAY remain a placeholder.

#### Scenario: Advanced is not placeholder-only

- **WHEN** the user opens Advanced Settings after this capability lands
- **THEN** AI Assistance and Dangerous Operations controls are interactive
- **AND** the tab MUST NOT show only the deferred-migration placeholder text
