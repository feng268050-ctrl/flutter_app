## Context

Advanced Settings and Engineer Mode already use shared FrostedGlass input wrappers for numeric parameter entry. Advanced Settings validation lives in `AdvancedSettingDataCheck`, while dialog construction is centralized in `SettingInputDialogBuilder`. Engineer Mode numeric prompts are centralized in `InputDialogBuilder`, with labels supplied as string resources and units appended through `FrostedGlassNumericInputDialog.Config.titleUnit(...)`. Material selection popups use `DataPopupBuilder` and `DataListPopup.show(...)`.

The requested fixes are UI contract corrections: values must match supported ranges, titles must match the visible row labels, the material selector must open from the correct anchor position, and Chinese tab copy must be corrected. No persistence, Modbus encoding, or process-parameter schema change is required.

## Goals / Non-Goals

**Goals:**

- Pass explicit min/max values from Advanced Settings builders into `FrostedGlassNumericInputDialog.Config` for every supported parameter dialog.
- Update Minimum Gas Pressure Threshold validation and dialog stepping to allow values from 0 through 400 inclusive.
- Keep Engineer Mode dialog titles derived from the same labels shown on the parameter rows, while preserving the existing unit suffix formatting.
- Correct the Engineer Mode Material Type popup vertical placement without changing its selection semantics or list content.
- Update Simplified Chinese copy for the Cut tab to `切割`.

**Non-Goals:**

- No database migration or default-value rewrite.
- No changes to Modbus register addresses, payload order, or process parameter encoding.
- No replacement of the existing FrostedGlass dialog shell or popup component.
- No redesign of Engineer Mode tabs or Advanced Settings layouts beyond the targeted interaction fixes.

## Decisions

1. Keep supported ranges at the builder/check layer and pass them into dialog config.

   `FrostedGlassNumericInputDialog.Config` already supports `minValue(...)` and `maxValue(...)` for stepper clamping. The Advanced Settings builders should use these fields instead of adding a new dialog API. Validation remains the source of truth through `AdvancedSettingDataCheck`, so typed values and stepper values reject the same ranges.

   Alternative considered: add range metadata to the data model. That would be heavier than needed because the affected ranges are static UI/device constraints already encoded in validation.

2. Update Minimum Gas Pressure Threshold as a validation change, not only a UI clamp.

   The max must change anywhere invalid values are rejected. The dialog clamp and `AdvancedSettingDataCheck.checkInletGasPressureThreshold(...)` must agree on 400, and the user-facing max error text must not still say 200.

   Alternative considered: clamp only the stepper to 400. That would leave direct keyboard input inconsistent and would not satisfy the supported setting range.

3. Use visible label resources for Engineer Mode prompt titles.

   Numeric builder call sites should supply the label shown on the row for that parameter. Existing `titleUnit(...)` formatting should remain the only unit presentation path so dialog titles continue to show labels plus units consistently.

   Alternative considered: post-process dialog title strings. That risks drifting from row labels and makes localization harder to verify.

4. Fix material popup position in `DataListPopup`/builder configuration, preserving list behavior.

   The placement bug should be corrected where the material popup is configured or displayed, while avoiding changes to selected item conversion, callback behavior, dismiss handling, and content size unless needed for alignment.

   Alternative considered: adjust individual fragment anchors. That would duplicate layout knowledge across welding, wash, and cutting fragments.

## Risks / Trade-offs

- Range constants can drift between validation and dialog config if duplicated. Mitigation: group each builder's min/max next to its validation call or introduce local named constants in the builder/check class where useful.
- Temperature thresholds depend on unit conversion. Mitigation: pass dialog bounds in the same displayed unit used for the default input and keep validation responsible for final conversion.
- Popup placement changes may affect all material selectors. Mitigation: verify welding, wash, and cutting Material Type dropdowns on the target emulator.
- String changes can affect English resources if applied to the wrong values file. Mitigation: update only Simplified Chinese `values/strings.xml` for the Cut tab copy.
