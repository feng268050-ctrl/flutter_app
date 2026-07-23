## ADDED Requirements

### Requirement: Left panel metric grids use at most two columns

On the Alarm Information screen left status panel (`fragment_warn_info.xml`), every `GridLayout` that lays out metric/status tiles SHALL use a maximum of two columns (`columnCount` 2 or equivalent), and individual metric tiles SHALL be laid out with wider nominal width than the previous 224dp three-column arrangement so English labels wrap less frequently.

#### Scenario: Laser Device and Wire Feeder grids

- **WHEN** the Alarm Information screen renders the Laser Device or Wire Feeder sections
- **THEN** each section’s metric `GridLayout` SHALL declare at most two columns and SHALL not arrange more than two metric tiles side-by-side in the same row.

### Requirement: Welding Gun group row layout

In the Welding Gun section, the **Gun Comm Status** tile SHALL occupy the first grid row alone and SHALL span the full width of the two-column grid. The gun driver board temperature tile and the gun motor temperature tile SHALL occupy the second grid row as two adjacent columns.

#### Scenario: Welding Gun visual order

- **WHEN** the Alarm Information screen displays the Welding Gun section
- **THEN** the Gun Comm Status control SHALL appear on the first row with no other Welding Gun metric beside it in that row, and the two temperature metrics SHALL appear together on the second row.

### Requirement: Alarm bindings and behavior unchanged

The change SHALL preserve existing data binding expressions, checkbox checked state logic, and enabled flags for all alarm tiles; only layout attributes (rows, columns, spans, widths, margins) MAY change.

#### Scenario: No logic regression

- **WHEN** device status and device data update on the Alarm Information screen
- **THEN** each tile SHALL continue to reflect the same alarm and value semantics as before this layout change.
