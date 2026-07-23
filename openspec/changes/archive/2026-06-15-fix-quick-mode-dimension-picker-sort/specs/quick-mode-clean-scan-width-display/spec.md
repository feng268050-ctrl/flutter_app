## MODIFIED Requirements

### Requirement: Clean modes right wheel selects by scan width

For Weld Path Clean and Ultra-wide Clean, the right wheel SHALL list distinct `ProcessParametersData.swingWidth` values (null treated as 0) for the current material and gear **in ascending numeric order derived from canonically sorted process rows**, and user selection SHALL update the active scan width used for process lookup.

#### Scenario: Wheel populated from swing width

- **WHEN** process parameters are loaded for a clean mode and material/gear are set
- **THEN** the right wheel entries reflect `swingWidth` values from matching rows, formatted with the same mm/in rules as thickness elsewhere in Quick Mode
- **AND** entries SHALL appear in ascending swing-width order because rows are canonically sorted and deduplicated in traversal order

#### Scenario: Selection sends matching process row

- **WHEN** the user selects a scan width on the right wheel in a clean mode
- **THEN** the app resolves the `ProcessParametersData` row matching material, gear, and selected `swingWidth`, and sends it via the existing Modbus process-config path
