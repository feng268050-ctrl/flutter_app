## ADDED Requirements

### Requirement: AI Vision shows lens dirty alert dialogs from native check results

The system SHALL present user-visible alert dialogs on the AI Vision screen when `LensCheckResultEvent` is received on the main thread, using **`level`** as the primary driver and **`message`** as the preferred body text when non-empty, as specified in repository **`docs/LENS_GUARD_APP_INTEGRATION.md`** §6. The system MUST NOT recompute contamination levels in Java.

#### Scenario: Heavy contamination shows blocking-style alert

- **WHEN** AI Vision is at least `STARTED` and `LensCheckResultEvent` carries `level >= 2`
- **THEN** the system SHALL show an alert dialog whose content prioritizes non-empty `message`, otherwise the documented default heavy text, and the visual treatment SHALL be distinct from mild (e.g., stronger emphasis / error styling as defined in implementation)
- **AND** the system SHALL apply de-duplication so repeated `level >= 2` events within a configured minimum interval do not stack multiple dialogs unless `level` increases

#### Scenario: Mild contamination shows advisory alert

- **WHEN** AI Vision is at least `STARTED` and `LensCheckResultEvent` carries `level == 1`
- **THEN** the system SHALL show an advisory alert dialog (or update an existing visible advisory dialog without stacking duplicates per de-duplication rules) prioritizing non-empty `message`, otherwise the documented default mild text

#### Scenario: Clean result dismisses dirty alerts

- **WHEN** `LensCheckResultEvent` carries `level == 0`
- **THEN** the system SHALL not open a new “clean” alert dialog for normal operation
- **AND** the system SHALL dismiss or clear any visible dirty alert dialog tied to this flow so the UI returns to normal state

#### Scenario: No dialog when fragment cannot interact

- **WHEN** AI Vision is not resumed, not added, or host context is unavailable
- **THEN** the system SHALL not show a window-leaking dialog for that event

#### Scenario: Alert sound policy for heavy level

- **WHEN** `level >= 2` and alert sound is triggered per product rules
- **THEN** the system SHALL follow a single documented policy to avoid double-playing the same alarm (either native `onAlert` only or App-only), consistent with `docs/LENS_GUARD_APP_INTEGRATION.md` §6.3
