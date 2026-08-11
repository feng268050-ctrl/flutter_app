## Context

FrostUI typography was partially standardized in change `frostui-typography-100-baseline-and-scaling` (`AppTypography` ladder, `HmiTypography` semantic roles, Small/Medium/Large via root `MediaQuery`). Production code still violates SoT: upgrade pages use `settingsRowValue` / `supporting` at 16–20 with ad-hoc `copyWith(fontSize: 22)`, `SettingsHelpFooter` recently gained a local `SettingsDimens.helpTextSize = 22`, and module files keep numeric aliases (`statusLabelFontSize = 20`) that duplicate the ladder.

The audit plan [`docs/frostui_global_typography_audit_and_cleanup_plan.md`](../../../docs/frostui_global_typography_audit_and_cleanup_plan.md) proposes full cleanup. **Product decision for this change:** `upgradeDescription` = **22** (`AppTypography.sectionTitle`), `settingsHelpFooter` = **20** (`AppTypography.control`) — intentionally different roles even when both are “important help” copy, so footer can stay one step below upgrade mid-card guidance.

Stakeholders: Settings / OTA operators (read distance), design system maintainers, CI owners.

## Goals / Non-Goals

**Goals:**

- Introduce `HmiTypography.upgradeDescription` and `HmiTypography.settingsHelpFooter` as first-class semantic roles with fixed 100% baselines (22 / 20).
- Migrate P0 call sites: four Settings upgrade pages, `SettingsHelpFooter`, `cyber_upgrade_ui` check-card / completion-tip defaults when used from lws_hmi.
- Remove duplicate intermediates (`SettingsDimens.helpTextSize`, `helpTextStyle`, page `descriptionSize` constants, `supporting.copyWith(fontSize: …)` on these paths).
- Extend `frostui-typography` spec with enforceable rules; stage P1 module dedup and P2 lint in tasks.
- Ensure both new roles participate in reading TextScaler (0.90 / 1.00 / 1.12) like other reading UI.

**Non-Goals:**

- Re-baseline entire `AppTypography` ladder or button/tab metrics.
- Force gauge/clock/dashboard glyphs into reading roles (remain `HmiDisplayTypography`).
- Register every special size (38 CNC title, 41 toast, etc.) in P0 — P2 follow-up.
- Change copy/content of upgrade or settings strings.

## Decisions

### 1. Two semantic tokens, not one shared “large supporting”

**Decision:** Add separate `upgradeDescription` and `settingsHelpFooter` on `HmiTypography`, mapped to different base styles at 100%:

| Role | 100% baseline | Base mapping |
|------|---------------|--------------|
| `upgradeDescription` | 22 | `AppTypography.sectionTitle` |
| `settingsHelpFooter` | 20 | `AppTypography.control` |

**Rationale:** Same number today does not imply same product role. Upgrade mid-card copy is primary operational guidance; card footnotes are secondary but still above weak `supporting` (16). Independent tokens allow future tuning (e.g. footer 20, upgrade 24) without cross-page churn.

**Alternatives considered:** Single `largeSupporting` at 22 — rejected (coupling). Reuse `sectionTitle` directly in widgets — rejected (blurs section headers vs body copy).

### 2. Footer at 20, not 22 (override audit doc §5.2)

**Decision:** `settingsHelpFooter` maps to **control (20)**, not sectionTitle (22), per operator request.

**Rationale:** Footnotes sit below cards and should remain visually subordinate to upgrade description and section titles while still readable at HMI distance.

### 3. Theme extension implementation

**Decision:** Add `TextStyle upgradeDescription` and `TextStyle settingsHelpFooter` fields to `HmiTypography` with defaults as above; expose via `context.hmiTypography.*`. Add unit tests asserting `fontSize` at Medium 100%.

**Rationale:** Matches existing pattern (`reminderBody`, `dialogBody`, etc.). No new `ThemeExtension` type.

### 4. SettingsHelpFooter owns role, not SettingsDimens

**Decision:** `SettingsHelpFooter` default style = `context.hmiTypography.settingsHelpFooter.copyWith(color: Colors.white54, height: 1.35)`. Delete `SettingsDimens.helpTextSize` / `helpTextStyle`. Optional `style` override remains for exceptional cases but SHOULD NOT change fontSize in production.

**Rationale:** Component is the SoT consumer; dimens layer should not re-export numeric sizes.

### 5. Upgrade pages inject role into cyber_upgrade_ui

**Decision:** App upgrade pages pass `statusStyle: context.hmiTypography.upgradeDescription.copyWith(color: CyberColors.textSecondary, height: 1.4)` (and equivalent for completion tip / running message). Update `UpgradeCheckCard` / `UpgradeCompletionTip` package fallbacks from 16 → document that App must inject; optionally bump package default to a neutral “inherit from theme” pattern or 22 with comment that App overrides.

**Rationale:** Package cannot depend on `HmiTypography`; App owns product baseline. Package defaults should not fight App at 16.

### 6. Forbidden patterns (enforcement staged)

**Decision:** P0 = manual migration + code review. P2 = extend `scripts/flutter/check_no_bare_font_size.sh` / `make check-typography` to flag `copyWith(fontSize:` in `lib/features/**` and `lib/ui/**`, whitelist only `lib/app/theme/**` and documented painters.

**Rationale:** Lint before full P1 dedup would create noise; land roles first, then tighten CI.

### 7. P1 module constants reference AppTypography.*Size

**Decision:** Replace duplicates like `wheelSelectedTextSize = 22` with `AppTypography.sectionTitleSize` or direct `HmiTypography` role where a widget paints text.

**Rationale:** Keeps geometry constants numeric but ties them to ladder SoT.

## Risks / Trade-offs

- **[Risk] Recent in-flight edits used helpTextSize=22 for both upgrade and footer** → P0 task explicitly reverts footer to 20 via `settingsHelpFooter` and keeps upgrade at 22 via `upgradeDescription`.
- **[Risk] cyber_upgrade_ui tests assume 16px fallback** → Update package widget tests when changing defaults.
- **[Risk] Large mode makes footnotes + descriptions compete with section titles** → Acceptable; both scale uniformly; display clamp unchanged.
- **[Trade-off] Footer 20 vs audit doc 22** → Documented product override in proposal/design/specs.

## Migration Plan

1. Land `HmiTypography` fields + tests.
2. Switch `SettingsHelpFooter` and upgrade pages (parallel-safe).
3. Remove `SettingsDimens.helpTextSize` / `helpTextStyle`; grep for remaining `helpTextStyle(` call sites.
4. Adjust `cyber_upgrade_ui` defaults or document injection-only contract.
5. `flutter test` typography + upgrade widget tests; visual spot-check on emulator (Settings footnotes + System/HMI upgrade idle copy).
6. P1/P2 tasks in follow-up commits within same change branch.

Rollback: revert theme fields and widget style lines; no data migration.

## Open Questions

- Should `UpgradeCheckCard` headline (available version, currently 22 via `sectionTitle`) stay separate from `upgradeDescription`? **Working assumption:** yes — headline = title role, body/status = `upgradeDescription`.
- P2 lint: block `AppTypography.*` in `lib/features/**` entirely or only bare `fontSize`? **Defer to P2 task; start with fontSize + copyWith(fontSize).**
