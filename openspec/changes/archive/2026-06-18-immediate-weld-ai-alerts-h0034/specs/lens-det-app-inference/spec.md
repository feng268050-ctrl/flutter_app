## MODIFIED Requirements

### Requirement: Production lens det coordinator publishes heavy dirty-alert side effects immediately

`OpencvStainDetectCoordinator` SHALL publish production dirty-alert side effects for heavy (`level == 2`) results only. Presentation SHALL follow **immediate** L001 coded-alarm policy via `LensHeavyContaminationWarnAlarm`, not deferred dialog on laser stop.

#### Scenario: Infer completion shows L001 immediately in eligible scope

- **WHEN** live weld OpenCV stain detect detects heavy contamination in eligible weld scope
- **THEN** the coordinator MUST publish `LensCheckResultEvent` with `level == 2`
- **AND** `LensHeavyContaminationWarnAlarm` MUST show the L001 passive warn dialog when scope and toggles allow
- **AND** MUST NOT wait for laser to turn OFF

#### Scenario: OpenCV session inactive

- **WHEN** `AiManager.isOpencvStainDetectSessionActive()` is false
- **THEN** production dirty-alert events MUST NOT be published from the live weld path

## REMOVED Requirements

### Requirement: Production lens det coordinator publishes heavy dirty-alert side effects after laser stop policy

**Reason**: Replaced by immediate L001 presentation requirement above.

**Migration**: Remove `WeldDeferredWarnCoordinator` laser falling-edge drain.
