# common-settings-persist Specification

## Purpose

App-owned Common Settings product preferences (Language, Unit, Country / Region, and future non-HAL / non-Misc peers) persisted at `/var/lib/hmi/common-settings.json`, with Language driving the CyberIME language provider and Flutter UI locale (BCP-47 wire values).
## Requirements
### Requirement: Common Settings product prefs use common-settings.json

`/var/lib/hmi/common-settings.json` SHALL remain available for future App-owned Common Settings peers that are neither HAL-backed nor Misc toggles. **Language, Unit, and Country / Region MUST NOT be stored in this file.** Those three preferences SHALL persist only via `cyber_hal` locale at `/var/lib/hal/locale.conf` (`language`, `unit`, `region`). The App and HAL MUST NOT implement a migration that imports `common-settings.json` locale keys into `locale.conf`. Leftover `language` / `unit` / `country` keys in an old JSON file MUST be ignored. The App SHALL NOT introduce additional per-preference files under `/var/lib/hmi/` for Language, Unit, or Region. Misc toggles MUST remain in `misc-settings.json`. Other HAL-backed Common Settings (brightness, AutoSleep, volume, ButtonFeedback sound-effect, network, datetime, mouse, keyboard, USB OTG, locale, etc.) MUST NOT be relocated into `common-settings.json`.

#### Scenario: Language persists in locale.conf not common-settings.json

- **WHEN** the operator selects Language `zh-CN`
- **THEN** `/var/lib/hal/locale.conf` contains `language=zh-CN`
- **AND** Language MUST NOT be written into `common-settings.json`

#### Scenario: Unit persists in locale.conf

- **WHEN** the operator selects Unit `Imperial`
- **THEN** `/var/lib/hal/locale.conf` contains `unit=Imperial`

#### Scenario: Region persists as region key

- **WHEN** the operator selects Country/Region `DE`
- **THEN** `/var/lib/hal/locale.conf` contains `region=DE`
- **AND** MUST NOT write a `country` key into `common-settings.json`

#### Scenario: Old JSON locale keys are ignored

- **WHEN** `locale.conf` is absent
- **AND** `common-settings.json` still contains `country` = `DE` (or Language / Unit peers)
- **AND** HAL locale warm-reads
- **THEN** Region is the default `US` (not `DE`)
- **AND** PreferredLanguage / UnitSystem use their documented defaults unless set in `locale.conf`

#### Scenario: Boundary with Misc and other HAL

- **WHEN** an operator changes Show System Status Overlay or Screen Brightness
- **THEN** those values are written to `misc-settings.json` or HAL backlight persistence respectively
- **AND** MUST NOT be written into `common-settings.json` or `locale.conf` solely because they appear under Common Settings

### Requirement: Language selection drives CyberIME language provider

After warm-read and whenever PreferredLanguage changes (via HAL locale / `locale.conf`), the App SHALL register or update the CyberIME language provider so `en-US` maps to EnglishGlobal and `zh-CN` / `zh-TW` map to ChineseGlobal. Legacy stored `EN` / `ZH` tokens in `locale.conf` MAY normalize before mapping. The App MUST NOT keep a hard-coded English-only fixed provider after this capability ships. Documented CyberIME Chinese asset gaps MAY still present EnglishGlobal for Text until ChineseGlobal is complete; persistence of Chinese locales MUST still succeed. Persistence of the language wire value remains HAL locale’s responsibility; CyberIME mapping remains App responsibility.

#### Scenario: Cold start restores IME language

- **WHEN** `locale.conf` has `language=zh-CN` and the App starts
- **THEN** the CyberIME language provider reports Chinese (ChineseGlobal mapping) for subsequent Text focus

#### Scenario: Changing Language updates provider without restart

- **WHEN** the operator changes Language from `en-US` to `zh-CN` in Settings
- **THEN** the CyberIME language provider updates for subsequent Text focus without requiring an App process restart

#### Scenario: Traditional Chinese uses Chinese IME mapping

- **WHEN** Language is `zh-TW`
- **THEN** the CyberIME language provider reports Chinese (ChineseGlobal mapping) for subsequent Text focus

