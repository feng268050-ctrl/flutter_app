## MODIFIED Requirements

### Requirement: Home provides Settings entry

The Home screen SHALL provide a visible Settings affordance that navigates to the product Settings route, and a visible Monitor affordance that navigates to the product Monitor route. Home MUST NOT, in this capability, require Quick Mode, Engineer Mode, AI Vision, metric stat cards, or status-bar chrome as full product flows (display-only stubs MAY exist for Quick/Engineer).

#### Scenario: Settings entry navigates

- **WHEN** the user activates the Settings entry on Home
- **THEN** the app navigates to the Settings route

#### Scenario: Monitor entry navigates

- **WHEN** the user activates the Monitor entry on Home
- **THEN** the app navigates to the Monitor route

#### Scenario: Deferred home chrome absent

- **WHEN** the user views Home after this change
- **THEN** Quick Mode, Engineer Mode, AI Vision, and the four customizable stat cards are not required to be present as full product flows (display-only stubs MAY exist)
