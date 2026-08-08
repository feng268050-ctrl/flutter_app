## Why

FrostUI already has `AppTypography` / `HmiTypography` / button & tab metrics, but 100% Medium is not yet a frozen, maintainable baseline: tip bodies are derived from title ladder steps, production code still uses bare `fontSize` literals, and several `TextPainter` paths ignore `MediaQuery.textScaler`. Adding Small / Medium / Large (0.90 / 1.00 / 1.12) on top of that would amplify layout bugs. Freeze the 100% semantic baseline and fix scaler-aware measurement first, then ship the three text-size modes via Common Settings + root `MediaQuery`.

Source plan: [`docs/frostui_typography_100_baseline_and_scaling_plan.md`](../../../docs/frostui_typography_100_baseline_and_scaling_plan.md).

## What Changes

- Freeze **100% Medium** as the sole design baseline: semantic roles on `HmiTypography` (and specialty display tokens), not page-local numbers or “title → next ladder step” body derivation.
- Add explicit dialog / tip / numeric-dialog roles (e.g. `dialogBody`, `importantDialogBody`, `dialogOptionLabel`, engineer/safety/reminder/numeric tokens); migrate all `AppTypography.tipBodySizeForTitle` call sites, then remove that API from the business path.
- Clear remaining production bare `fontSize` literals (plan’s 13 call sites; Theme / painter metrics whitelist); enforce “business UI picks roles.”
- Freeze **button Hero** font size at **24** (matches current `HmiTypography.buttonHeroFontSize`).
- Make `HmiTabMetrics` layout-only; tab label size comes only from `HmiTypography.primaryTabLabel`.
- Deduplicate clock / dashboard sizes under `HmiDisplayTypography` as the single source of truth.
- Fix scaler-aware measurement: `WordBoundaryLabel` / `WordBoundaryBody`, `ProductTopTabs._tabWidthFor`, `WorkModeStatusBar`, and document Home Quick Action / Display clamp policy.
- Add `AppTextSize` (`small` / `medium` / `large` → 0.90 / 1.00 / 1.12), persist `textSize` in `common-settings.json` (default `medium`), Common Settings UI, and root `MediaQuery.textScaler` injection without dropping scaler in `_matchFlutterPiDensity`.
- First-pass layout compensation only (row / tab / dialog height overrides)—not three full metrics tables.
- Optional follow-up: CI lint against bare `fontSize` in `lib/features/**` and `lib/ui/**` (excluding demos / theme whitelist).

## Capabilities

### New Capabilities

- `frostui-typography`: 100% semantic typography baseline, TextScaler-correct measurement rules, scale classification (full / layout-coupled / clamped display), and Small / Medium / Large text-size modes applied through root MediaQuery.

### Modified Capabilities

- `common-settings-persist`: Persist `textSize` (`small` | `medium` | `large`, default `medium`) alongside language / unit / country.
- `settings-ui`: Common Settings exposes Text Size (Small / Medium / Large) and applies it immediately via the shared store + MediaQuery path.

## Impact

- App theme: `app_typography.dart`, `hmi_typography.dart`, `hmi_display_typography.dart`, `hmi_tab_metrics.dart`, `hmi_button_metrics.dart` (Hero 24).
- App shell: `app.dart` MediaQuery / `_matchFlutterPiDensity`; `CommonSettingsStore` + Common Settings tab / page.
- Measurement / chrome: `word_boundary_label.dart`, `product_top_tabs.dart`, status bar, Home Quick Action fit path, tip/dialog call sites listed in the plan.
- Tests: typography tokens, store default/migration, WordBoundary + tab width under Large scaler, settings UI.
- Docs: plan already in `docs/`; implementation notes stay in this change.
- No rootfs / OEM / HAL package changes for the first ship of text size (App-owned JSON only).
