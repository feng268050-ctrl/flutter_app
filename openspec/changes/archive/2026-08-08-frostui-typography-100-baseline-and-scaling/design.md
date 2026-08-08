## Context

HMI typography already has layered tokens (`AppTypography` ladder → `HmiTypography` roles → button/tab/display metrics), but Medium (100%) is not fully frozen: tip dialogs still derive body size from `tipBodySizeForTitle`, production surfaces still use bare `fontSize` literals, Tab label size is duplicated (`HmiTabMetrics.labelFontSize` vs `HmiTypography.primaryTabLabel`), and clock/dashboard sizes are duplicated across `HmiTypography` and `HmiDisplayTypography`. Several layout measurements (`WordBoundaryLabel`, `ProductTopTabs`, status bar) ignore `MediaQuery.textScaler`, so a future Large mode would mis-wrap or under-width tabs.

App shell currently wraps MediaQuery twice (`_appBuilder` sets `alwaysUse24HourFormat`, then `_matchFlutterPiDensity` re-reads `MediaQuery.of` and may rewrite size/DPR). Text size must be injected once and preserved through density matching so QEMU / flutter-pi / device share one scaler.

Plan SoT: `docs/frostui_typography_100_baseline_and_scaling_plan.md`.

## Goals / Non-Goals

**Goals:**

- Freeze 100% Medium as the only design baseline (semantic roles + named specialty tokens).
- Remove business use of title→ladder body derivation; delete `tipBodySizeForTitle` after migration.
- Make all layout-affecting text measurement scaler-aware (or explicitly documented as fixed display chrome).
- Ship Small / Medium / Large via `CommonSettingsStore.textSize` + root `TextScaler.linear(0.90|1.00|1.12)`.
- Apply minimal layout compensation for Large (row/tab/dialog), not three full metrics tables.

**Non-Goals:**

- Redesigning the 12–52 `AppTypography` ladder values.
- Per-locale font family changes or Chinese-specific tracking.
- Full three-way clones of all layout constants (`HmiButtonMetrics` heights stay Medium-first; Large height bumps only where validation fails).
- Pixel screenshot CI in the first ship (P2 in the plan; optional follow-up).
- Changing HAL / OEM / rootfs for text size (App JSON only).

## Decisions

### D1 — Three layers stay orthogonal

**Choice:** Keep **Typography** (role → 100% size), **Metrics** (container geometry), **TextScaler** (user scale) separate. No deriving body from title size; no putting label font size inside tab layout metrics.

**Alternatives:** Scale token tables per mode (3× maintenance); reject.

### D2 — Explicit dialog / tip / numeric roles

**Choice:** Add named roles on `HmiTypography` (and numeric-dialog specialty constants) with the 100% values from the plan (`dialogBody` 28, `importantDialogBody` 32, `dialogOptionLabel` 26, engineer/safety/reminder/numeric tokens). Migrate the five `tipBodySizeForTitle` call sites and the plan’s 13 bare literals, then remove `tipBodySizeForTitle` from the public business path (keep briefly as `@Deprecated` only if needed for a single PR split).

**Alternatives:** Keep ladder lookup under scaled titles — breaks once sizes are non-integer after scale.

### D3 — Hero button font = 24

**Choice:** Freeze `HmiTypography.buttonHeroFontSize = 24.0` as the 100% baseline (matches current code). No value change required; only confirm tests/docs stay on 24.

**Alternatives:** Raise to 26 — rejected by product confirmation.

### D4 — Tab metrics layout-only

**Choice:** Remove business use of `HmiTabMetrics.labelFontSize`; `HmiPrimaryTabContent` / `ProductTopTabs` measure and paint with `context.hmiTypography.primaryTabLabel` (+ weight from metrics). Keep `labelFontSize` as a deprecated alias equal to `AppTypography.navigationSize` only if process-mode tokens still need a compile-time constant; prefer pointing aliases at `HmiTypography` / `AppTypography.navigationSize` without a second “tab font” SoT.

### D5 — Display SoT = `HmiDisplayTypography`

**Choice:** Clock 120 / dashboard 68 live only in `HmiDisplayTypography`. `HmiTypography.clock` / `dashboardValue` either delegate to those constants or are removed from the extension if unused.

### D6 — Scale classes

| Class | Scale | Examples |
|---|---|---|
| A Full UI text | 0.90 / 1.00 / 1.12 | titles, tabs, body, settings, buttons, dialogs, tips |
| B Layout-coupled | same text scale + small metric overrides | settings row minHeight, tab height, dialog padding |
| C Display / geometry | clamp **0.95 / 1.00 / 1.05** or fixed 1.00 | Home clock, gauges, process wheel, CustomPainter glyphs |
| Home Quick Action | clamped (max **1.05**) **or** fit algorithm includes `TextScaler` | avoid fit-then-re-scale double bump |

**Choice for v1 Display:** clamp display/painter text at 1.05 for Large (and 0.95 for Small) via an explicit `displayTextScaler` helper, not raw MediaQuery, so Home layout stays stable.

### D7 — Persistence + UI

**Choice:**

```dart
enum AppTextSize { small, medium, large } // scale 0.90 / 1.00 / 1.12
```

Wire key `textSize` in `common-settings.json`; missing → `medium`. Common Settings Display & Sound card: Text Size row **between Display and Sound** (order: Country → Language → Unit → Display → **Text Size** → Sound). Sub-page with three options; change applies immediately (ListenableBuilder on store → MediaQuery).

### D8 — Single app MediaQuery pipeline

**Choice:** In `_appBuilder`, build one `MediaQueryData`:

```text
baseMq.copyWith(
  alwaysUse24HourFormat: ...,
  textScaler: TextScaler.linear(store.textSize.scale),
)
```

Pass that data into `_matchFlutterPiDensity` (signature change). Density path may rewrite `size` / `devicePixelRatio` only; MUST keep `textScaler` and `alwaysUse24HourFormat`.

**Alternatives:** Nest another MediaQuery outside density — easy to drop scaler on the FittedBox branch; rejected.

### D9 — Measurement APIs take TextScaler

**Choice:** `WordBoundaryLabel` / `WordBoundaryBody` accept `MediaQuery.textScalerOf(context)` for measure + wrap spacing. `ProductTopTabs._tabWidthFor` and status-bar width helpers pass the same scaler and use `primaryTabLabel` / status styles. Intentional fixed chrome MUST comment `// Intentionally fixed-size display chrome; does not follow user text size.`

### D10 — Layout compensation v1 (minimal)

| Param | Small | Medium | Large |
|---|---:|---:|---:|
| Text scale | 0.90 | 1.00 | 1.12 |
| Settings row minHeight | ~0.95× | 1.00× | ~1.10× |
| Tab height | 64 | 68 | 76 |
| Dialog vertical padding | ~0.95× | 1.00× | ~1.08× |

Buttons keep current heights initially; add Large-only height if English labels clip in validation.

Tip / light prompts: prefer scrollable body + screen-relative maxHeight over `FittedBox.scaleDown` that undoes user Large.

## Risks / Trade-offs

- **[Risk] Large English overflows fixed-width button groups** → English-first pass on process actions / dialogs; selective stretch or height bump, not global FittedBox.
- **[Risk] Density FittedBox + textScaler interaction on sim** → unit/widget tests with both DPR rematch and Large scaler; visual check on QEMU.
- **[Risk] Bare fontSize regressions after freeze** → optional custom_lint / CI grep in P2; document whitelist (`lib/app/theme/**`, registered painters).
- **[Risk] Home Quick Action double-scale** → implement clamp or scaler-aware fit in same change as MediaQuery injection (do not ship scaler without this).
- **[Trade-off] Display clamp ≠ full user scale** → product rule: geometry text does not grow as much as reading UI; document in settings help if needed later.

## Migration Plan

1. Land P0 token + measurement fixes under Medium-only (scaler still 1.0).
2. Land store + UI + MediaQuery; default remains Medium (no visual change for existing devices).
3. Validate Small / Large on QEMU then ynh960; adjust Class B overrides only where needed.
4. Rollback: omit `textSize` key or set `medium`; App soft-defaults to Medium.

## Open Questions

- ~~Exact Common Settings row order for Text Size~~ — resolved: **between Display and Sound**.
- Whether Display class uses 0.95/1.00/1.05 or hard 1.00 for clock only—default **0.95/1.00/1.05** unless Home QA prefers clock fixed at 1.00.
