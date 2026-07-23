## ADDED Requirements

### Requirement: Parameter settings pages use the global scrollbar style

Parameter and Advanced Settings pages that require vertical scrolling SHALL use the global vertical scrollbar style and MUST NOT define page-local scrollbar thumb, track, size, style, or fade behavior that differs from the global baseline.

#### Scenario: Advanced Settings scroll area uses global scrollbar

- **WHEN** the user opens the Advanced Settings page and its content is vertically scrollable
- **THEN** the scroll area MUST use the global vertical scrollbar style
- **AND** the parameter controls and validation behavior MUST remain unchanged

#### Scenario: Parameter detail pages use global scrollbar

- **WHEN** the user opens a process or parameter details page with vertically scrollable content
- **THEN** the page MUST use the global vertical scrollbar style for the scrollable content area
- **AND** existing page content, delete actions, video/detail panels, and navigation behavior MUST remain unchanged
