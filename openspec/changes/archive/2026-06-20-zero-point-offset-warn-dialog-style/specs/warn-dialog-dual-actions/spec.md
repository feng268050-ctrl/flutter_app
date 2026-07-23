## ADDED Requirements

### Requirement: WarnDialog SHALL support optional dual-button footer

The shared passive alarm dialog (`dialog_warn.xml` rendered by `WarnDialogUtil`) SHALL support an optional second action button for operator navigation. When `WarnDialogVo.jumpButtonText` is non-null and non-empty, the dialog MUST render a horizontal footer with **confirm on the left** and **jump on the right**, separated by a divider consistent with the existing alarm dialog chrome. When `jumpButtonText` is absent or empty, the dialog MUST retain the current single-button footer behavior used by camera communication and other Modbus alarms.

#### Scenario: Single-button mode unchanged for camera communication

- **WHEN** a `WarnDialogVo` is shown for alarm code C002 without `jumpButtonText`
- **THEN** only the confirm button is visible
- **AND** confirm dismiss semantics and warn sound behavior MUST match the pre-change single-button alarm dialog

#### Scenario: Dual-button mode shows left confirm and right jump

- **WHEN** a `WarnDialogVo` has non-empty `buttonText` (or default confirm text) and non-empty `jumpButtonText`
- **THEN** the footer MUST display confirm on the left and jump on the right
- **AND** both buttons MUST use the same typography and color rules as the existing confirm button for `WARN_TYPE` alarms

#### Scenario: Jump button invokes optional callback

- **WHEN** the operator taps the jump button
- **THEN** `WarnDialogVo.onJump` MUST run if set
- **AND** the dialog MUST dismiss through the same close path as confirm (including optional `OnDismissListener` supplied by the caller)
