## ADDED Requirements

### Requirement: SettingsHelpFooter uses settingsHelpFooter typography role

Settings pages that render operator help or numbered explanatory footnotes below a card (via `SettingsHelpFooter` or the same component contract) SHALL render that copy at the `HmiTypography.settingsHelpFooter` semantic role (**20** at Medium 100%), not at generic `supporting` (16) or page-local size constants. Color and line-height adjustments are permitted; changing font size via `style.copyWith(fontSize: …)` in production call sites is forbidden unless covered by an documented exception list.

#### Scenario: Language settings footnote size

- **WHEN** the operator opens Language settings and reads the persisted-preference footnote below the card
- **THEN** the footnote renders at the `settingsHelpFooter` size (20 at Medium 100%)

#### Scenario: Keyboard layout help footnote

- **WHEN** the operator opens Keyboard settings and reads the layout help footnote
- **THEN** the footnote uses `settingsHelpFooter` as the default style
- **AND** does not use a custom 18px body override

#### Scenario: Cloud services dual footnotes

- **WHEN** Cloud Services settings shows one or two help footnotes under its cards
- **THEN** each footnote uses the shared `SettingsHelpFooter` default (`settingsHelpFooter` role)
