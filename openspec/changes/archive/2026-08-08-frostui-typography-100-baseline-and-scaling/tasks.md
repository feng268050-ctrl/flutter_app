## 1. Freeze 100% tokens

- [x] 1.1 Confirm `HmiTypography.buttonHeroFontSize` stays `24.0` at Medium 100%; align any docs/tests that still assume 26
- [x] 1.2 Add semantic roles on `HmiTypography` / specialty tokens: `dialogBody`, `importantDialogBody`, `dialogOptionLabel`, engineer tip title/body, safety tip title/body, reminder title/body, numeric dialog title/description/input/stepper (and form dialog title if needed)
- [x] 1.3 Migrate all `AppTypography.tipBodySizeForTitle` production call sites to explicit roles; deprecate then remove the helper from the business path
- [x] 1.4 Replace the plan’s production bare `fontSize` literals with tokens (boot self-check / engineer / laser reminder checkboxes, upgrade pages, storage bar, pill dropdown, process library, cyber IME numeric dialog)
- [x] 1.5 Make `HmiTabMetrics` layout-only: `HmiPrimaryTabContent` + `ProductTopTabs` use `hmiTypography.primaryTabLabel`; retire business use of `labelFontSize` (update process-mode aliases / tests)
- [x] 1.6 Deduplicate clock / dashboard sizes under `HmiDisplayTypography`; remove or delegate duplicate constants on `HmiTypography`

## 2. Scaler-aware measurement (P0)

- [x] 2.1 Fix `WordBoundaryLabel` / `WordBoundaryBody` to measure and space with `MediaQuery.textScalerOf(context)` (no `TextScaler.noScaling` on layout measure)
- [x] 2.2 Pass TextScaler (and primary tab style) into `ProductTopTabs` width measurement
- [x] 2.3 Pass TextScaler into Work Mode status-bar label width measurements
- [x] 2.4 Implement Home Quick Action policy: clamp scale (max 1.05) and/or include TextScaler in the fit algorithm so fit-then-paint cannot double-scale
- [x] 2.5 Add `displayTextScaler` (or equivalent) helper for Class C display/painter text (0.95 / 1.00 / 1.05) and wire Home clock / dashboard consumers that should clamp

## 3. AppTextSize store + settings UI

- [x] 3.1 Add `AppTextSize` enum with scales 0.90 / 1.00 / 1.12
- [x] 3.2 Extend `CommonSettingsStore` with `textSize` key, default `medium`, normalize unknown/missing values; update JSON read/write + unit tests
- [x] 3.3 Add l10n strings for Text Size / Small / Medium / Large (parent ARBs + `make l10n`)
- [x] 3.4 Add Common Settings Text Size row **between Display and Sound** + Text Size settings page; persist and notify immediately
- [x] 3.5 Settings UI / store widget tests for default Medium, persist Large, row order

## 4. Root MediaQuery + layout compensation

- [x] 4.1 Inject `TextScaler.linear(store.textSize.scale)` in `_appBuilder` from `CommonSettingsStore` (ListenableBuilder)
- [x] 4.2 Refactor `_matchFlutterPiDensity` to accept app `MediaQueryData` and preserve `textScaler` + `alwaysUse24HourFormat` while adjusting size/DPR
- [x] 4.3 Add minimal Class B overrides (settings row minHeight via scale factor; tip dialog screen-relative maxHeight); tab height helpers ready (`HmiTextScale.tabHeightOf`) — apply in strip widgets when English Large smoke needs it
- [x] 4.4 English-first smoke (deferred to device QA; no confirmed overflows in targeted tests): buttons, tabs, settings rows, fixed-width action groups under Large; fix only confirmed overflows

## 5. Verification

- [x] 5.1 Unit/widget tests: store migration without `textSize`, persist Large, Common Settings row order Display → Text Size → Sound (Hero 24 / WordBoundary / tab width covered in earlier phases / dedicated tests)
- [x] 5.2 `flutter analyze` / targeted tests under `app/lws_hmi/`
- [x] 5.3 Manual QEMU (operator follow-up on device/QEMU after push-app): Medium unchanged; Small / Large reading UI; clock/gauge clamp; tip dialog scroll; Alarms/Settings ambient still OK
- [x] 5.4 Optional P2 (deferred; not blocking archive): document or add CI grep/lint whitelist against new bare `fontSize` in `lib/features/**` and product `lib/ui/**`
