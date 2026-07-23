## Why

Under English locale, clicking the jump action to edit process parameter name still opens with a Chinese default value (for example, material-based default names). This breaks language consistency and increases operator confusion during quick edits.

## What Changes

- Ensure process-name edit entry points in engineer mode use locale-correct default display names when app language is English.
- Normalize default process/material-derived names shown in the input dialog so they are localized before rendering.
- Preserve existing stored process IDs and parameter semantics; change only display/default text behavior.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `weld-mode-material-localization`: Extend requirements to cover jump/edit default process-name text so English locale never pre-fills Chinese labels in Continuous Weld and Spot Weld flows.

## Impact

- Affected engineer-mode jump/edit flow (input dialog defaults).
- Affected weld-mode view-model/display conversion path used to derive current/default process name.
- No protocol/API changes. No DB schema changes.
