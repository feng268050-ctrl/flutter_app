# region-country-settings Specification

## Purpose

Product Country / Region preference (ISO 3166-1 alpha-2, default `US`) in Common Settings, driving Wi‑Fi regulatory domain and Country-linked timezone / NTP defaults without changing Language.

## Requirements

### Requirement: Country preference persists and defaults to US

The App SHALL persist Common Settings Country as ISO 3166-1 alpha-2 uppercase in `/var/lib/hmi/common-settings.json` under key `country`, peer of Language and Unit. Missing file or missing `country` key SHALL default to `US`. Unsupported or malformed codes MUST normalize to `US` without crashing. Corrupt JSON soft-fail MUST still apply Country `US` with Language/Unit defaults.

#### Scenario: Default when country absent

- **WHEN** `common-settings.json` is absent or lacks `country`
- **THEN** Country is `US` until the operator selects another supported code

#### Scenario: Country change persists

- **WHEN** the operator selects Country `DE`
- **THEN** `/var/lib/hmi/common-settings.json` contains `country` = `DE`
- **AND** a subsequent process start restores Country `DE`

#### Scenario: Unknown code normalizes to US

- **WHEN** stored `country` is `XX` or empty
- **AND** the App warm-reads preferences
- **THEN** in-memory Country is `US`

### Requirement: Full Country / territory list with search

Country / Region Settings SHALL offer the full ISO 3166-1 alpha-2 catalog of countries and territories (plus `XK` Kosovo), not a US/EU-only short list. The product default selection is `US`. Operator-visible title SHALL be Country/Region (zh: 国家/地区). The page SHALL provide search by name (English and Chinese) and by country code. Display order SHALL be alphabetical by English name (A–Z).

#### Scenario: Country page includes world markets

- **WHEN** the operator opens Country / Region Settings
- **THEN** `US` is available
- **AND** non-European codes such as `CN`, `JP`, and `BR` are available

#### Scenario: Search finds Germany

- **WHEN** the operator searches for `德国` or `DE`
- **THEN** Germany (`DE`) appears in the filtered results

### Requirement: Country applies wireless regulatory domain

After warm-read and whenever Country changes, the App SHALL apply the selected country as the Wi‑Fi regulatory country: upsert wpa_supplicant `country=<CC>` in the conf file and set runtime country via `wpa_cli` (and optionally `iw reg set` when available). Apply MUST be best-effort (soft-fail if radio/wpa unavailable) and MUST NOT crash the HMI. AIC custom regulatory (`custregd`) MUST remain off as established by the platform bring-up path.

#### Scenario: Boot applies Country to Wi-Fi

- **WHEN** Country is `US` and Wi‑Fi stack is available after App warm-read
- **THEN** the effective wpa country is `US`

#### Scenario: Changing Country updates regulatory

- **WHEN** the operator changes Country from `US` to `GB`
- **THEN** the Wi‑Fi regulatory country becomes `GB` without requiring an App process restart

### Requirement: Country drives timezone and NTP defaults without clobbering custom prefs

The product SHALL maintain a Country → default IANA timezone and preferred primary NTP hostname table for the full catalog. Preferred NTP for Country-driven defaults MUST NOT be `cn.pool.ntp.org` (typically `pool.ntp.org`). When Country changes (or on first apply with no prior Country key):

- If Automatic Timezone (`auto_timezone`) is off, the App SHALL set timezone to the new country’s default when current timezone is unset, equals the previous country’s default, or (on first Country key seed) is legacy `Asia/Shanghai` or `UTC`.
- The App SHALL set primary NTP to the new country’s preferred host when NTP is unset, unknown, equals the previous country’s preferred host, or is the legacy Asia-centric `cn.pool.ntp.org` during migration.
- If `auto_timezone` is on, Country MUST NOT force a timezone overwrite (geo path remains authoritative); NTP apply rules above still apply.
- Operator-customized timezone / NTP that diverged from the previous country’s defaults MUST be preserved.
- Language MUST NOT change solely because Country changed.

#### Scenario: First boot US defaults for clock seeds

- **WHEN** Country defaults to `US` and timezone / NTP prefs are unset (or timezone is legacy `Asia/Shanghai` / `UTC` on first Country seed)
- **THEN** timezone becomes the US country-default IANA zone
- **AND** primary NTP becomes the US-preferred curated host (not `cn.pool.ntp.org`)

#### Scenario: Country change updates linked defaults

- **WHEN** Country was `US` with timezone still at the US default and NTP at the US preferred host
- **AND** the operator selects `DE` with `auto_timezone` off
- **THEN** timezone becomes the DE country-default zone
- **AND** primary NTP becomes the DE-preferred curated host

#### Scenario: Custom timezone is preserved

- **WHEN** Country is `US` but the operator previously set timezone to a non-US-default zone (e.g. `Asia/Shanghai` or `America/Los_Angeles` when US default is `America/New_York`)
- **AND** the operator changes Country to `GB` with `auto_timezone` off
- **THEN** timezone remains the operator-customized zone
- **AND** regulatory country still becomes `GB`

#### Scenario: Language stays independent

- **WHEN** the operator changes Country from `US` to `DE`
- **THEN** Language preference is unchanged
