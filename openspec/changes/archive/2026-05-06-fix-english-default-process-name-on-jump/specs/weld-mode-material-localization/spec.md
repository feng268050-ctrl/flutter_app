## MODIFIED Requirements

### Requirement: Weld material labels follow active locale
In Continuous Weld and Spot Weld screens, material display labels (including selector options, selected/current material text, and jump/edit default process-name prefill text when derived from known built-in material labels) SHALL be rendered from locale-specific resources and SHALL match the active app language.

#### Scenario: English locale material options
- **WHEN** app language is English and user opens the material selector in Continuous Weld or Spot Weld
- **THEN** all predefined material options SHALL be displayed in English labels.

#### Scenario: English locale selected material
- **WHEN** app language is English and a material is selected in Continuous Weld or Spot Weld
- **THEN** the selected/current material text shown in the parameter area SHALL be displayed in English.

#### Scenario: English locale jump/edit default process name
- **WHEN** app language is English and user enters process-name edit via jump action in Continuous Weld or Spot Weld
- **THEN** the default prefilled process name SHALL be displayed in English for known built-in material-derived labels.

#### Scenario: Custom process names are preserved
- **WHEN** a process name is user-defined custom text
- **THEN** jump/edit default prefill SHALL preserve the custom text and SHALL NOT force translation.
