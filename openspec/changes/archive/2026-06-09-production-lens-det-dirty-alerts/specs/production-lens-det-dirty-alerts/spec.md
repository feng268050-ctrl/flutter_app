## ADDED Requirements

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

### Requirement: Heavy production dirty alert shows only after laser stops

Production heavy lens dirty alerts (`level >= 2` from RKNN callback or live OpenCV stain detect) SHALL be shown only when the laser has transitioned from **ON to OFF** and the top activity is Quick Mode or Engineer Mode in continuous welding or spot welding. The system MUST NOT show these dialogs while `DeviceStatus.isLaserOn()` is true.

#### Scenario: Pending on detect during laser on

- **WHEN** a heavy dirty event is recorded while laser is ON
- **THEN** the system SHALL set pending heavy contamination
- **AND** MUST NOT display the warn dialog until laser stops

#### Scenario: Dialog on laser falling edge

- **WHEN** pending heavy contamination exists
- **AND** laser transitions ON to OFF
- **AND** production weld scope is active
- **THEN** the system SHALL show the heavy lens warn dialog with title **安全警报** and body **镜片重度污染，立即清洗/更换** (or localized equivalents)
- **AND** a single acknowledge button (**知道了**)
- **AND** MUST use alarm code `ALARM_L001` when using the production warn dialog component

#### Scenario: No dialog during laser on

- **WHEN** laser remains ON after heavy contamination is detected
- **THEN** no production heavy dirty dialog SHALL be visible

### Requirement: Offline stain detect sources do not drive production alerts

Production heavy dirty pending MUST NOT be set from **`offline_stain_detect`** results (AI Vision process video) or AI Vision preview-only paths.

#### Scenario: Process video offline source ignored

- **WHEN** `message` JSON `source` is `offline_stain_detect`
- **THEN** production heavy dirty pending MUST NOT be set

#### Scenario: AI Vision preview source ignored

- **WHEN** stain detect completes on AI Vision live preview only (not live weld PR1 coordinator)
- **THEN** production heavy dirty pending MUST NOT be set from that path alone
