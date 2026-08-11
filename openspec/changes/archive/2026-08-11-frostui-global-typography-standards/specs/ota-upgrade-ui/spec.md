## ADDED Requirements

### Requirement: Upgrade pages use upgradeDescription for mid-card explanatory copy

System Upgrade, HMI Upgrade, and peripheral firmware upgrade pages rendered with Settings chrome SHALL style mid-card explanatory copy—idle hints before check, check-card status messages, in-progress guidance styled as description, and completion-tip bodies—with `HmiTypography.upgradeDescription` (**22** at Medium 100%). Section headlines for available versions MAY continue to use `sectionTitle` or `settingsRowTitle` as appropriate; only the descriptive / instructional body copy uses `upgradeDescription`.

#### Scenario: System Upgrade idle hint

- **WHEN** System Upgrade is shown before the operator runs Check for Updates
- **THEN** the idle hint in the check card uses `upgradeDescription` for font size

#### Scenario: HMI Upgrade check status

- **WHEN** HMI Upgrade presents checking, up-to-date, unavailable, or failed status text in the check card body
- **THEN** that body copy uses `upgradeDescription`

#### Scenario: Control-board and camera upgrade parity

- **WHEN** control-board or camera program upgrade pages render the same classes of mid-card explanatory copy
- **THEN** they use the same `upgradeDescription` role as System / HMI upgrade
- **AND** do not keep page-local `descriptionSize` or `helpTextSize` constants

#### Scenario: Completion tip on upgrade page

- **WHEN** an upgrade page shows `UpgradeCompletionTip` success or failure body text below the progress UI
- **THEN** the tip body uses `upgradeDescription` (injected style from the App)
