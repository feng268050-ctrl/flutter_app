## ADDED Requirements

### Requirement: Camera settings primary actions use HmiButton

IP Camera Settings primary operator actions (e.g. connect / record / stop equivalents presented as buttons on that page) SHALL use `HmiButton` rather than Material `FilledButton` / `TextButton` for those CTAs.

#### Scenario: Settings CTA is HmiButton

- **WHEN** the operator views primary actions on IP Camera Settings
- **THEN** those CTAs are `HmiButton` instances
