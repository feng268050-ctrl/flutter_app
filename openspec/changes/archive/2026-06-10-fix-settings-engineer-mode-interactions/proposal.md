## Why

Advanced Settings and Engineer Mode currently expose several parameter-entry details that do not match the supported device limits or the labels shown in the UI. This creates confusing validation behavior and visible localization/layout regressions in high-use operator workflows.

## What Changes

- Constrain Advanced Settings numeric input dialogs with each setting's supported minimum and maximum values.
- Set the Advanced Settings Minimum Gas Pressure Threshold maximum to 400.
- Restore the Engineer Mode Material Type dropdown popup position so it appears aligned with the field instead of shifted downward.
- Use the on-screen parameter label as the title for Engineer Mode numeric input dialogs while preserving unit display.
- Change the Chinese translation of the Engineer Mode Cut tab to `切割`.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `parameter-settings`: Advanced Settings validation and dialog limits must reflect supported setting ranges, including a 400 maximum for minimum gas pressure threshold.
- `frosted-glass-numeric-input-dialog`: Numeric input dialog titles and min/max configuration must preserve existing units while matching the setting label and supported range.
- `engineer-mode-common-params`: Engineer Mode material selector placement, numeric prompt titles, and Cut tab localization must match the visible UI contract.

## Impact

- Affected Android UI code includes Advanced Settings setting builders, Engineer Mode parameter rows, material selector popup/dropdown positioning, and string resources.
- Persistence, Modbus write semantics, process parameter encoding, and existing FrostedGlass dialog shell behavior are expected to remain unchanged.
