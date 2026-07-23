## ADDED Requirements

### Requirement: Work Information panel shows Process Type and Material Type labels

The AI Vision left **Work Information** panel SHALL label its first two data rows **Process Type** and **Material Type** (localized per app locale). The panel MUST NOT label these rows as Detection Type or Work Mode.

#### Scenario: English labels

- **WHEN** the device locale is English
- **THEN** the first row label MUST read “Process Type”
- **AND** the second row label MUST read “Material Type”

#### Scenario: Values are not static placeholders

- **WHEN** the AI Vision screen is shown
- **THEN** the Process Type value MUST NOT be a hardcoded lens or detection placeholder string
- **AND** both value fields MUST be updated by application logic

### Requirement: Process Type and Material Type use enum display text

Displayed values for Process Type and Material Type SHALL use the same human-readable enum mappings as elsewhere in the LWS UI (e.g. `ModelConstant` for process type; material type helpers including custom material names).

#### Scenario: Known process type enum

- **WHEN** the resolved process type code maps to a known welding/cleaning/cutting mode
- **THEN** the Process Type row MUST show the corresponding localized mode name (e.g. continuous welding, point welding)

#### Scenario: Known material type enum

- **WHEN** the resolved material type code maps to a known material enum
- **THEN** the Material Type row MUST show the corresponding localized material name

#### Scenario: Custom material name

- **WHEN** resolved process parameters indicate a custom material with a non-empty `materialName`
- **THEN** the Material Type row MUST show that custom name (localized when applicable per existing material display rules)

### Requirement: Recorded video selection populates work information from video metadata

When the operator selects an inference-recorded process video on AI Vision, the system SHALL resolve Process Type and Material Type from the video record before display.

#### Scenario: Prefer processParameters JSON

- **WHEN** the selected `ProcessParamsVideo` row has non-empty valid `processParametersJson`
- **THEN** Process Type and Material Type MUST be taken from the parsed `ProcessParametersData` object
- **AND** column-only values MUST be ignored when the JSON supplies a field

#### Scenario: Fallback to row columns

- **WHEN** `processParametersJson` is absent, empty, or invalid
- **THEN** Process Type MUST fall back to the row `processType` column when present
- **AND** Material Type MUST fall back to the row `materialType` column when present

#### Scenario: Recording time unchanged

- **WHEN** a video is selected with a valid `createTime`
- **THEN** the Recording Time row MUST continue to show the formatted recording date as today

### Requirement: Live RTSP detection uses in-memory process parameter snapshot

When AI Vision live RTSP preview/detection is active on the page, Process Type and Material Type SHALL be read from the latest in-memory process-parameters snapshot (`ProcessParametersSnapshotStore` or equivalent shared store updated by quick/engineer parameter flows).

#### Scenario: Snapshot provides both fields

- **WHEN** live RTSP detection is active and the snapshot contains `processType` and `materialType`
- **THEN** both Work Information rows MUST reflect the snapshot values using enum display text

#### Scenario: Live takes precedence over selected video metadata

- **WHEN** live RTSP detection is active and a process video is also selected
- **THEN** Process Type and Material Type MUST reflect the live snapshot, not the selected file metadata

#### Scenario: Snapshot field missing

- **WHEN** live RTSP detection is active and the snapshot is null or lacks a given field
- **THEN** the missing field MUST display `-`

### Requirement: Unresolved values display as dash

If Process Type or Material Type cannot be resolved for the active context (no video selected and no live snapshot field; null enum; unknown code), the system SHALL display a single hyphen character `-` for that row.

#### Scenario: No video and no live context

- **WHEN** no process video is selected and live RTSP work-info source is not active
- **THEN** both Process Type and Material Type MUST show `-`

#### Scenario: Partial video metadata

- **WHEN** a video is selected but only `processType` is available
- **THEN** Process Type MUST show the enum label
- **AND** Material Type MUST show `-`

### Requirement: AI Vision video selection copy uses Select wording

User-visible strings for choosing a recording on AI Vision SHALL use “Select” terminology instead of “Choose” in English, with equivalent updates in Chinese resources.

#### Scenario: Select Video button

- **WHEN** the Work Information panel action button is shown
- **THEN** its label MUST read “Select Video” in English

#### Scenario: Player empty prompt

- **WHEN** no video is selected and the player area shows the first-time prompt
- **THEN** the English prompt MUST instruct the user to select a video (word “select”, not “choose”)
