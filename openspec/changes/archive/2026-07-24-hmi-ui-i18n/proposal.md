## Why

Language preference is already persisted (`common-settings.json`) and wired to CyberIME, but the HMI product UI remains English-only hardcoded strings. Operators selecting 中文 reasonably expect the Settings / Monitor / Alarm / Home surfaces to switch language. LaserCyber Mobile already has a proven Flutter `gen-l10n` stack (parent–child ARBs + `make l10n*` commands); lws-ui already holds the canonical EN/ZH product copy for the same on-device features.

## What Changes

- Adopt Flutter official **`flutter gen-l10n`** in `app/hmi/` (ARB catalogs, `l10n.yaml`, `flutter_localizations`, committed generated `AppLocalizations`).
- Port Mobile’s **parent–child ARB workflow and host commands** (`make l10n` / `l10n-sync` / `l10n-gen` / `l10n-verify`, sync script + OpenCC zh_TW) into this repo under `scripts/` + root `Makefile`.
- Seed EN/ZH strings for **already-implemented HMI features** by copying from lws-ui `strings.xml` where keys exist; author missing keys for HMI-only surfaces.
- Drive `MaterialApp.locale` / `supportedLocales` / `localizationsDelegates` from `CommonSettingsStore` language so UI rebuilds on change (IME mapping remains).
- Replace hardcoded operator-visible strings in product surfaces with `AppLocalizations.of(context)!` (domain extensions for enums/alarm catalogs as needed).
- Language settings endonyms and store wire values align with Mobile BCP-47 tags (`en-US` / `zh-CN` / `zh-TW`), with **backward-compatible** read of existing `EN` / `ZH` JSON.

## Capabilities

### New Capabilities

- `app-ui-i18n`: Flutter gen-l10n catalogs, runtime locale resolution from Common Settings, and host `make l10n*` tooling (Mobile-parity workflow) for HMI product UI strings

### Modified Capabilities

- `settings-ui`: Language selection applies full UI locale (not IME-only); Language page options/endonyms match supported locales; Common Settings summaries use localized labels where appropriate
- `common-settings-persist`: Language wire values become BCP-47 (`en-US` / `zh-CN` / `zh-TW`) with legacy `EN`/`ZH` accepted on read
- `cyber-alarm`: Product alarm title/body presentation resolves through App localization keys (seeded from lws-ui alarm strings) rather than English-only catalog literals
- `product-home-ui`: Home chrome / mode labels use localized strings (replace or supplement English-only WebP text assets where needed)
- `product-monitor-ui`: Monitor tab chrome and labels use AppLocalizations
- `product-boot-self-check`: Boot self-check dialog strings use AppLocalizations
- `advanced-settings-ui`: Advanced Settings group/row labels and hints use AppLocalizations

## Impact

- **App (`app/hmi/`):** new `lib/l10n/` ARBs + generated Dart; `l10n.yaml`; `pubspec` `flutter_localizations` + `generate: true`; `LwsHmiApp` MaterialApp locale wiring; migrate product UI string literals; alarm catalog / home assets
- **Store:** `CommonSettingsStore` language codes + labels; tests updated for new wire values + legacy mapping
- **Host tooling:** new `scripts/flutter/l10n*.sh`, sync/OpenCC scripts (adapted from lasercyber-mobile); Makefile targets; AGENTS.md / README rebuild notes for `make l10n`
- **Packages:** `cyber_ui` / `cyber_ime` / `cyber_alarm` chrome strings stay package-owned for now unless a product string is clearly App-presented; App seeds alarm catalog localization
- **Out of scope:** Imperial unit conversion math; full ChineseGlobal IME asset completion; P2 demo / non-product surfaces as first priority; translating `cyber_ui` design-system internals; cloud/mobile-only ARB keys from lasercyber-mobile
