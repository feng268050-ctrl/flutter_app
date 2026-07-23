## MODIFIED Requirements

### Requirement: Heavy production dirty alert shows immediately in production weld modes

Production heavy lens dirty alerts (`level >= 2` from RKNN callback or live OpenCV stain detect) SHALL be shown as soon as a heavy episode is recorded while production weld scope is active (Quick Mode or Engineer Mode continuous welding or spot welding). The system MUST NOT defer the warn dialog until laser stops or wait for a laser falling edge.

#### Scenario: Dialog on heavy detect during laser on

- **WHEN** a heavy dirty event is recorded while laser is ON
- **AND** production weld scope is active
- **AND** `lensContaminationDetectionEnabled` is true
- **THEN** the system SHALL show the heavy lens warn dialog immediately via the coded-alarm passive warn pipeline
- **AND** the dialog MUST use alarm code **L001**
- **AND** title/body MUST use localized **镜片脏污告警** / heavy contamination copy
- **AND** a single acknowledge button (**知道了**)

#### Scenario: Laser interrupt while dialog shown

- **WHEN** L001 passive warn is shown while laser enable is active
- **AND** `keepLaserOnWhileAlarmed` is false
- **AND** `allowWorkAfterLensContamination` is false
- **THEN** the app SHALL force laser enable off per `alarm-laser-interrupt`
- **AND** the L001 dialog MUST remain visible until the operator acknowledges (no second L001 enqueue on laser falling edge)

#### Scenario: Demo alarm does not fight deferred second show

- **WHEN** `make alarm CODE=L001` or production detect shows L001 while laser is ON
- **THEN** the system MUST NOT enqueue a second L001 dialog solely because laser later turns OFF

### Requirement: Unresolved heavy contamination blocks repeat laser enable

After a production heavy lens contamination episode (L001) is detected and the operator has acknowledged the warn dialog, subsequent **laser enable** attempts in Quick Mode or Engineer Mode SHALL be blocked while the episode remains unresolved (no level-0 / fault-cleared event), unless `allowWorkAfterLensContamination` in `t_advanced_settings` is true.

When blocked, the app MUST re-show the L001 heavy contamination warn dialog on each laser-enable attempt using the same copy as the production alert.

When `lensContaminationDetectionEnabled` is true, immediate L001 presentation on detect SHALL remain unchanged.

#### Scenario: Acknowledged L001 blocks next laser enable

- **WHEN** production heavy contamination was detected and the operator acknowledged the L001 dialog
- **AND** no clean / level-0 event has cleared the episode
- **AND** `allowWorkAfterLensContamination` is false
- **AND** the operator taps laser enable
- **THEN** laser enable MUST NOT proceed
- **AND** the L001 warn dialog MUST be shown again

#### Scenario: Clean result clears laser-enable block

- **WHEN** live weld stain detect or RKNN reports level 0 / CLEAN after a heavy episode
- **THEN** the L001 laser-enable block MUST be cleared
- **AND** laser enable MAY proceed when other preflight checks pass

#### Scenario: Dangerous operations bypass clears laser-enable block only for enable path

- **WHEN** an unresolved L001 episode exists
- **AND** `allowWorkAfterLensContamination` is true
- **AND** the operator taps laser enable
- **THEN** the L001 guard MUST NOT block laser enable for that attempt
- **AND** the warn table / monitor MAY still show L001 while contamination persists

## REMOVED Requirements

### Requirement: Heavy production dirty alert shows only after laser stops

**Reason**: Deferred post-laser-stop presentation conflicted with immediate coded-alarm pipeline and demo triggers; product now shows L001 when heavy contamination is detected.

**Migration**: Remove `WeldDeferredWarnCoordinator` and laser falling-edge drain; use `DeviceDialogHandler.showPassiveWarnDialog` on detect.
