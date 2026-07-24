## Why

Common Settings → Language and Unit are still in-memory stubs (“not persisted yet”), so a process restart loses operator choices. Misc already has `/var/lib/hmi/misc-settings.json`, Advanced has `advanced-settings.json`, and HAL prefs live under `/var/lib/hal/` — non-HAL, non-Misc Common Settings need the same App-owned JSON pattern so Display & Sound product prefs survive restart without polluting Misc or HAL.

## What Changes

- Add App-owned **`/var/lib/hmi/common-settings.json`** for Common Settings preferences that are neither HAL-backed nor Misc-section toggles.
- Introduce a **`CommonSettingsStore`** (mirror `MiscSettingsStore` / `AdvancedSettingsStore`: warm-read, soft-fail corrupt JSON, immediate write on change, InheritedWidget scope).
- Persist at least **Language** (`EN` / `ZH`) and **Unit** (`Metric` / `Imperial`); wire Language / Unit Settings pages and Common Settings row summaries to the store.
- Apply Language at cold start (and on change) to product UI locale / Cyber IME language selection as already scaffolded — not Flutter Material localization overhaul.
- Leave Misc in `misc-settings.json`; leave brightness, screen-off, volume, sound-effect, network, date-time, mouse/keyboard, USB OTG, etc. on their existing HAL / platform paths.
- Update path-layout / settings-persist docs to list `common-settings.json` under `/var/lib/hmi/`.

## Capabilities

### New Capabilities

- `common-settings-persist`: Unified App JSON store for non-HAL, non-Misc Common Settings (Language, Unit, and future peers) at `/var/lib/hmi/common-settings.json`

### Modified Capabilities

- `settings-ui`: Language / Unit become real persisted controls (not stubs); Common Settings rows reflect store values
- `os-path-layout`: `/var/lib/hmi/` inventory includes `common-settings.json`
- `linux-settings-persist`: HMI App store list includes `common-settings.json` (still not HAL restore)

## Impact

- **App:** new `CommonSettingsStore` + scope; bootstrap warm-read next to Misc/Advanced; `LanguageSettingsPage` / `UnitSettingsPage` / `common_settings_tab.dart` summaries; optional locale/IME apply hook in `LwsHmiApp`
- **Paths:** `OsPaths.varHmi` docs / comments; no new Buildroot packages
- **Out of scope:** moving Sound Effect off `ButtonFeedback` / `sound.conf`; Misc key migration; full i18n string catalogs; Imperial unit conversion UI beyond the preference itself
