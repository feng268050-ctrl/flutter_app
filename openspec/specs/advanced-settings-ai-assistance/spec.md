# advanced-settings-ai-assistance Specification

## Purpose
TBD - created by archiving change add-ai-assistance-advanced-settings. Update Purpose after archive.
## Requirements
### Requirement: Advanced Settings exposes AI Assistance toggle group

The Advanced Settings page SHALL include a titled group **AI Assistance** containing two Switch controls:

| Control | Persisted field | Default |
|---------|-----------------|---------|
| Lens Contamination Detection | `lensContaminationDetectionEnabled` | ON (true) |
| Zero Point Offset Detection | `zeroPointOffsetDetectionEnabled` | ON (true) |

Both fields SHALL be stored in `t_advanced_settings`. Labels MUST be localized (EN: group **AI Assistance**, items **Lens Contamination Detection** and **Zero Point Offset Detection**; ZH equivalents in `values-zh`).

#### Scenario: User views AI Assistance group

- **WHEN** the user opens Advanced Settings
- **THEN** the page displays the AI Assistance group below Temperature Thresholds
- **AND** both switches reflect persisted values from `t_advanced_settings`

#### Scenario: User disables lens contamination detection

- **WHEN** the user turns OFF Lens Contamination Detection
- **THEN** the app persists `lensContaminationDetectionEnabled` false in `t_advanced_settings`
- **AND** live-weld lens contamination inference SHALL NOT run on subsequent laser-on sessions until re-enabled
- **AND** no Modbus device-setting write is sent solely because this toggle changed

#### Scenario: User disables zero point offset detection

- **WHEN** the user turns OFF Zero Point Offset Detection
- **THEN** the app persists `zeroPointOffsetDetectionEnabled` false in `t_advanced_settings`
- **AND** laser-on zero-point detect rounds SHALL NOT run on subsequent laser-on sessions until re-enabled
- **AND** no Modbus device-setting write is sent solely because this toggle changed

#### Scenario: Fresh install defaults both toggles on

- **WHEN** the app creates the default `t_advanced_settings` row on first access
- **THEN** `lensContaminationDetectionEnabled` MUST be true
- **AND** `zeroPointOffsetDetectionEnabled` MUST be true

### Requirement: AI assistance toggles gate production laser-on coordinators

When **Lens Contamination Detection** is disabled, `OpencvStainDetectCoordinator` SHALL NOT invoke live-weld stain detect inference and SHALL NOT set production heavy dirty-alert pending from the live weld path.

When **Zero Point Offset Detection** is disabled, `ZeroPointDetectCoordinator` SHALL NOT start laser-on rounds, SHALL NOT sample PR1 frames for production zero-point detect, SHALL NOT finalize rounds with Modbus 0090H writes, and SHALL NOT set zero-point offset alert pending.

Manual Auto zero-point correction initiated from Advanced Settings SHALL remain available regardless of the Zero Point Offset Detection toggle.

#### Scenario: Lens toggle off skips live stain detect

- **WHEN** `lensContaminationDetectionEnabled` is false
- **AND** laser is ON in eligible production weld scope
- **THEN** the live PR1 stain detect coordinator SHALL NOT call `opencvStainDetectFromI420`
- **AND** production heavy dirty-alert pending MUST NOT be set from live weld stain detect

#### Scenario: Zero point toggle off skips laser-on round

- **WHEN** `zeroPointOffsetDetectionEnabled` is false
- **AND** laser transitions OFF to ON in eligible production scope
- **THEN** no zero-point detect round SHALL start
- **AND** no PR1 zero-point samples SHALL run while laser remains ON

#### Scenario: Zero point toggle off skips correction and alert

- **WHEN** `zeroPointOffsetDetectionEnabled` is false for the entire laser-on session
- **AND** laser transitions ON to OFF
- **THEN** the app MUST NOT apply automatic 0090H correction for that session
- **AND** MUST NOT set zero-point offset alert pending for that session

#### Scenario: Manual Auto unaffected by zero point toggle

- **WHEN** `zeroPointOffsetDetectionEnabled` is false
- **AND** the operator starts Zero Offset Manual Auto from Advanced Settings
- **THEN** Manual Auto detection and correction flow SHALL proceed per existing Advanced Settings behavior

