## Why

Region, PreferredLanguage, and UnitSystem today live as App-owned string prefs in `CommonSettingsStore` (`/var/lib/hmi/common-settings.json`), with Region apply logic (wireless regulatory + TZ/NTP policy) also App-local. Other CyberUI products cannot reuse typed locale/region APIs, and General Settings in `lws_hmi` couples UI to product-specific persistence instead of a shared HAL surface. Abstracting these into `cyber_hal/locale` keeps regulatory apply next to `WifiCountryApply` and aligns persistence with other HAL domains under `/var/lib/hal/`.

## What Changes

- Add `cyber_hal/locale` with typed **Region** (ISO 3166-1 alpha-2), **PreferredLanguage** (BCP-47), and **UnitSystem** (metric/imperial), plus catalog, normalize, persist, and Region apply APIs.
- Persist locale prefs at **`/var/lib/hal/locale.conf`** (`key=value`, same family as `datetime.conf` / `power.conf`) with keys `language`, `unit`, and **`region`**.
- **No migration** from `/var/lib/hmi/common-settings.json`: ignore any legacy `language` / `unit` / `country` there; missing `locale.conf` uses defaults (`en-US` / `Metric` / `US`). Keep implementation free of import/strip helpers.
- Move Region → wireless regulatory (`iw reg` / wpa `country=`) and Region-linked timezone/NTP apply policy into the HAL locale domain (reuse / fold today’s App `RegionSettingsApplier` + catalog).
- Keep operator-visible General (Common Settings) Language / Unit / Country/Region behavior; wire `lws_hmi` to `cyber_hal/locale` instead of owning types and apply.
- Language still drives Flutter UI locale + CyberIME at the App layer; Unit still drives product unit conversion in App UI.
- **BREAKING**: On-disk SoT is `locale.conf` only (not `common-settings.json`); persist key is `region` (not `country`). Prior JSON prefs are discarded. Cloud snapshot uses `region`. Apps MUST use `package:cyber_hal/locale.dart`.

## Capabilities

### New Capabilities

- `hal-locale`: Portable HAL locale domain — Region / PreferredLanguage / UnitSystem types, `/var/lib/hal/locale.conf` persistence, catalog, and Region side effects (wireless regulatory + linked clock defaults).

### Modified Capabilities

- `common-settings-persist`: Language / Unit / Country leave `common-settings.json`; HAL `locale.conf` owns them; no JSON import path.
- `region-country-settings`: Persist Region via HAL `region=` key; apply authority moves to `cyber_hal/locale`.
- `settings-ui`: General Settings Language / Unit / Country/Region rows use HAL locale types/APIs and `locale.conf`.
- `linux-wifi`: Product Region (HAL locale) is the source of regulatory country apply.
- `linux-settings-persist`: Document `locale.conf` under `/var/lib/hal/`; Language/Unit/Region no longer written under `/var/lib/hmi/`.

## Impact

- `packages/cyber_hal/` — new `locale.dart` barrel + `lib/src/locale/**`; `locale.conf` I/O only (no migrate helper); Region catalog/policy; package tests.
- `app/lws_hmi/` — remove locale ownership from `CommonSettingsStore`; Language/Unit/Country pages + General summaries + bootstrap + cloud `commonSettings` (`region`) consume HAL.
- Specs: `hal-locale`, `common-settings-persist`, `region-country-settings`, `settings-ui`, `linux-wifi`, `linux-settings-persist`.
- Field units: Language / Unit / Region reset to defaults until reconfigured in General Settings.
