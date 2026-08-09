## 1. HAL locale types and barrel

- [x] 1.1 Add `packages/cyber_hal/lib/src/locale/` with `PreferredLanguage`, `UnitSystem`, and `Region` (parse / normalize / toWire; defaults `en-US` / `Metric` / `US`)
- [x] 1.2 Move Region catalog + filter helpers from App `region_country_*` into HAL locale (full ISO + `XK`, TZ/NTP defaults)
- [x] 1.3 Add `packages/cyber_hal/lib/locale.dart` barrel exporting types, catalog, store, and Region applier
- [x] 1.4 Add package unit tests for normalize / catalog filter / wire round-trip

## 2. HAL locale.conf persistence and Region apply

- [x] 2.1 Implement `LocaleSettings` reading/writing `/var/lib/hal/locale.conf` as `key=value` (`language` / `unit` / **`region`**); warm-read; corrupt soft-fail; injectable path; **no** `common-settings.json` read/import
- [x] 2.2 Move `RegionSettingsPolicy` clock-link rules into HAL locale; inject `DateTimeController` for TZ/NTP apply
- [x] 2.3 Implement Region applier: persist `region=` + `WifiCountryApply` + policy-driven clock apply; soft-fail; seed `region` on first warm apply
- [x] 2.4 Package tests: conf I/O, defaults when absent, apply policy (mock runners / fake datetime), first-seed and custom-TZ preserve

## 3. Wire lws_hmi General Settings to HAL locale

- [x] 3.1 Remove locale fields from `CommonSettingsStore` (or delete the store if empty); wire scopes/bootstrap to HAL `LocaleSettings` only
- [x] 3.2 Point Language / Unit / Country settings pages and General Display & Sound summaries at HAL types/APIs; keep operator copy and row order
- [x] 3.3 Call HAL Region apply on bootstrap and on Country/Region change; remove App-local `region_settings_applier` / catalog / policy duplicates
- [x] 3.4 Update cloud `commonSettings` snapshot to use **`region`** (not `country`) plus `language` / `unit` from HAL locale; keep PreferredLanguage → Flutter locale + CyberIME in App

## 4. Tests and cleanup

- [x] 4.1 Update App tests that targeted `CommonSettingsStore` / region policy / `country` snapshot keys to HAL locale + `region`
- [x] 4.2 Run `flutter test` / analyze in `packages/cyber_hal` and affected `app/lws_hmi` tests; fix regressions
- [x] 4.3 Remove dead App region/language/unit helpers, unused JSON locale writes, and unused exports
