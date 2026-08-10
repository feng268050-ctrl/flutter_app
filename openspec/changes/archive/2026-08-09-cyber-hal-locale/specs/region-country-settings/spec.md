## MODIFIED Requirements

### Requirement: Country preference persists and defaults to US

The product SHALL persist Common Settings Country / Region as ISO 3166-1 alpha-2 uppercase via **`cyber_hal` locale** at `/var/lib/hal/locale.conf` under key **`region`** (peer of `language` and `unit`). Persistence and normalize SHALL NOT use a duplicate App-owned country string store or `common-settings.json`. Missing file or missing `region` key SHALL default to `US`. Leftover JSON `country` keys MUST be ignored (no migration). Unsupported or malformed codes MUST normalize to `US` without crashing. Corrupt `locale.conf` soft-fail MUST still apply Region `US` with Language/Unit defaults.

#### Scenario: Default when region absent

- **WHEN** `locale.conf` is absent or lacks `region`
- **THEN** Region is `US` until the operator selects another supported code

#### Scenario: Region change persists

- **WHEN** the operator selects Country/Region `DE`
- **THEN** `/var/lib/hal/locale.conf` contains `region=DE`
- **AND** a subsequent process start restores Region `DE`

#### Scenario: Unknown code normalizes to US

- **WHEN** stored `region` is `XX` or empty
- **AND** HAL locale warm-reads preferences
- **THEN** in-memory Region is `US`

### Requirement: Full Country / territory list with search

Country / Region Settings SHALL offer the full ISO 3166-1 alpha-2 catalog of countries and territories (plus `XK` Kosovo), not a US/EU-only short list. The catalog data and normalize helpers SHALL live in `cyber_hal` locale (Region catalog). The product default selection is `US`. Operator-visible title SHALL be Country/Region (zh: 国家/地区). The page SHALL provide search by name (English and Chinese) and by country code. Display order SHALL be alphabetical by English name (A–Z).

#### Scenario: Country page includes world markets

- **WHEN** the operator opens Country / Region Settings
- **THEN** `US` is available
- **AND** non-European codes such as `CN`, `JP`, and `BR` are available

#### Scenario: Search finds Germany

- **WHEN** the operator searches for `德国` or `DE`
- **THEN** Germany (`DE`) appears in the filtered results

### Requirement: Country applies wireless regulatory domain

After warm-read and whenever Region changes, **HAL locale Region apply** SHALL apply the selected ISO code as the Wi‑Fi regulatory country: upsert wpa_supplicant `country=<CC>` in the conf file and set runtime country via `wpa_cli` (and optionally `iw reg set` when available). Apply MUST be best-effort (soft-fail if radio/wpa unavailable) and MUST NOT crash the HMI. AIC custom regulatory (`custregd`) MUST remain off as established by the platform bring-up path. The App General Settings Country page MUST invoke HAL locale apply rather than duplicating regulatory shell logic.

#### Scenario: Boot applies Country to Wi-Fi

- **WHEN** Region is `US` and Wi‑Fi stack is available after App warm-read
- **THEN** the effective wpa country is `US`

#### Scenario: Changing Country updates regulatory

- **WHEN** the operator changes Country/Region from `US` to `GB`
- **THEN** the Wi‑Fi regulatory country becomes `GB` without requiring an App process restart

### Requirement: Country drives timezone and NTP defaults without clobbering custom prefs

The product SHALL maintain a Region → default IANA timezone and preferred primary NTP hostname table for the full catalog **inside `cyber_hal` locale**. Preferred NTP for Region-driven defaults MUST NOT be `cn.pool.ntp.org` (typically `pool.ntp.org`). When Region changes (or on first apply with no prior `region` key):

- If Automatic Timezone (`auto_timezone`) is off, the apply path SHALL set timezone to the new Region default when current timezone is unset, equals the previous Region default, or (on first Region key seed) is legacy `Asia/Shanghai` or `UTC`.
- The apply path SHALL set primary NTP to the new Region preferred host when NTP is unset, unknown, equals the previous Region preferred host, or is the legacy Asia-centric `cn.pool.ntp.org` during Region clock seeding.
- If `auto_timezone` is on, Region MUST NOT force a timezone overwrite (geo path remains authoritative); NTP apply rules above still apply.
- Operator-customized timezone / NTP that diverged from the previous Region defaults MUST be preserved.
- Language MUST NOT change solely because Region changed.

#### Scenario: First boot US defaults for clock seeds

- **WHEN** Region defaults to `US` and timezone / NTP prefs are unset (or timezone is legacy `Asia/Shanghai` / `UTC` on first Region seed)
- **THEN** timezone becomes the US Region-default IANA zone
- **AND** primary NTP becomes the US-preferred curated host (not `cn.pool.ntp.org`)

#### Scenario: Country change updates linked defaults

- **WHEN** Region was `US` with timezone still at the US default and NTP at the US preferred host
- **AND** the operator selects `DE` with `auto_timezone` off
- **THEN** timezone becomes the DE Region-default zone
- **AND** primary NTP becomes the DE-preferred curated host

#### Scenario: Custom timezone is preserved

- **WHEN** Region is `US` but the operator previously set timezone to a non-US-default zone (e.g. `Asia/Shanghai` or `America/Los_Angeles` when US default is `America/New_York`)
- **AND** the operator changes Region to `GB` with `auto_timezone` off
- **THEN** timezone remains the operator-customized zone
- **AND** regulatory country still becomes `GB`

#### Scenario: Language stays independent

- **WHEN** the operator changes Region from `US` to `DE`
- **THEN** Language preference is unchanged
