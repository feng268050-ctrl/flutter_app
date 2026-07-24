## 1. Scaffold gen-l10n + host commands

- [x] 1.1 Add `flutter_localizations` and `flutter: generate: true` to `app/hmi/pubspec.yaml`; add `app/hmi/l10n.yaml` (`arb-dir: lib/l10n`, template `app_en.arb`)
- [x] 1.2 Create parent ARBs `app/hmi/lib/l10n/app_en.arb` and `app_zh.arb` with seed keys (language/unit/common confirm-cancel at minimum) + empty/stub child ARBs
- [x] 1.3 Adapt LaserCyber Mobile `scripts/flutter/l10n*.sh`, `sync_l10n_child_arbs.py`, `zh_s2t.py`, and OpenCC data for `APP_DIR=app/hmi` (prefer pinned `flutter-sdk` when present)
- [x] 1.4 Add root Makefile targets `l10n`, `l10n-sync`, `l10n-gen`, `l10n-verify`; document in README help / AGENTS.md rebuild notes
- [x] 1.5 Run `make l10n` and commit generated `app_localizations*.dart`; confirm `make l10n-verify` passes

## 2. Locale wiring + Common Settings store

- [x] 2.1 Migrate `CommonSettingsStore` language wire values to `en-US` / `zh-CN` / `zh-TW` with legacy `EN`→`en-US`, `ZH`→`zh-CN` on read; update defaults, labels, and unit tests
- [x] 2.2 Update `AppCyberImeLanguageProvider` so `en-US` → EnglishGlobal and `zh-CN`/`zh-TW` → ChineseGlobal
- [x] 2.3 Wire `MaterialApp` `locale` / `supportedLocales` / `localizationsDelegates` from the store with live rebuild on language change
- [x] 2.4 Update `LanguageSettingsPage` to three endonym options; remove IME-only footer copy; drive selection via store BCP-47 values

## 3. Seed ARBs from lws-ui (implemented features)

- [x] 3.1 Inventory implemented HMI surfaces vs lws-ui key namespaces; produce a mapping checklist (settings, wifi, bluetooth, device info, alarms, boot self-check, monitor, home, advanced)
- [x] 3.2 Copy Settings chrome / language / units / common groups EN+ZH from lws-ui into parent ARBs (`snake_case` → lowerCamelCase)
- [x] 3.3 Copy Wi‑Fi / network / bluetooth / date-time / device-info / advanced-settings keys used by shipped pages
- [x] 3.4 Copy alarm title/body keys for codes present in `ProductAlarmCatalog` (and shared alarm chrome)
- [x] 3.5 Copy boot self-check + Monitor/Home chrome keys; author HMI-only gaps in EN+ZH
- [x] 3.6 Run `make l10n` after bulk import; fix placeholder/`@metadata` issues in `app_en.arb`

## 4. Migrate Settings UI strings

- [x] 4.1 Replace Settings shell tab titles and Common Settings group/row labels with `AppLocalizations`
- [x] 4.2 Migrate Language / Unit pages and Common Settings summaries
- [x] 4.3 Migrate Display & Sound, Date & Time, Input, Network (Wi‑Fi/Ethernet/Bluetooth/proxy) sub-pages already shipped
- [x] 4.4 Migrate Device Information tab labels
- [x] 4.5 Migrate Advanced Settings section headers, row titles, and hints
- [x] 4.6 Migrate remaining shipped Settings pages (IP Camera, Keyboard, RGB LED, Misc, USB OTG, sound/volume/brightness/screen-off as applicable)

## 5. Migrate alarms, Monitor, boot self-check, Home

- [x] 5.1 Resolve warn dialog title/body through App localization keyed by alarm catalog; remove English-only catalog literals as sole copy source
- [x] 5.2 Migrate Monitor shell title, tabs, Machine Status / Alarm Information / related labels
- [x] 5.3 Migrate boot self-check dialog title, items, status words, footer
- [x] 5.4 Migrate Home text chrome; replace or supplement English-only mode WebP labels for Chinese locales
- [x] 5.5 Migrate process-library / other shipped product chrome still showing hardcoded English (if in scope for implemented features)

## 6. Verification

- [x] 6.1 Add/adjust widget or store tests for locale mapping, legacy `EN`/`ZH` read, and at least one l10n smoke assertion
- [x] 6.2 Run `make l10n-verify` and `flutter analyze` (pinned SDK) under `app/hmi/`
- [x] 6.3 Manual device check: switch `en-US` ↔ `zh-CN` (and `zh-TW`), confirm Settings/Monitor/alarm/self-check/Home update without restart; confirm CyberIME mapping still follows language
