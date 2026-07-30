## MODIFIED Requirements

### Requirement: App environment tier selects candidate set

The system SHALL support distinct candidate sets for at least test and production Worker origins. Test and production candidate lists MUST include the primary `*.lasercyber.workers.dev` base and the `lasercyber.hyurl.com/{test|prod}` fallback. The active tier SHALL be readable from persisted App settings and/or `product.ini` / host `set-prop`. Operators SHALL change the tier from Device Information by tapping Device SN five times within five seconds (lws-ui parity), not via a permanent Settings row.

#### Scenario: Tier change updates candidates on next probe

- **WHEN** the operator or host tooling changes the app environment tier and a new probe round runs
- **THEN** the candidate list MUST match the selected tier
- **AND** a successful probe MUST replace the previous in-memory pin

#### Scenario: SN five-tap opens tier picker

- **WHEN** the operator taps Device SN five times within five seconds on Device Information
- **THEN** the environment tier picker is presented
- **AND** selecting a tier persists it for subsequent probes

#### Scenario: Test tier includes hyurl fallback

- **WHEN** the active tier is test
- **THEN** the ordered candidate list MUST include `https://api-test.lasercyber.workers.dev`
- **AND** MUST include `https://lasercyber.hyurl.com/test`
