## ADDED Requirements

### Requirement: Settings menu keeps stable order with Date & Time insertion
The Settings navigation in this capability's host flow SHALL preserve existing item order semantics while inserting `Date & Time` immediately after `Screen Settings`.

#### Scenario: Existing entries remain stable around insertion point
- **WHEN** the Settings menu is rendered after this change
- **THEN** items before `Screen Settings` keep their previous relative order
- **AND** `Date & Time` appears directly after `Screen Settings`
- **AND** items previously after `Screen Settings` remain in their relative order after the inserted entry
