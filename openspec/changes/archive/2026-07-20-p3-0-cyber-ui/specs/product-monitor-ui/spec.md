## ADDED Requirements

### Requirement: Monitor prefers CyberUI for status and glass chrome

Where Monitor shows Cyber status lights or frosted panels, it SHALL use CyberUI components (`CyberStatusIndicator` or successors) once `packages/cyber_ui` is adopted. Layout shells MAY remain Material.

#### Scenario: Alarm status lights use CyberUI indicator

- **WHEN** Monitor Alarm Information shows status lights after CyberUI migration
- **THEN** those lights are built from CyberUI status APIs rather than a one-off feature-local indicator fork

## MODIFIED Requirements

### Requirement: Monitor uses Material stand-in UI

Monitor MAY use Flutter Material for page layout and tabs. Frost / status glass chrome SHALL use CyberUI when the capability is migrated; Monitor MUST NOT require a second in-app glass kit parallel to `packages/cyber_ui`.

#### Scenario: Monitor opens with Material shell

- **WHEN** the user navigates to Monitor on the current Flutter pin
- **THEN** the Monitor screen renders with Material-based layout/tabs and remains usable

#### Scenario: Glass chrome not forked in Monitor

- **WHEN** Monitor needs frosted or Cyber status chrome after CyberUI adoption
- **THEN** it depends on `packages/cyber_ui` rather than maintaining a separate Monitor-only glass implementation
