## MODIFIED Requirements

### Requirement: Catalog model in package; product seeds copy

`cyber_alarm` SHALL provide an alarm-code catalog model that defines at least code, severity, and localized title/body keys for warn presentation. The product App SHALL seed/load catalog entries for codes in scope and SHALL resolve title/body through App `AppLocalizations` (or equivalent gen-l10n accessors) for the active UI locale. Product alarm EN/ZH copy for codes in scope SHALL be seeded from lws-ui alarm string resources when a match exists. HAL `meta.label` / `meta.alarm_code` MAY supply join keys and list labels but MUST NOT be the sole source of dialog severity policy or bilingual dialog copy.

#### Scenario: Catalog drives dialog content

- **WHEN** a warn episode for code `H001` is presented
- **THEN** dialog title and body SHALL come from the product catalog resolved through App localization keyed by that catalog
- **AND** missing catalog entries MUST soft-fail (diagnosable placeholder) without crashing the App

#### Scenario: Chinese locale shows Chinese alarm copy

- **WHEN** UI locale is `zh-CN` and a catalogued warn dialog is shown
- **THEN** title and body render Simplified Chinese strings from App localization (lws-ui-sourced when available)
