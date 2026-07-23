## ADDED Requirements

### Requirement: Production lens det coordinator publishes heavy dirty-alert side effects after laser stop policy

`OpencvStainDetectCoordinator` SHALL publish production dirty-alert side effects for heavy (`level == 2`) results only. Presentation SHALL follow laser-stop timing via shared weld alert controllers, not immediate dialog on infer completion.

#### Scenario: Infer completion sets pending only

- **WHEN** live weld OpenCV stain detect detects heavy contamination in eligible weld scope while laser is ON
- **THEN** the coordinator MUST publish `LensCheckResultEvent` with `level == 2`
- **AND** MUST NOT show a dialog until laser stops

#### Scenario: OpenCV session inactive

- **WHEN** `AiManager.isOpencvStainDetectSessionActive()` is false
- **THEN** production dirty-alert events MUST NOT be published from the live weld path
