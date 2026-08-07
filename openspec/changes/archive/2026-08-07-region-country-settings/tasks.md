## 1. Country preference model

- [x] 1.1 Add full ISO 3166-1 (+ XK) Country codes + Country→timezone/NTP defaults table in App
- [x] 1.2 Extend `CommonSettingsStore` with `country` key, default `US`, normalize unknown → `US`
- [x] 1.3 Unit tests: absent file / missing key / corrupt JSON / persist round-trip for Country

## 2. Region apply path

- [x] 2.1 Implement region apply: wireless `country=` / `iw reg set` (soft-fail) from Country preference
- [x] 2.2 Implement linked timezone/NTP apply rules (preserve operator custom; skip TZ when `auto_timezone`; never Country-default to `cn.pool.ntp.org`)
- [x] 2.3 Wire apply on warm-read and on `setCountry`; do not change Language
- [x] 2.4 Unit/widget tests for apply policy (linked vs custom TZ/NTP)

## 3. Settings UI

- [x] 3.1 Add searchable Country Settings page listing full ISO catalog with EN/ZH labels
- [x] 3.2 Insert Country nav row **before Language** on Common Settings Display & Sound card; show summary
- [x] 3.3 Add l10n strings (en / zh / zh_TW) for Country row, search, empty state (names live in catalog data)
- [x] 3.4 UI test or golden/assertion: Country appears above Language / catalog coverage

## 4. Image / Wi-Fi seeds

- [x] 4.1 Change rootfs `wpa_supplicant.conf` seed `country=CN` → `country=US`
- [x] 4.2 Change `run-wpa.sh` / `wifi-stack-up.sh` default country → `US`
- [x] 4.3 Ensure App apply path can update runtime wpa country without full reboot (helper or controller hook)

## 5. DateTime / NTP alignment

- [x] 5.1 Confirm Country-driven NTP uses `pool.ntp.org` (or europe pool if in catalog) — not China pool as default
- [x] 5.2 Align first-boot / empty `datetime.conf` behavior with US Country defaults via App region apply (document any HAL default tweaks)

## 6. Verification

- [x] 6.1 `flutter analyze` / targeted tests under `app/lws_hmi/` (and helper package tests if any)
- [x] 6.2 Device smoke: default US regdomain; change Country to DE → regdomain + linked TZ/NTP; custom TZ preserved
- [x] 6.3 Update Wi-Fi / Settings docs if they still imply `country=CN` or Asia-only clock defaults
