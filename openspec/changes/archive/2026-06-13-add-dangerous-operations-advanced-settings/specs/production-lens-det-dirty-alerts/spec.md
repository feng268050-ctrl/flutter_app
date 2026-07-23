## ADDED Requirements

### Requirement: Unresolved heavy contamination blocks repeat laser enable

After a production heavy lens contamination episode (L001) is detected and the operator has acknowledged the post-laser-stop dialog, subsequent **laser enable** attempts in Quick Mode or Engineer Mode SHALL be blocked while the episode remains unresolved (no level-0 / fault-cleared event), unless `allowWorkAfterLensContamination` in `t_advanced_settings` is true.

When blocked, the app MUST re-show the L001 heavy contamination warn dialog on each laser-enable attempt using the same copy as the post-laser-stop alert.

Passive first-pass deferred dialog behavior after laser stops SHALL remain unchanged when `lensContaminationDetectionEnabled` is true.

#### Scenario: Acknowledged L001 blocks next laser enable

- **WHEN** production heavy contamination was detected and the operator acknowledged the post-laser-stop L001 dialog
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
