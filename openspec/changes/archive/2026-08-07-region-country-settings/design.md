## Context

Product markets are **US and Europe**. Wi‑Fi still seeds `country=CN` in rootfs `wpa_supplicant.conf` and bring-up scripts; Date & Time still presents Asia-centric curated defaults (`Asia/Shanghai` prominent; China NTP pool in catalog). Language / Unit already live in App-owned `/var/lib/hmi/common-settings.json` via `CommonSettingsStore`. Kernel/regulatory.db embedding and AIC `custregd=0` already land in prior work — this change owns the **operator Country preference** and its apply path, not firmware embedding.

Stakeholders: Settings / Common Settings UX, Wi‑Fi stack (wpa + cfg80211 regdomain), Date & Time (timezone + NTP), factory/image defaults.

## Goals / Non-Goals

**Goals:**

- Default Country **`US`** (ISO 3166-1 alpha-2) for missing prefs and image Wi‑Fi seeds.
- Common Settings: **Country row before Language** in the Display & Sound untitled card.
- Country drives: (1) wireless `country=` / regdomain, (2) suggested IANA timezone, (3) preferred primary NTP hostname from curated mapping.
- Persist Country with Language/Unit peers; apply on warm-read (boot) and on operator change.
- Language stays independent (no auto locale switch from Country).

**Non-Goals:**

- Auto-changing Language or Unit from Country (Unit may stay Metric default; Imperial is operator choice).
- Replacing operator-customized timezone/NTP when they already diverged from the previous country defaults (see Decisions).
- GPS/GNSS geolocation; IP auto-timezone remains a separate Date & Time toggle.
- Changing AIC firmware / `regulatory.db` packaging (already done); this change only sets runtime country.
- Perfect multi-zone countries (e.g. US West Coast): Country seeds one primary zone; Date & Time remains authoritative.

## Decisions

### 1. Persist Country in `common-settings.json`

- **Choice:** Key `country` (ISO alpha-2 uppercase), default `US`, peer of `language` / `unit` in `CommonSettingsStore`.
- **Why:** Same App-owned product prefs class; no new HAL file; Settings already owns Language UX here.
- **Alternatives:** HAL `/var/lib/hal/region.conf` — rejected (Country is product UX, not board HAL); Vendor Storage market SKU — rejected for operator-changeable Settings.

### 2. Full ISO country / territory catalog + defaults table

- **Choice:** App owns the full ISO 3166-1 alpha-2 list (plus `XK`), with English + Simplified Chinese display names and a primary IANA timezone per entry. Preferred NTP is `pool.ntp.org` for all Country-driven defaults (including CN — China pool remains a manual Date & Time preset only).
- **Why:** Primary markets are US/EU, but product may ship worldwide; operators need any sovereign / administrative territory code for regulatory + clock seeds.
- **UI:** Searchable Country page (name or code); list sorted A–Z by English name.
- **Alternatives:** US/EU short list — rejected (blocks non-EU sales); derive TZ only from IP geo — rejected as primary (needs network).

### 3. Apply policy when Country changes

On Country set (and once after warm-read if Wi‑Fi country ≠ preference):

1. Persist `country`.
2. Apply wireless: rewrite/upsert wpa `country=` (via existing Wi‑Fi controller / board helper) + `iw reg set <CC>` (or equivalent); soft-fail if radio down.
3. Clock/network defaults:
   - If `auto_timezone` is on → leave timezone to geo path; still update NTP preferred if NTP still equals previous country default or is unset.
   - If `auto_timezone` is off → set timezone to country default **when** current timezone is unset **or** equals the *previous* country’s default (treat as still Country-linked).
   - NTP: set primary to country preferred **when** unset **or** equals previous country’s preferred (or legacy `cn.pool.ntp.org` on first migrate).
- **Why:** “Can influence” without clobbering deliberate Date & Time customizations.
- **Alternatives:** Always overwrite TZ/NTP on Country change — simpler but hostile; Rejected for production appliances.

### 4. Image / script seeds → US

- Rootfs `wpa_supplicant.conf` and `run-wpa.sh` / `wifi-stack-up.sh` default `country=US`.
- Document that App Country is source of truth after first warm-read; seeds only cover pre-App bring-up.

### 5. UI placement

- Common Settings Display & Sound card: **Country → Language → Unit → Display → Sound**.
- New `CountrySettingsPage` (searchable full ISO catalog with EN/ZH names); summary row shows selected country name.

## Risks / Trade-offs

- **[Risk]** Changing Country while on Wi‑Fi may briefly disrupt association if wpa reloads. → Mitigation: prefer `SET country` / `iw reg set` without full stack restart when possible; document soft-fail.
- **[Risk]** Multi-zone countries get one primary TZ seed. → Mitigation: Date & Time page remains authoritative; auto-timezone optional.
- **[Risk]** Existing field units with `country=CN` in userdata. → Mitigation: warm-read applies App Country (default US if missing key); one-shot migrate away from CN when key absent.
- **[Risk]** Catalog drift vs future ISO assignments. → Mitigation: data file is regenerable; unknown stored codes normalize to `US`.

## Migration Plan

1. Ship App with Country store + UI + apply path; ship rootfs seed `country=US`.
2. Devices with no `country` key: default US and apply regulatory once.
3. Devices with explicit future `country` key: honor it.
4. Rollback: revert App/overlay; wpa may remain at last applied country until seed/scripts restored.

## Open Questions

- Whether Unit should *suggest* Imperial for US (non-goal for v1; leave Metric unless product asks).
- Whether Traditional Chinese UI should use a separate `nameZhTw` column (v1 reuses Simplified Chinese names).
