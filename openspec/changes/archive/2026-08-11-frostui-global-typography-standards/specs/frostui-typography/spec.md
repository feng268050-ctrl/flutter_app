## ADDED Requirements

### Requirement: Upgrade description semantic role at 100% size 22

`HmiTypography` SHALL expose `upgradeDescription` as a reading-UI semantic role for important explanatory copy in upgrade workflows (idle hints, check outcomes, in-card status bodies, completion tips, and equivalent mid-card guidance on System / HMI / control-board / camera upgrade pages). At Medium 100% the role SHALL map to `AppTypography.sectionTitle` (**22** logical pixels). Business widgets MUST NOT set upgrade mid-card copy size via bare `fontSize`, `SettingsDimens.helpTextSize`, or `supporting.copyWith(fontSize: 22)`.

#### Scenario: Upgrade description token baseline

- **WHEN** code or tests read `HmiTypography.upgradeDescription.fontSize` at Medium 100%
- **THEN** the value is `22.0`

#### Scenario: Upgrade page uses semantic role

- **WHEN** System Upgrade, HMI Upgrade, control-board upgrade, or camera program upgrade renders mid-card explanatory copy (idle hint, check status, completion tip body, or in-progress message styled as description)
- **THEN** the text style originates from `context.hmiTypography.upgradeDescription` (color/height overrides allowed; fontSize override forbidden)

#### Scenario: Large mode scales upgrade description

- **WHEN** the operator selects Large text size
- **THEN** upgrade description text scales with the reading TextScaler (1.12× Medium baseline)
- **AND** the App does not hard-code a separate Large-only font size for that copy

### Requirement: Settings help footer semantic role at 100% size 20

`HmiTypography` SHALL expose `settingsHelpFooter` as a reading-UI semantic role for important help copy rendered below settings cards via `SettingsHelpFooter` and equivalent footnote components. At Medium 100% the role SHALL map to `AppTypography.control` (**20** logical pixels). `SettingsHelpFooter` MUST use this role as its default style. Business code MUST NOT duplicate the size as `helpTextSize`, `helpTextStyle`, or `supporting.copyWith(fontSize: …)` for that component.

#### Scenario: Settings help footer token baseline

- **WHEN** code or tests read `HmiTypography.settingsHelpFooter.fontSize` at Medium 100%
- **THEN** the value is `20.0`

#### Scenario: SettingsHelpFooter default style

- **WHEN** a settings page renders `SettingsHelpFooter` without an explicit `style` override
- **THEN** the footnote uses `context.hmiTypography.settingsHelpFooter` for font size and weight
- **AND** the footnote is not rendered at generic `supporting` (16) size

#### Scenario: Large mode scales settings help footer

- **WHEN** the operator selects Large text size
- **THEN** settings help footer text scales with the reading TextScaler
- **AND** the App does not hard-code a separate Large-only font size for footnotes

### Requirement: Business code must not override global font sizes via copyWith

Production widgets under `app/lws_hmi/lib/features/**` and product `lib/ui/**` (excluding demos and documented Theme / CustomPainter whitelists) MUST NOT introduce new `TextStyle(fontSize: <number>)` literals on the standard ladder (12/14/16/18/20/22/24/…) nor `existingStyle.copyWith(fontSize: <number>)` to pick a role. Widgets SHALL select the appropriate `HmiTypography` semantic role instead.

#### Scenario: Upgrade page removes copyWith fontSize hack

- **WHEN** an upgrade page previously used `settingsRowTitle.copyWith(fontSize: 22)` for description copy
- **THEN** after migration it uses `upgradeDescription` without a fontSize override

#### Scenario: Settings row title keeps control baseline without override

- **WHEN** a settings row title already maps to `settingsRowTitle` (control / 20 at 100%)
- **THEN** migration removes redundant `copyWith(fontSize: 20)` and uses the role directly

### Requirement: Module size constants must reference AppTypography ladder

Numeric size constants in feature modules that duplicate global ladder values (for example `statusLabelFontSize = 20`, `wheelSelectedTextSize = 22`) SHALL reference `AppTypography.*Size` or an appropriate `HmiTypography` role rather than repeating bare literals, unless registered as a documented specialty display token under `HmiDisplayTypography` or an approved painter whitelist.

#### Scenario: Process wheel sizes alias ladder

- **WHEN** Quick Mode process wheel code defines selected/unselected label sizes matching sectionTitle/control
- **THEN** the constants reference `AppTypography.sectionTitleSize` and `AppTypography.controlSize` (or semantic styles)
- **AND** do not hard-code independent `22` / `20` literals without ladder linkage
