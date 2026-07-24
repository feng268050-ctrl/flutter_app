## 1. CommonSettingsStore

- [x] 1.1 Add `CommonSettingsStore` (`language` / `unit` keys, defaults `EN` / `Metric`, warm-read, soft-fail corrupt JSON, write on change) at `${OsPaths.varHmi}/common-settings.json`
- [x] 1.2 Add `CommonSettingsScope` InheritedWidget (of / maybeOf)
- [x] 1.3 Unit tests: defaults when absent, round-trip persist, corrupt JSON soft-fail, invalid values → defaults

## 2. App bootstrap & CyberIME

- [x] 2.1 Inject/create store in `LwsHmiApp`; `warmRead()` with Misc/Advanced; wrap tree with `CommonSettingsScope`
- [x] 2.2 Replace fixed English CyberIME language provider with a mutable provider driven by store (`EN` → english, `ZH` → chinese); update on language change
- [x] 2.3 Update `OsPaths` / path-layout comments to mention `common-settings.json` under `/var/lib/hmi/`

## 3. Settings UI wiring

- [x] 3.1 Wire `LanguageSettingsPage` to store; remove “not persisted yet”; selection writes immediately
- [x] 3.2 Wire `UnitSettingsPage` to store; remove “not persisted yet”; selection writes immediately
- [x] 3.3 Update `CommonSettingsTab` Language / Unit row summaries from store (listen / rebuild on change)

## 4. Verification

- [x] 4.1 `flutter analyze` / store unit tests under `app/hmi/`
- [x] 4.2 Manual: set Language + Unit → kill/restart HMI → values restored; IME language follows Language; Misc/HAL prefs unchanged
