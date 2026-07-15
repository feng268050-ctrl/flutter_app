## ADDED Requirements

### Requirement: Demo exposes Date & Time section

The P2 demo SHALL include a **Date & Time** section that:

1. Displays the current wall clock (updating while the section is visible)
2. Allows editing date and time for **manual** apply
3. Allows selecting timezone from a curated list that includes at least `UTC` and `Asia/Shanghai`
4. Offers **Manual** vs **Network** sync mode controls
5. Offers **Apply** (manual set) and **Sync Now** (network sync) actions wired to `DateTimeController`

Failures MUST show a non-fatal status/error string and MUST NOT crash the demo. Initialization of the section MUST NOT block first paint (post-frame / after network sections pattern is acceptable).

#### Scenario: Section visible

- **WHEN** the user scrolls to the Date & Time demo section after it has initialized
- **THEN** current time, mode controls, timezone control, Apply, and Sync Now are visible

#### Scenario: Apply sets manual time

- **WHEN** the user enters a valid date/time and taps Apply
- **THEN** the date/time controller is asked to set the wall clock (and mode becomes manual per platform rules)

#### Scenario: Sync Now requests network sync

- **WHEN** the user taps Sync Now
- **THEN** the date/time controller is asked to sync from the network and the section shows success or a structured failure message

#### Scenario: Mode toggle persists via controller

- **WHEN** the user selects Network mode
- **THEN** the date/time controller is asked to set sync mode to `network`
