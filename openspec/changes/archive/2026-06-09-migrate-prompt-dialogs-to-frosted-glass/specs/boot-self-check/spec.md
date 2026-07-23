## MODIFIED Requirements

### Requirement: Self-check dialog appends items and status incrementally

During boot self-check, the app SHALL display a self-check progress dialog hosted by `FrostedGlassDialog` with a custom body that lists each check item. For every item, the dialog SHALL first append the item label with status **checking**, then update that row to **pass** or **fail** when the check completes. Manual close, auto-dismiss, and "do not show again" behavior MUST remain equivalent to the pre-migration `BootSelfCheckDialog`.

#### Scenario: Self-check dialog uses FrostedGlass overlay

- **WHEN** boot self-check starts on first home entry
- **THEN** the progress dialog MUST render as a `FrostedGlassDialog` overlay with incremental item rows in the custom body slot
- **AND** MUST NOT use a standalone legacy `Dialog` window as the primary visual container

#### Scenario: Item transitions from checking to pass

- **WHEN** a check item begins execution
- **THEN** the dialog SHALL append a row with the localized item name and status **checking**
- **WHEN** the item evaluation concludes healthy
- **THEN** that row SHALL update to status **pass**
