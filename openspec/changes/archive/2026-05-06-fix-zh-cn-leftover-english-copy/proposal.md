## Why

After switching app language to Simplified Chinese, parts of the engineer weld UI still show English copy. This causes mixed-language UX and can confuse operators during parameter selection and editing.

## What Changes

- Audit and fix Simplified Chinese text resources used by weld-mode process parameter screens and related dialogs.
- Ensure locale switch to `zh-CN` renders Chinese copy for static labels and default/edit-prefill labels in Continuous Weld and Spot Weld flows.
- Keep business logic, process IDs, and persistence semantics unchanged; only fix display localization behavior.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `weld-mode-material-localization`: Extend requirements so switching to Simplified Chinese must not leave English copy in weld-mode labels, selector entries, or edit default text.

## Impact

- Affected Android resource entries in `values-zh` and potentially fallback `values` usage paths.
- Affected weld-mode UI text-binding/rendering paths in engineer mode.
- No API/protocol changes and no database schema changes.
