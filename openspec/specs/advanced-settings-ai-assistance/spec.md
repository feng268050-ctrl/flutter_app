# advanced-settings-ai-assistance Specification

## Purpose

Lens / zero-point AI assistance toggles — App persistence, defaults, and facade APIs for production AI paths.
## Requirements
### Requirement: AI Assistance toggles persist App-side with lws-ui defaults

Advanced Settings SHALL expose an **AI Assistance** group with two CyberUI switches:

| Control | Key | Default |
|---------|-----|---------|
| Lens Contamination Detection | `lensContaminationDetectionEnabled` | ON |
| Zero Point Offset Detection | `zeroPointOffsetDetectionEnabled` | ON |

Values SHALL persist in the App advanced-settings store under `/var/lib/hmi/` (not Misc JSON, not Modbus). Toggling MUST NOT issue a Modbus write solely because the switch changed.

#### Scenario: Disable lens contamination

- **WHEN** the operator turns Lens Contamination Detection OFF
- **THEN** the store persists false
- **AND** no Modbus write is sent for that toggle alone

#### Scenario: Fresh defaults

- **WHEN** the advanced-settings store is created with no file
- **THEN** both AI assistance toggles default to ON

### Requirement: AI assistance gates production AI via App facade

The App SHALL expose a read facade (e.g. `AiAssistanceSettings`) that production AI paths consult. When lens contamination detection is disabled, live-weld lens contamination inference and production heavy dirty-alert pending from that path MUST NOT run. When zero-point offset detection is disabled, production laser-on zero-point rounds MUST NOT start and MUST NOT apply automatic offset correction / pending alert for that session. Manual Zero Offset Auto initiated from Advanced Settings SHALL remain available regardless of the zero-point toggle.

#### Scenario: Facade read by coordinators

- **WHEN** a production stain or zero-point coordinator evaluates whether to run
- **THEN** it SHALL read the App AI assistance facade
- **AND** MUST NOT read switch widget state directly

#### Scenario: Manual Auto unaffected

- **WHEN** zero-point offset detection is OFF
- **AND** the operator starts Manual Auto from Advanced Settings
- **THEN** Manual Auto MAY proceed
