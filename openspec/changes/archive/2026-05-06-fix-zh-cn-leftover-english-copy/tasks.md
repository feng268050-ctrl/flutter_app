## 1. Audit zh-CN localization gaps in weld-mode flows

- [x] 1.1 Identify all user-visible weld-mode labels/dialog texts that remain English after switching to Simplified Chinese.
- [x] 1.2 Map each leftover English text to its source (resource key, hardcoded string, or runtime default/persisted value).

## 2. Implement locale-consistent Chinese display behavior

- [x] 2.1 Correct `values-zh` resource entries for affected weld-mode strings and remove unintended English fallbacks.
- [x] 2.2 Ensure Continuous Weld / Spot Weld selector entries and selected/current material text resolve to Chinese in `zh-CN`.
- [x] 2.3 Ensure process-name edit default prefill in jump flow resolves to Chinese for known built-in labels while preserving custom user-defined names.

## 3. Validate bilingual regressions

- [x] 3.1 Validate on device in Simplified Chinese: no leftover English copy in targeted weld-mode labels, selectors, and edit-prefill dialogs.
- [x] 3.2 Validate in English locale: existing English labels remain correct and unchanged.
- [x] 3.3 Regression-check that localization remains display-only and does not alter material encoding/process persistence semantics.
