## MODIFIED Requirements

### Requirement: Welding Gun two-row layout

In the Welding Gun section, **Gun Comm Status** and **Camera Comm Status** SHALL occupy the first grid row as two adjacent columns (`column 0` and `column 1`). The gun driver board temperature and gun motor temperature tiles SHALL occupy the second grid row in two adjacent columns.

#### Scenario: Welding Gun visual order

- **WHEN** the Alarm Information screen displays the Welding Gun section
- **THEN** Gun Comm Status SHALL appear in the first row first column
- **AND** Camera Comm Status SHALL appear in the first row second column immediately after Gun Comm Status
- **AND** the two temperature metrics SHALL appear together on the second row
