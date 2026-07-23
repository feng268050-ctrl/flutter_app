## ADDED Requirements

### Requirement: Clean modes show Scan Width label on right picker

When Quick Mode is active for Weld Path Clean or Ultra-wide Clean, the right-side dimension picker beside the circular gauge SHALL display the label from `@string/swing_width_text` (English: "Scan Width") instead of `@string/thickness_text`.

#### Scenario: Weld Path Clean label

- **WHEN** the user is in Quick Mode on Weld Path Clean (`ModelConstant.WELD_CLEAN`)
- **THEN** the right picker title shows Scan Width (`swing_width_text`), not Thickness

#### Scenario: Ultra-wide Clean label

- **WHEN** the user is in Quick Mode on Ultra-wide Clean (`ModelConstant.WIDTH_CLEAN`)
- **THEN** the right picker title shows Scan Width (`swing_width_text`), not Thickness

#### Scenario: Welding modes unchanged

- **WHEN** the user is in Quick Mode on Continuous Welding, Point Welding, or Hand Cutting
- **THEN** the right picker title continues to show Thickness (`thickness_text`)

### Requirement: Clean modes right wheel selects by scan width

For Weld Path Clean and Ultra-wide Clean, the right wheel SHALL list distinct `ProcessParametersData.swingWidth` values (null treated as 0) for the current material and gear, and user selection SHALL update the active scan width used for process lookup.

#### Scenario: Wheel populated from swing width

- **WHEN** process parameters are loaded for a clean mode and material/gear are set
- **THEN** the right wheel entries reflect `swingWidth` values from matching rows, formatted with the same mm/in rules as thickness elsewhere in Quick Mode

#### Scenario: Selection sends matching process row

- **WHEN** the user selects a scan width on the right wheel in a clean mode
- **THEN** the app resolves the `ProcessParametersData` row matching material, gear, and selected `swingWidth`, and sends it via the existing Modbus process-config path

### Requirement: Non-clean modes retain thickness behavior

Modes other than Weld Path Clean and Ultra-wide Clean SHALL continue to use thickness for the right wheel label, values, active state, and `findNowProcessParametersData` matching.

#### Scenario: Continuous welding thickness

- **WHEN** the user is in Quick Mode on Continuous Welding
- **THEN** the right picker shows Thickness and selects process rows by `thickness` as before this change
