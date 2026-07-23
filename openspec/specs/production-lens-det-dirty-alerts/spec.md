# production-lens-det-dirty-alerts Specification

## Purpose
TBD - created by archiving change production-lens-det-dirty-alerts. Update Purpose after archive.
## Requirements
### Requirement: Production OpenCV stain detect posts only heavy LensCheckResultEvent in weld modes

When the device is in Quick Mode or Engineer Mode with active process type **continuous welding** or **spot welding**, the system SHALL map a successful live-weld **`OpencvStainDetectResult`** with heavy contamination to `LensCheckResultEvent` with **`level == 2`** only. Events with **`level == 1`** from any source MUST be ignored for production weld dirty-alert pending.

#### Scenario: Heavy stain triggers heavy-level event

- **WHEN** live weld OpenCV stain detect completes with heavy contamination in eligible weld scope
- **THEN** the system SHALL post `LensCheckResultEvent` with `level == 2` and `status == STAIN_HEAVY`
- **AND** `message` MUST identify `source=live_stain_detect`

#### Scenario: Mild level ignored in production weld scope

- **WHEN** a `LensCheckResultEvent` with `level == 1` is received while production weld alert scope is active
- **THEN** the system MUST NOT set production dirty-alert pending
- **AND** MUST NOT show a mild advisory dialog in the weld screen

#### Scenario: Clean frame clears pending

- **WHEN** live weld OpenCV stain detect reports clean in eligible scope
- **THEN** the system SHALL post `level == 0` / `CLEAN` to clear dirty pending
- **AND** MUST NOT show a clean-state dialog

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

### Requirement: Offline stain detect sources do not drive production alerts

Production heavy dirty pending MUST NOT be set from **`offline_stain_detect`** results (AI Vision process video) or AI Vision preview-only paths.

#### Scenario: Process video offline source ignored

- **WHEN** `message` JSON `source` is `offline_stain_detect`
- **THEN** production heavy dirty pending MUST NOT be set

#### Scenario: AI Vision preview source ignored

- **WHEN** stain detect completes on AI Vision live preview only (not live weld PR1 coordinator)
- **THEN** production heavy dirty pending MUST NOT be set from that path alone

### Requirement: Lens contamination detection toggle gates production dirty alerts

When `lensContaminationDetectionEnabled` in `t_advanced_settings` is false, the system MUST NOT set production heavy dirty-alert pending from live-weld OpenCV stain detect and MUST NOT show the production heavy lens dirty dialog for detections that would have occurred while the toggle was off during the laser-on session.

#### Scenario: Toggle off prevents pending during laser on

- **WHEN** `lensContaminationDetectionEnabled` is false
- **AND** laser is ON in eligible production weld scope
- **THEN** production heavy dirty-alert pending MUST NOT be set from live weld stain detect

#### Scenario: Toggle off prevents dialog after detect

- **WHEN** `lensContaminationDetectionEnabled` was false for the entire laser-on session
- **AND** a heavy contamination event would have occurred
- **THEN** the production heavy lens dirty dialog MUST NOT be shown for that session

#### Scenario: Toggle on preserves existing alert behavior

- **WHEN** `lensContaminationDetectionEnabled` is true
- **AND** live weld stain detect reports heavy contamination in eligible scope
- **THEN** existing production dirty-alert immediate L001 behavior SHALL apply unchanged

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

