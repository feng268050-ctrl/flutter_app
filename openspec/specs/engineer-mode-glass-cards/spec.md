# engineer-mode-glass-cards Specification

## Purpose
TBD - created by archiving change engineer-mode-frosted-glass-cards. Update Purpose after archive.
## Requirements
### Requirement: Engineer Mode parameter cards use FrostedGlassCard with transparent background

Engineer Mode parameter screen card containers SHALL use `FrostedGlassCard` with `cardBackground="transparent"` instead of legacy `@mipmap` image backgrounds. Layout dimensions, padding, margins, scroll behavior, and child content MUST remain functionally unchanged.

#### Scenario: Continuous Weld and Spot Weld dual-card layout
- **WHEN** the operator views the Continuous Weld or Spot Weld Engineer Mode tab
- **THEN** the left chart panel MUST be wrapped in `FrostedGlassCard` with `borderGradientCenter="top-left-bottom-right"`
- **AND** the right parameter form panel MUST be wrapped in `FrostedGlassCard` with `borderGradientCenter="bottom-left-top-right"`
- **AND** both cards MUST use transparent background

#### Scenario: Cutting and Cleaning single-card layout
- **WHEN** the operator views the Cutting or Cleaning Engineer Mode tab
- **THEN** the parameter form container MUST be a single `FrostedGlassCard` with `borderGradientCenter="top-left-bottom-right"`
- **AND** the card MUST use transparent background

### Requirement: Engineer Mode Reset and Save actions use FrostButtonView

The Engineer Mode **Reset to Default** and **Save as Common** action controls SHALL use `FrostButtonView` with `borderGradientCenter="top-left-bottom-right"` instead of `@mipmap` button backgrounds. Button labels, start drawables, enabled/disabled states, click handlers, and session baseline / save semantics MUST remain unchanged.

#### Scenario: Reset to Default glass button
- **WHEN** the operator views any Engineer Mode process tab
- **THEN** the Reset to Default control MUST render as `FrostButtonView` with `borderGradientCenter="top-left-bottom-right"`
- **AND** tapping it MUST restore the session baseline as before

#### Scenario: Save as Common glass button
- **WHEN** the operator views any Engineer Mode process tab
- **THEN** the Save as Common control MUST render as `FrostButtonView` with `borderGradientCenter="top-left-bottom-right"`
- **AND** tapping it MUST open the preset name dialog and persist via Save as Common semantics defined in `engineer-mode-common-params`

### Requirement: Engineer Mode selection popups use FrostedGlassPopupMenu

The More Common Specs and Material Type selectors in Engineer Mode SHALL use shared `FrostedGlassPopupMenu` (in-window overlay + `FrostedGlassCard` + `InsetList` rows) instead of legacy `PopupWindow` + `@mipmap/material_popup_bg`. List data, item selection callbacks, and dismiss-on-outside-tap semantics MUST remain unchanged.

#### Scenario: More Common Specs popup chrome
- **WHEN** the operator opens the More Common Specs selector
- **THEN** the popup MUST render as `FrostedGlassPopupMenu` with frosted card chrome
- **AND** the preset list and selection callback MUST behave as before

#### Scenario: Material Type popup chrome
- **WHEN** the operator opens the Material Type selector
- **THEN** the popup MUST render as `FrostedGlassPopupMenu` with frosted card chrome
- **AND** the material list, custom material flow, and selection callback MUST behave as before

#### Scenario: Popup is right-aligned to anchor
- **WHEN** the operator opens More Common Specs or Material Type on any Engineer Mode tab
- **THEN** the popup menu MUST align its trailing edge to the anchor field's trailing edge (within screen bounds)
- **AND** MUST NOT extend past the screen's right edge

#### Scenario: Selected row uses uniform corner highlight
- **WHEN** the operator highlights an item in a multi-row popup list
- **THEN** the selection background MUST use a uniform corner radius on all four corners of that row
- **AND** MUST use the engineer theme orange selection color

#### Scenario: Scrollable popup shows vertical scrollbar
- **WHEN** the popup list content exceeds the configured menu height
- **THEN** the operator MUST be able to scroll the list
- **AND** a vertical scrollbar thumb MUST appear while scrolling

#### Scenario: Custom material opens dialog without crash
- **WHEN** the operator selects **Custom** in the Material Type popup and the material name dialog opens
- **THEN** the application MUST NOT crash during popup dismiss or dialog show
- **AND** the material name `FrostedGlassTextInputDialog` MUST appear as before

