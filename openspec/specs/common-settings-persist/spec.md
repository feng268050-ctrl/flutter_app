# common-settings-persist Specification

## Purpose

App-owned Common Settings product preferences (Language, Unit, and future non-HAL / non-Misc peers) persisted at `/var/lib/hmi/common-settings.json`, with Language driving the CyberIME language provider.
## Requirements

### Requirement: Common Settings product prefs use common-settings.json

Common Settings preferences that are neither HAL/platform-backed nor Misc-section toggles SHALL be persisted in a single JSON file at `/var/lib/hmi/common-settings.json` (or `${OsPaths.varHmi}/common-settings.json`). The App SHALL NOT introduce additional per-preference files under `/var/lib/hmi/` for Language, Unit, or future peers of this class. Keys for at least Language and Unit SHALL live in this file. Missing file or missing keys SHALL apply documented per-key defaults (`language` = `EN`, `unit` = `Metric`). Corrupt JSON MUST NOT crash the App (soft-fail to defaults). Misc toggles MUST remain in `misc-settings.json`. HAL-backed Common Settings (brightness, AutoSleep, volume, ButtonFeedback sound-effect, network, datetime, mouse, keyboard, USB OTG, etc.) MUST NOT be relocated into `common-settings.json`.

#### Scenario: Defaults when file absent

- **WHEN** `/var/lib/hmi/common-settings.json` is absent
- **THEN** Language is `EN` and Unit is `Metric` until the operator changes a value

#### Scenario: Language change persists

- **WHEN** the operator selects Language `ZH`
- **THEN** `/var/lib/hmi/common-settings.json` is updated so `language` is `ZH`
- **AND** a subsequent process start restores Language `ZH`

#### Scenario: Unit change persists

- **WHEN** the operator selects Unit `Imperial`
- **THEN** `/var/lib/hmi/common-settings.json` is updated so `unit` is `Imperial`
- **AND** a subsequent process start restores Unit `Imperial`

#### Scenario: Corrupt JSON soft-fails

- **WHEN** `common-settings.json` exists but is not valid JSON
- **THEN** the App applies Language `EN` and Unit `Metric` defaults and continues without crashing

#### Scenario: Boundary with Misc and HAL

- **WHEN** an operator changes Show System Status Overlay or Screen Brightness
- **THEN** those values are written to `misc-settings.json` or HAL backlight persistence respectively
- **AND** MUST NOT be written into `common-settings.json` solely because they appear under Common Settings

### Requirement: Language selection drives CyberIME language provider

After warm-read and whenever Language changes, the App SHALL register or update the CyberIME language provider so `EN` maps to EnglishGlobal and `ZH` maps to ChineseGlobal. The App MUST NOT keep a hard-coded English-only fixed provider after this capability ships. Documented CyberIME Chinese asset gaps MAY still present EnglishGlobal for Text until ChineseGlobal is complete; persistence of `ZH` MUST still succeed.

#### Scenario: Cold start restores IME language

- **WHEN** `common-settings.json` has `language` = `ZH` and the App starts
- **THEN** the CyberIME language provider reports Chinese (ChineseGlobal mapping) for subsequent Text focus

#### Scenario: Changing Language updates provider without restart

- **WHEN** the operator changes Language from `EN` to `ZH` in Settings
- **THEN** the CyberIME language provider updates for subsequent Text focus without requiring an App process restart
