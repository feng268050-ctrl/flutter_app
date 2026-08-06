## ADDED Requirements

### Requirement: Network list actions use HmiButton

Connect / cancel-style actions in the shared Wi‑Fi network list presentation SHALL use `HmiButton` rather than Material `FilledButton` or `TextButton` for those roles.

#### Scenario: Connect action chrome

- **WHEN** the Wi‑Fi network list presents a primary connect action to the operator
- **THEN** that action is an `HmiButton`
