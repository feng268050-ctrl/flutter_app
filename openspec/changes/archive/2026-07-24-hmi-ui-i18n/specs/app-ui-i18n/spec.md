## ADDED Requirements

### Requirement: Flutter gen-l10n catalogs ship with the HMI App

The product App under `app/hmi/` SHALL use Flutter official `flutter gen-l10n` with `l10n.yaml`, parent ARB files `app_en.arb` (template with `@metadata`) and `app_zh.arb`, child locale ARBs for `en_US` / `zh_CN` / `zh_TW`, and committed generated `AppLocalizations` Dart sources. The App SHALL depend on `flutter_localizations` and enable `flutter: generate: true`. Runtime supported locales SHALL be `en-US`, `zh-CN`, and `zh-TW` (no bare `en` / `zh` as MaterialApp `supportedLocales` entries).

#### Scenario: Generated localizations are available

- **WHEN** the App builds with the pinned Flutter SDK
- **THEN** `AppLocalizations` is importable and resolves keys for `en_US`, `zh_CN`, and `zh_TW`

#### Scenario: Parents are the human-edited sources

- **WHEN** a developer adds or changes a product UI string
- **THEN** the edit is made in `app_en.arb` and `app_zh.arb` (and optional manual `app_zh_TW.arb` overrides)
- **AND** child stub/override ARBs plus generated Dart are refreshed via the documented l10n commands

### Requirement: Host l10n commands mirror LaserCyber Mobile

The repository SHALL provide host commands that sync child ARBs and regenerate localizations:

- `make l10n` — sync child ARBs then `flutter gen-l10n` for `app/hmi`
- `make l10n-sync` — sync child ARBs only
- `make l10n-gen` — `flutter gen-l10n` only
- `make l10n-verify` — fail if child ARBs or generated Dart drift from what sync+gen would produce

zh_TW child content SHALL be derived from Simplified Chinese via OpenCC (with preserved manual overrides), adapted from the LaserCyber Mobile workflow.

#### Scenario: Full workflow regenerates children and Dart

- **WHEN** an operator runs `make l10n` after editing parent ARBs
- **THEN** child ARBs and `app_localizations*.dart` are updated for `app/hmi`

#### Scenario: Verify detects drift

- **WHEN** generated l10n outputs are stale relative to parents/sync rules
- **AND** `make l10n-verify` runs
- **THEN** the command exits non-zero

### Requirement: MaterialApp locale follows Common Settings Language

`LwsHmiApp` SHALL configure `MaterialApp` with `locale`, `supportedLocales`, and `localizationsDelegates` (including `AppLocalizations.delegate` and Flutter global Material/Widgets/Cupertino delegates) driven by `CommonSettingsStore` language. Changing Language SHALL rebuild the widget tree so operator-visible `AppLocalizations` strings update without requiring a process restart. CyberIME language provider mapping SHALL remain in effect for the same preference.

#### Scenario: Cold start applies persisted locale

- **WHEN** `common-settings.json` has `language` = `zh-CN` and the App starts
- **THEN** `MaterialApp.locale` is `zh_CN`
- **AND** `AppLocalizations.of(context)` returns Simplified Chinese strings for migrated keys

#### Scenario: Language change updates UI locale live

- **WHEN** the operator changes Language from `en-US` to `zh-CN` in Settings
- **THEN** migrated UI strings switch to Simplified Chinese without an App process restart

### Requirement: Product copy prefers lws-ui translations for implemented features

For operator-visible strings on **already-implemented** HMI product surfaces, ARB English and Simplified Chinese values SHALL be copied from sibling lws-ui `values` / `values-zh` `strings.xml` when a semantic match exists. Keys SHALL use lowerCamelCase derived from lws-ui `snake_case` names. When lws-ui has no matching string, the App SHALL author EN + ZH in the parent ARBs. LaserCyber Mobile cloud ARB catalogs MUST NOT be the primary copy source for on-device HMI settings/alarm/Wi‑Fi strings.

#### Scenario: Settings label matches lws-ui when present

- **WHEN** a Settings chrome string exists in lws-ui (e.g. language / units / Wi‑Fi group labels)
- **THEN** the corresponding HMI ARB EN and ZH values match lws-ui (modulo placeholder syntax)

#### Scenario: HMI-only string is authored when missing upstream

- **WHEN** an implemented HMI surface needs a string with no lws-ui counterpart
- **THEN** EN and ZH entries exist in the parent ARBs and are reachable via `AppLocalizations`

### Requirement: Widgets consume AppLocalizations for migrated surfaces

Migrated product UI MUST obtain operator-visible copy through `AppLocalizations.of(context)` (or an `AppLocalizations` extension). Hardcoded English (or mixed) literals MUST NOT remain as the sole source of truth for those migrated call sites. Enum / alarm-code → label maps MAY live in `extension` helpers on `AppLocalizations`.

#### Scenario: Migrated Settings row uses l10n

- **WHEN** a migrated Common Settings row is rendered under `zh-CN`
- **THEN** its title/summary text comes from `AppLocalizations` rather than a hardcoded English literal
