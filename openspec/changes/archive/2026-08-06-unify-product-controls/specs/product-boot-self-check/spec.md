## ADDED Requirements

### Requirement: Boot self-check don’t-show-again uses CyberCheckbox at 28

After all boot self-check items reach a terminal status, the dialog footer “don’t show again” control SHALL be a `CyberCheckbox` with face size `CyberDimens.checkboxLargeSize` (28). The App MUST NOT use an ad-hoc size such as 38 for that control.

#### Scenario: Footer checkbox size

- **WHEN** the boot self-check footer is visible
- **THEN** the don’t-show-again control is a `CyberCheckbox` at size 28
