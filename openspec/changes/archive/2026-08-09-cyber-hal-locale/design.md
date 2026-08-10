## Context

Today General Settings (en: **General** / zh: **通用设置**, code: Common Settings) persists Language, Unit, and Country in App-owned `CommonSettingsStore` (`/var/lib/hmi/common-settings.json`). Region catalog, clock-link policy, and Wi‑Fi regulatory apply live under `app/lws_hmi/features/settings/application/region_*`, while `WifiCountryApply` already sits in `cyber_hal` network. Other HAL domains already use `/var/lib/hal/*.conf` (`datetime.conf`, `power.conf`, `mouse.conf`, …). Locale prefs should follow that pattern, with the Country wire key renamed to **`region`**, and **no legacy JSON migration**.

Stakeholders: HAL package consumers, `lws_hmi` General Settings, Wi‑Fi regulatory, Date & Time (linked TZ/NTP), cloud `commonSettings` snapshot, FHS persist schema.

## Goals / Non-Goals

**Goals:**

- Expose portable **Region**, **PreferredLanguage**, and **UnitSystem** via `package:cyber_hal/locale.dart`.
- HAL owns normalize/catalog/persist/read APIs and **Region apply** (wireless regulatory + Region-linked timezone/NTP policy).
- Persist at **`/var/lib/hal/locale.conf`** with keys `language`, `unit`, `region`.
- `lws_hmi` General Settings Language / Unit / Country/Region consume HAL locale; UI copy and row order stay as today.
- Language → Flutter locale + CyberIME remains App responsibility, driven by PreferredLanguage from HAL.
- Keep the implementation small: no import/strip path from `common-settings.json`.

**Non-Goals:**

- Migrating or reading legacy `common-settings.json` Language / Unit / Country values.
- Auto-changing PreferredLanguage or UnitSystem from Region.
- GPS / IP geolocation as Region source (Date & Time auto-timezone stays separate).
- Moving Misc / backlight / power prefs into locale.
- Renaming operator-facing strings away from Country/Region / Language / Unit.
- Changing image Wi‑Fi seed `country=US` or AIC `custregd=0` packaging (already done).
- Requiring `settings-restore.service` to apply language/unit/region (HMI process still warm-reads and applies Region side effects on start).

## Decisions

### 1. New domain barrel `cyber_hal/locale`

- **Choice:** Add `packages/cyber_hal/lib/locale.dart` exporting `lib/src/locale/**` (types, catalog, store/controller, region applier). Mirror `datetime.dart` / `network.dart` style.
- **Why:** Clear domain boundary; Apps import one barrel.
- **Alternatives:** Stuff into `network.dart` — rejected (Language/Unit are not network); keep App-only — rejected (proposal goal).

### 2. Typed values vs wire strings

| Type | Persist key | Wire values | Default |
|------|-------------|-------------|---------|
| `PreferredLanguage` | `language` | BCP-47 `en-US` / `zh-CN` / `zh-TW` (+ optional read normalize `EN`/`ZH`) | `en-US` |
| `UnitSystem` | `unit` | `Metric` / `Imperial` | `Metric` |
| `Region` | **`region`** | ISO 3166-1 alpha-2 (+ `XK`) | `US` |

- **Choice:** Value types (or enums + parse) with `toWire` / `parse` / `normalize`; catalog entries stay data-driven for Region.
- **Why:** Call sites stop using magic strings; `region` matches the type name.
- **Alternatives:** Keep persist key `country` — rejected (user requires `region`).

### 3. Persistence at `/var/lib/hal/locale.conf`

- **Choice:** HAL `LocaleSettings` reads/writes **`/var/lib/hal/locale.conf`** as `key=value` lines (same style as `datetime.conf` / `mouse.conf`), injectable path for tests. Example:

  ```text
  language=en-US
  unit=Metric
  region=US
  ```

- **Why:** Matches other HAL packages under `/var/lib/hal/`; clear FHS ownership.
- **Alternatives:** Keep `/var/lib/hmi/common-settings.json` — rejected; `/var/lib/hal/locale.json` — rejected in favor of existing `.conf` convention.

### 4. No migration from `common-settings.json`

- **Choice:** HAL locale **only** reads/writes `locale.conf`. Absent or corrupt file → defaults. Any leftover `language` / `unit` / `country` in `common-settings.json` is **ignored** (not imported, not stripped by locale code). App removes locale writes from `CommonSettingsStore` / may delete the store if empty of peers.
- **Why:** Clean code; no dual-SoT or migrate helpers; acceptable to reset field Language/Unit/Region once.
- **Alternatives:** One-shot JSON import — rejected per product decision.

### 5. Region apply lives in HAL locale

- **Choice:** Move `RegionCountryCatalog` / `RegionSettingsPolicy` / `RegionSettingsApplier` into `cyber_hal` locale. Apply sequence: persist `region=` → `WifiCountryApply` → conditional TZ/NTP via `DateTimeController`. Soft-fail; never crash HMI. First seed = missing `region` key in `locale.conf`.
- **Why:** Regulatory is HAL-adjacent; policy is reusable.
- **Alternatives:** Leave applier in App — rejected.

### 6. App adapter + cloud wire

- **Choice:** Replace or remove `CommonSettingsStore` locale fields; use HAL `LocaleSettings`. Cloud / device snapshot `commonSettings` uses **`region`** (not `country`) alongside `language` / `unit`. General Settings pages keep operator copy.
- **Why:** Align snapshot with on-disk key; single SoT.
- **Alternatives:** Dual-publish `country` + `region` — rejected.

### 7. Naming: API vs UI

- **Choice:** Code/API/persist: `Region` / `region`. Operator UI: Country/Region (existing ARB). PreferredLanguage / UnitSystem similarly (Language / Unit in UI).
- **Why:** HAL vocabulary matches file keys; shipped copy unchanged.

## Risks / Trade-offs

- **[Risk]** Field units lose prior Language / Unit / Country from JSON. → Mitigation: accepted; defaults apply until operator reconfigures; document in proposal impact.
- **[Risk]** Orphan `common-settings.json` locale keys confuse operators reading files by hand. → Mitigation: App stops writing those keys; optional later cleanup outside this change’s HAL path.
- **[Risk]** Cloud consumers expecting `country`. → Mitigation: **BREAKING** rename to `region` with App.
- **[Risk]** Clock apply needs `DateTimeController`. → Mitigation: inject dependency (same as today).

## Migration Plan

1. Land HAL locale types + `locale.conf` I/O + applier + package tests (no JSON import).
2. Point `lws_hmi` bootstrap, General Settings, and cloud snapshot at HAL (`region` key); delete App locale JSON ownership.
3. Devices with only old JSON: first boot uses defaults until General Settings is changed.
4. Rollback: revert App + package; `locale.conf` if already written is ignored by old builds that only read JSON (old JSON may still be stale).

## Open Questions

- Whether to delete empty `CommonSettingsStore` entirely once locale keys leave (yes if no remaining peers).
- Whether Traditional Chinese Region labels need `nameZhTw` (v1 keeps Simplified names as today).
