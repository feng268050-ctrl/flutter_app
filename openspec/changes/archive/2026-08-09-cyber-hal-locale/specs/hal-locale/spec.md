## ADDED Requirements

### Requirement: cyber_hal exposes a locale domain barrel

`cyber_hal` SHALL provide `package:cyber_hal/locale.dart` exporting typed **Region**, **PreferredLanguage**, and **UnitSystem** APIs plus persistence and Region apply helpers under `lib/src/locale/`. Product Apps MUST depend on this barrel for locale prefs rather than owning duplicate string catalogs for these three values. The barrel MUST be Linux-usable with injectable paths for tests (stub-friendly soft-fail where OS tools are absent).

#### Scenario: App imports locale barrel

- **WHEN** a product App needs Region / PreferredLanguage / UnitSystem
- **THEN** it imports `package:cyber_hal/locale.dart`
- **AND** MUST NOT reintroduce a parallel App-owned type catalog for the same three values

### Requirement: Typed PreferredLanguage UnitSystem and Region

HAL locale SHALL define:

- **PreferredLanguage** — wire BCP-47 tags `en-US`, `zh-CN`, `zh-TW`; on read, legacy `EN` → `en-US` and `ZH` → `zh-CN` MAY normalize; unsupported → `en-US`
- **UnitSystem** — wire `Metric` / `Imperial`; unsupported → `Metric`
- **Region** — ISO 3166-1 alpha-2 uppercase (plus `XK`) from the product Region catalog; unsupported / empty → `US`

Defaults when file or keys are missing: PreferredLanguage `en-US`, UnitSystem `Metric`, Region `US`.

#### Scenario: Normalize legacy language tokens

- **WHEN** stored language wire is `ZH`
- **THEN** PreferredLanguage normalizes to `zh-CN`

#### Scenario: Unknown region becomes US

- **WHEN** stored region wire is `XX` or empty
- **THEN** Region normalizes to `US`

#### Scenario: Unknown unit becomes Metric

- **WHEN** stored unit wire is unrecognized
- **THEN** UnitSystem normalizes to `Metric`

### Requirement: Locale prefs persist in locale.conf under /var/lib/hal

HAL locale persistence SHALL use `/var/lib/hal/locale.conf` (injectable for tests) as a `key=value` preference file in the same family as `datetime.conf` / `power.conf`. Keys SHALL be `language`, `unit`, and **`region`** mapping to PreferredLanguage, UnitSystem, and Region respectively. The persist key for Region MUST be `region` (MUST NOT use `country` as the primary key). Corrupt or unreadable files MUST soft-fail to defaults without throwing to callers. HAL locale MUST NOT write Misc or backlight/power prefs into this file. HAL locale MUST NOT read or import `/var/lib/hmi/common-settings.json`.

#### Scenario: Persisted region survives restart

- **WHEN** Region is set to `DE` via HAL locale API
- **THEN** `/var/lib/hal/locale.conf` contains `region=DE`
- **AND** a subsequent warm-read restores Region `DE`

#### Scenario: Corrupt file soft-fails

- **WHEN** `locale.conf` exists but cannot be parsed as key=value prefs
- **THEN** HAL locale reports PreferredLanguage `en-US`, UnitSystem `Metric`, and Region `US`
- **AND** MUST NOT crash the process

#### Scenario: Default path is under var lib hal

- **WHEN** HAL locale uses its default preference path
- **THEN** that path is `/var/lib/hal/locale.conf`

#### Scenario: Missing locale.conf uses defaults

- **WHEN** `locale.conf` is absent
- **THEN** PreferredLanguage is `en-US`, UnitSystem is `Metric`, and Region is `US`
- **AND** leftover keys in `common-settings.json` MUST NOT affect those values

### Requirement: Region apply updates wireless regulatory

After warm-read and whenever Region changes, HAL locale SHALL apply the Region ISO code as the Wi‑Fi regulatory country via `WifiCountryApply` (or equivalent): upsert wpa_supplicant `country=<CC>` and set runtime country (`wpa_cli` and optionally `iw reg set`). Apply MUST be best-effort soft-fail when radio/wpa/`iw` are unavailable and MUST NOT crash the HMI. PreferredLanguage MUST NOT change solely because Region changed.

#### Scenario: Boot applies region to Wi-Fi

- **WHEN** Region is `US` and Wi‑Fi stack is available after warm-read apply
- **THEN** the effective wpa country is `US`

#### Scenario: Changing region updates regulatory without reboot

- **WHEN** the operator changes Region from `US` to `GB` via HAL locale
- **THEN** the Wi‑Fi regulatory country becomes `GB` without requiring an App process restart

### Requirement: Region apply links timezone and NTP without clobbering customs

HAL locale SHALL maintain Region → default IANA timezone and preferred primary NTP hostname for the full catalog. Preferred NTP for Region-driven defaults MUST NOT be `cn.pool.ntp.org` (typically `pool.ntp.org`). When Region changes (or on first apply with no prior persisted `region` key):

- If Automatic Timezone is off, set timezone to the new Region default when current timezone is unset, equals the previous Region default, or (on first Region key seed) is legacy `Asia/Shanghai` or `UTC`.
- Set primary NTP to the new Region preferred host when NTP is unset, unknown, equals the previous Region preferred host, or is legacy `cn.pool.ntp.org` during Region clock seeding.
- If Automatic Timezone is on, MUST NOT force a timezone overwrite; NTP rules above still apply.
- Operator-customized timezone / NTP that diverged from the previous Region defaults MUST be preserved.

#### Scenario: First seed applies US clock defaults

- **WHEN** Region defaults to `US` and timezone / NTP prefs are unset (or timezone is legacy `Asia/Shanghai` / `UTC` on first Region key seed)
- **THEN** timezone becomes the US Region-default IANA zone
- **AND** primary NTP becomes the US-preferred curated host (not `cn.pool.ntp.org`)

#### Scenario: Custom timezone preserved on region change

- **WHEN** Region is `US` but timezone was customized away from the US default
- **AND** Region changes to `GB` with Automatic Timezone off
- **THEN** timezone remains the operator-customized zone
- **AND** regulatory country still becomes `GB`
