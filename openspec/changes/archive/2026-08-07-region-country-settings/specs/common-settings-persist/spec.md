## MODIFIED Requirements

### Requirement: Common Settings product prefs use common-settings.json

Common Settings preferences that are neither HAL/platform-backed nor Misc-section toggles SHALL be persisted in a single JSON file at `/var/lib/hmi/common-settings.json` (or `${OsPaths.varHmi}/common-settings.json`). The App SHALL NOT introduce additional per-preference files under `/var/lib/hmi/` for Language, Unit, Country, or future peers of this class. Keys for at least Language, Unit, and Country SHALL live in this file. Language wire values SHALL be BCP-47 tags `en-US`, `zh-CN`, or `zh-TW`. Country wire values SHALL be ISO 3166-1 alpha-2 uppercase codes from the product Country catalog (full ISO list plus `XK`). Missing file or missing keys SHALL apply documented per-key defaults (`language` = `en-US`, `unit` = `Metric`, `country` = `US`). On read, legacy Language values `EN` and `ZH` SHALL be accepted and normalized to `en-US` and `zh-CN` respectively. Unsupported Country codes MUST normalize to `US`. Corrupt JSON MUST NOT crash the App (soft-fail to defaults including Country `US`). Misc toggles MUST remain in `misc-settings.json`. HAL-backed Common Settings (brightness, AutoSleep, volume, ButtonFeedback sound-effect, network, datetime, mouse, keyboard, USB OTG, etc.) MUST NOT be relocated into `common-settings.json`.

#### Scenario: Defaults when file absent

- **WHEN** `/var/lib/hmi/common-settings.json` is absent
- **THEN** Language is `en-US`, Unit is `Metric`, and Country is `US` until the operator changes a value

#### Scenario: Language change persists

- **WHEN** the operator selects Language `zh-CN`
- **THEN** `/var/lib/hmi/common-settings.json` is updated so `language` is `zh-CN`
- **AND** a subsequent process start restores Language `zh-CN`

#### Scenario: Legacy Language values normalize on read

- **WHEN** `common-settings.json` contains `language` = `ZH` from a prior App build
- **AND** the App warm-reads preferences
- **THEN** the in-memory Language is `zh-CN`
- **AND** a subsequent Language or Unit write MAY upgrade the stored `language` value to `zh-CN`

#### Scenario: Unit change persists

- **WHEN** the operator selects Unit `Imperial`
- **THEN** `/var/lib/hmi/common-settings.json` is updated so `unit` is `Imperial`
- **AND** a subsequent process start restores Unit `Imperial`

#### Scenario: Country change persists

- **WHEN** the operator selects Country `DE`
- **THEN** `/var/lib/hmi/common-settings.json` is updated so `country` is `DE`
- **AND** a subsequent process start restores Country `DE`

#### Scenario: Corrupt JSON soft-fails

- **WHEN** `common-settings.json` exists but is not valid JSON
- **THEN** the App applies Language `en-US`, Unit `Metric`, and Country `US` defaults and continues without crashing

#### Scenario: Boundary with Misc and HAL

- **WHEN** an operator changes Show System Status Overlay or Screen Brightness
- **THEN** those values are written to `misc-settings.json` or HAL backlight persistence respectively
- **AND** MUST NOT be written into `common-settings.json` solely because they appear under Common Settings
