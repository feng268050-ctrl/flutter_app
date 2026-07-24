## Context

Common Settings already splits persistence by ownership:

| Bucket | Path | Examples |
|--------|------|----------|
| HAL / platform | `/var/lib/hal/*` | brightness, AutoSleep, volume, ButtonFeedback sound, mouse, keyboard, datetime |
| Misc | `/var/lib/hmi/misc-settings.json` | Startup Self-Check, System Status Overlay, Ground Lock Alarm |
| Advanced | `/var/lib/hmi/advanced-settings.json` | AI / dangerous / thresholds |

Language and Unit live under Display & Sound but are product prefs (not HAL, not Misc). Pages still hold local state and show “not persisted yet”. `LwsHmiApp` already warm-reads Misc / Advanced / SoundEffect and registers a **fixed** English CyberIME language provider.

## Goals / Non-Goals

**Goals:**

- Persist Language + Unit (and leave room for future peers) in one App JSON file: `/var/lib/hmi/common-settings.json`.
- Mirror existing store patterns (`MiscSettingsStore`): injectable path, `warmRead`, soft-fail corrupt JSON, write on change, `ChangeNotifier` + InheritedWidget scope.
- Wire Settings UI summaries and detail pages to the store; remove “not persisted yet” copy.
- On warm-read / language change, update CyberIME language provider (`EN` → EnglishGlobal, `ZH` → ChineseGlobal) so IME tracks the preference (Chinese asset gaps remain CyberIME’s documented limit).

**Non-Goals:**

- Moving Misc keys into `common-settings.json`, or Sound Effect / other HAL prefs into App JSON.
- Full Flutter `Localizations` / ARB catalog for every string.
- Converting Monitor / process numeric displays to Imperial (preference only in this change).
- Enabling Ground Lock Alarm UI (still Misc; already has a store key).
- Buildroot / overlay changes beyond docs that mention `/var/lib/hmi/` inventories.

## Decisions

### D1: Separate `common-settings.json` (not fold into Misc)

**Choice:** New file + `CommonSettingsStore`, parallel to Misc/Advanced.

**Why:** Specs already say Misc is for Common Settings → **Misc** toggles only; Sound Effect must not land in Misc. Language/Unit are Display & Sound product prefs — a third App JSON keeps section ownership clear and avoids Misc schema growth.

**Alternatives:** (a) Put keys in `misc-settings.json` — rejected (wrong section / existing “unified Misc” contract). (b) Per-key files — rejected (same anti-pattern Misc already avoided).

### D2: JSON key/value shape

**Choice:**

```json
{
  "language": "EN",
  "unit": "Metric"
}
```

- `language`: `"EN"` | `"ZH"` (match current Settings page codes).
- `unit`: `"Metric"` | `"Imperial"` (match current labels).
- Defaults when file/keys missing: `EN`, `Metric`.
- Unknown values → default for that key; do not rewrite file until an operator change (same lazy-write spirit as Misc defaults).

**Why:** Matches UI tokens already shown; no enum migration churn.

### D3: Scope + bootstrap

**Choice:** `CommonSettingsScope` under `LwsHmiApp` next to `MiscSettingsScope`; `warmRead()` in `initState` with Misc/Advanced; optional constructor inject for tests.

**Why:** Same bootstrap path operators already depend on for prefs.

### D4: Language → CyberIME (mutable provider)

**Choice:** Replace fixed `CyberImeFixedLanguageProvider(english)` with a small mutable provider owned by the App (or update registration when language changes). Map `EN` → `CyberImeGlobalKind.english`, `ZH` → `chinese`. Do **not** block on full UI string localization.

**Why:** Language page already offers ZH; IME registry is the existing hook. Full Material locale rebuild can follow later without blocking persistence.

**Alternatives:** Persist-only without IME apply — rejected (preference would be invisible to soft keyboard).

### D5: Unit consumers

**Choice:** This change only persists + surfaces Unit in Settings. Call sites that need Metric/Imperial conversion subscribe later via `CommonSettingsScope` / store getters.

**Why:** No current product UI converts units; shipping the store first avoids speculative Monitor churn.

### D6: Boundary checklist (what must NOT go in common-settings.json)

- Misc section switches → `misc-settings.json`
- Anything with a HAL controller / `/var/lib/hal/` conf → keep HAL
- Advanced tab → `advanced-settings.json`
- IP Camera host / product.ini → existing product / HAL paths

Future Common Settings product prefs that fit none of the above SHOULD extend this store rather than invent new files under `/var/lib/hmi/`.

## Risks / Trade-offs

- **[Risk] Operators expect full ZH UI strings after Language=ZH** → Mitigation: Spec/UI can note language applies to IME (and future localization); CyberIME Chinese gaps remain as today.
- **[Risk] Confusing three App JSON files** → Mitigation: Document ownership in os-path-layout / settings-ui; naming mirrors section (`common` vs `misc` vs `advanced`).
- **[Risk] Race if multiple stores write same path** → Mitigation: Single `CommonSettingsStore` instance; no second writer.
- **[Trade-off] Unit preference unused by Monitor yet** → Acceptable; store is the contract for later slices.

## Migration Plan

1. Ship App with store; missing file → defaults (no mandatory seed write).
2. No legacy file to import (Language/Unit never persisted).
3. Rollback: remove store usage; orphaned `common-settings.json` is harmless.

## Open Questions

None blocking — Imperial display conversion and full i18n are deferred explicitly.
