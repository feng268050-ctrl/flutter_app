# global-scrollbar-style Specification

## Purpose
Define the application-wide vertical scrollbar baseline for scrollable pages so scrollbar visuals and display timing remain consistent across the UI.

## Requirements
### Requirement: Vertical scroll containers use the global scrollbar style

Pages that need vertical content scrolling SHALL use the application-wide vertical scrollbar style instead of page-local scrollbar drawable, size, fade, or track overrides. The global style MUST match the Engineer Mode parameter panel baseline: vertical scrollbar, `insideOverlay`, fading enabled, a unified white rounded thumb, and no default visible track.

#### Scenario: Scrollable page adopts global style

- **WHEN** a page uses a `ScrollView` or equivalent vertical scroll container for normal page content
- **THEN** the container MUST apply the global vertical scrollbar style or a style that inherits from it
- **AND** the page MUST NOT directly set a conflicting `scrollbarThumbVertical`, `scrollbarTrackVertical`, `scrollbarStyle`, `scrollbarSize`, or `fadeScrollbars` value

#### Scenario: Existing disclaimer scrollbar resources are not page defaults

- **WHEN** an existing page previously referenced `scrollbar_thumb_disclaimer` or `scrollbar_track_disclaimer` for normal vertical page scrolling
- **THEN** the page MUST migrate to the global vertical scrollbar style
- **AND** the disclaimer resources MUST NOT be used as the default scrollbar appearance for ordinary scrollable pages

### Requirement: Scrollbars appear only after user scrolling

Global vertical scroll containers SHALL keep scrollbars hidden until the user performs a vertical scroll interaction, then allow the system scrollbar fade behavior to display and hide the thumb normally.

#### Scenario: Page opens without scrollbar chrome

- **WHEN** a scrollable page first appears and the user has not scrolled the content
- **THEN** the vertical scrollbar MUST remain hidden

#### Scenario: User scroll reveals scrollbar

- **WHEN** the user scrolls vertically within a global styled scroll container
- **THEN** the unified vertical scrollbar thumb MUST become visible according to Android scrollbar fade behavior
- **AND** the page content MUST continue scrolling normally

### Requirement: Scrollbar unification preserves page layout and behavior

Applying the global vertical scrollbar style SHALL NOT change page content, data loading, click handlers, form validation, persistence, or navigation behavior. Layout dimensions, margins, padding, and `fillViewport`/`clipToPadding` semantics MUST be preserved unless a small right-side spacing adjustment is required to avoid overlaying content.

#### Scenario: Migrated page keeps existing interactions

- **WHEN** a page is migrated from local scrollbar attributes to the global scrollbar style
- **THEN** all existing content, buttons, list items, input fields, and navigation actions MUST continue to behave as before
- **AND** only the scrollbar visual style and display timing may change
