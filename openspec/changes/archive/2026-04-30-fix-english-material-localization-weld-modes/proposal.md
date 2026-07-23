## Why

When app language is set to English, Continuous Weld and Spot Weld still show Chinese material names in the material selector and current process name area. This creates an inconsistent bilingual UI and can cause operator confusion during parameter selection.

## What Changes

- Ensure material names shown in weld-mode UI (including dropdown options and selected material display) follow active app language resources.
- Remove/replace hardcoded Chinese material labels in English resource paths used by weld-mode screens.
- Align English locale assets so material labels are fully localized for the weld-mode workflow.

## Capabilities

### New Capabilities
- `weld-mode-material-localization`: Defines locale-correct material label rendering for Continuous Weld and Spot Weld parameter screens.

### Modified Capabilities
- None.

## Impact

- Affected resources: `app/src/main/res/values-en/strings.xml` and related localized string arrays.
- Potentially affected UI layouts/adapters where material text is hardcoded.
- No API changes, protocol changes, or dependency changes.
