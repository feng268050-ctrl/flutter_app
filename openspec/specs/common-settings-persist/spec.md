# common-settings-persist Specification

## Purpose

App-owned Common Settings product preferences (Language, Unit, and future non-HAL / non-Misc peers) persisted at `/var/lib/hmi/common-settings.json`, with Language driving the CyberIME language provider and Flutter UI locale (BCP-47 wire values).
## Requirements

### Requirement: Common Settings product prefs use common-settings.json

Common Settings preferences that are neither HAL/platform-backed nor Misc-section toggles SHALL be persisted in a single JSON file at `/var/lib/hmi/common-settings.json` (or `${OsPaths.varHmi}/common-settings.json`). The App SHALL NOT introduce additional per-preference files under `/var/lib/hmi/` for Language, Unit, or future peers of this class. Keys for at least Language and Unit SHALL live in this file. Language wire values SHALL be BCP-47 tags `en-US`, `zh-CN`, or `zh-TW`. Missing file or missing keys SHALL apply documented per-key defaults (`language` = `en-US`, `unit` = `Metric`). On read, legacy values `EN` and `ZH` SHALL be accepted and normalized to `en-US` and `zh-CN` respectively. Corrupt JSON MUST NOT crash the App (soft-fail to defaults). Misc toggles MUST remain in `misc-settings.json`. HAL-backed Common Settings (brightness, AutoSleep, volume, ButtonFeedback sound-effect, network, datetime, mouse, keyboard, USB OTG, etc.) MUST NOT be relocated into `common-settings.json`.

#### Scenario: Defaults when file absent

- **WHEN** `/var/lib/hmi/common-settings.json` is absent
- **THEN** Language is `en-US` and Unit is `Metric` until the operator changes a value

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

#### Scenario: Corrupt JSON soft-fails

- **WHEN** `common-settings.json` exists but is not valid JSON
- **THEN** the App applies Language `en-US` and Unit `Metric` defaults and continues without crashing

#### Scenario: Boundary with Misc and HAL

- **WHEN** an operator changes Show System Status Overlay or Screen Brightness
- **THEN** those values are written to `misc-settings.json` or HAL backlight persistence respectively
- **AND** MUST NOT be written into `common-settings.json` solely because they appear under Common Settings

### Requirement: Language selection drives CyberIME language provider

After warm-read and whenever Language changes, the App SHALL register or update the CyberIME language provider so `en-US` maps to EnglishGlobal and `zh-CN` / `zh-TW` map to ChineseGlobal. Legacy stored `EN` / `ZH` MUST normalize before mapping. The App MUST NOT keep a hard-coded English-only fixed provider after this capability ships. Documented CyberIME Chinese asset gaps MAY still present EnglishGlobal for Text until ChineseGlobal is complete; persistence of Chinese locales MUST still succeed.

#### Scenario: Cold start restores IME language

- **WHEN** `common-settings.json` has `language` = `zh-CN` (or legacy `ZH`) and the App starts
- **THEN** the CyberIME language provider reports Chinese (ChineseGlobal mapping) for subsequent Text focus

#### Scenario: Changing Language updates provider without restart

- **WHEN** the operator changes Language from `en-US` to `zh-CN` in Settings
- **THEN** the CyberIME language provider updates for subsequent Text focus without requiring an App process restart

#### Scenario: Traditional Chinese uses Chinese IME mapping

- **WHEN** Language is `zh-TW`
- **THEN** the CyberIME language provider reports Chinese (ChineseGlobal mapping) for subsequent Text focus
