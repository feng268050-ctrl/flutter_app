## Why

Product target markets are the US and Europe, but the image still seeds Wi‑Fi `country=CN` and Date/Time defaults lean Asia (`Asia/Shanghai`, China NTP pool). Operators need a single **Country / Region** preference in Common Settings that drives wireless regulatory domain and region-aware network/time defaults, with **US as the product default**.

## What Changes

- Add **Country** to Common Settings **above Language** (General / Display & Sound group), with the **full ISO 3166-1 alpha-2** country/territory catalog (plus `XK`); **default `US`** (primary markets US/EU; other regions also selectable for worldwide sales).
- Persist Country in App-owned `common-settings.json` (peer of Language / Unit).
- On boot and whenever Country changes, apply **wireless regulatory** (`wpa_supplicant` `country=` + cfg80211 regdomain; keep AIC `custregd=0`).
- On Country change (and cold defaults), drive **region-aware clock/network defaults**: preferred IANA timezone and primary NTP hostname from a Country→defaults table (HAL `datetime.conf` / existing Date & Time path). Operator can still override timezone/NTP manually afterward.
- **BREAKING (image defaults):** Replace rootfs/script seeds `country=CN` with `country=US`. First-boot Date & Time defaults shift from Asia-centric to US-centric when no prefs exist.
- Language remains independent (UI locale); Country does not auto-change Language.

## Capabilities

### New Capabilities

- `region-country-settings`: Country preference UX, persistence, country→regulatory / timezone / NTP default mapping, and apply path on change and boot.

### Modified Capabilities

- `common-settings-persist`: Add `country` key and default `US` to `common-settings.json` contract.
- `settings-ui`: Common Settings lists Country before Language.
- `linux-wifi`: Product Wi‑Fi country/regdomain follows App Country preference (not hard-coded `CN`).
- `linux-datetime`: Default timezone / NTP catalog selection follows Country when prefs are absent or Country-driven apply runs.

## Impact

- App: `CommonSettingsStore`, Common Settings tab, new Country settings page, l10n; wiring to Wi‑Fi / DateTime controllers on change and warm-start.
- HAL / datetime: `NtpServerCatalog` / timezone defaults keyed by country (or App-side mapper calling existing setTimezone / setNtpServerId).
- Rootfs / scripts: `wpa_supplicant.conf` seed and `run-wpa.sh` / `wifi-stack-up.sh` defaults → `US`; optional helper to rewrite `country=` when App applies region.
- Docs: `docs/kernel-evb-dts-deferred.md` / Wi‑Fi notes if they still imply `CN`.
- Tests: store defaults, country apply, settings UI order; host unit tests for mapper.
