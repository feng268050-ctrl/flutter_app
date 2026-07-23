## Purpose

Define locale-correct material label rendering for Continuous Weld and Spot Weld parameter screens.
## Requirements
### Requirement: Weld material labels follow active locale
In Continuous Weld and Spot Weld screens, weld-related display labels (including selector options, selected/current material text, and process-name edit default prefill text when derived from known built-in labels) SHALL be rendered from locale-specific resources and SHALL match the active app language.

#### Scenario: English locale material options
- **WHEN** app language is English and user opens the material selector in Continuous Weld or Spot Weld
- **THEN** all predefined material options SHALL be displayed in English labels.

#### Scenario: English locale selected material
- **WHEN** app language is English and a material is selected in Continuous Weld or Spot Weld
- **THEN** the selected/current material text shown in the parameter area SHALL be displayed in English.

#### Scenario: Chinese locale weld labels
- **WHEN** app language is Simplified Chinese and user opens Continuous Weld or Spot Weld parameter screens
- **THEN** weld-related static labels and selector entries SHALL be displayed in Simplified Chinese and SHALL NOT contain leftover English copy.

#### Scenario: Chinese locale process-name edit prefill
- **WHEN** app language is Simplified Chinese and user enters process-name edit via jump action in Continuous Weld or Spot Weld
- **THEN** the default prefilled name derived from known built-in labels SHALL be displayed in Simplified Chinese.

### Requirement: Material localization SHALL NOT change material encoding semantics
Localization updates for weld-mode material labels SHALL only affect display text and MUST NOT alter material type encoding, stored values, or conversion behavior used by process parameters.

#### Scenario: Display-only localization change
- **WHEN** localization resources are updated for English/Chinese weld-mode labels
- **THEN** existing material type IDs/codes and process parameter persistence semantics SHALL remain unchanged.

