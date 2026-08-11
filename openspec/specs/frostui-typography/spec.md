# frostui-typography Specification

## Purpose

FrostUI Medium-100% semantic typography baseline, TextScaler-aware measurement, and Small/Medium/Large reading text-size modes with display clamp policy.

## Requirements

### Requirement: Medium 100% is the frozen semantic typography baseline

The App SHALL treat Medium (100%) sizes on `AppTypography` / `HmiTypography` / specialty display tokens as the sole design baseline. Business UI in `lib/features/**` and product `lib/ui/**` (excluding demos) SHALL select semantic text roles or named specialty tokens rather than literal `fontSize` numbers. Dialog / tip body sizes SHALL be explicit roles (for example `dialogBody`, `importantDialogBody`, engineer / safety / reminder bodies) and MUST NOT be derived at runtime by stepping the title size down a ladder. After migration, `AppTypography.tipBodySizeForTitle` MUST NOT be used by production call sites.

#### Scenario: Tip body uses a semantic role

- **WHEN** a product tip or light-prompt dialog renders its body text
- **THEN** the body style comes from an explicit `HmiTypography` (or equivalent) role for that dialog class
- **AND** the body size is not computed via `tipBodySizeForTitle`

#### Scenario: Production UI avoids bare fontSize literals

- **WHEN** a non-demo business widget under `lib/features/**` or product `lib/ui/**` sets text size
- **THEN** it references a theme / typography / registered metrics token
- **AND** it does not introduce a new bare numeric `fontSize` outside the documented Theme / CustomPainter whitelist

### Requirement: Button Hero 100% font size is 24

`HmiTypography.buttonHeroFontSize` (and consumers that alias it) SHALL use **24** logical pixels at Medium 100%.

#### Scenario: Hero token matches baseline

- **WHEN** code or tests read `HmiTypography.buttonHeroFontSize`
- **THEN** the value is `24.0`

### Requirement: Primary tab label size has a single source of truth

Primary top-tab label font size SHALL come from `HmiTypography.primaryTabLabel` (backed by the navigation ladder). `HmiTabMetrics` SHALL own layout geometry (height, icon size, padding, indicator, weights) and MUST NOT be the business source for tab label font size.

#### Scenario: Tab content uses typography role

- **WHEN** `HmiPrimaryTabContent` or `ProductTopTabs` paints a primary tab label
- **THEN** the text style font size matches `context.hmiTypography.primaryTabLabel`
- **AND** layout spacing still uses `HmiTabMetrics` geometry fields

### Requirement: Display sizes use HmiDisplayTypography as SoT

Home clock and dashboard large-value sizes SHALL be defined once in `HmiDisplayTypography`. `HmiTypography` MUST NOT keep a divergent copy of the same numeric constants.

#### Scenario: Clock size is not duplicated

- **WHEN** Home clock or equivalent display chrome reads its design font size
- **THEN** the constant originates from `HmiDisplayTypography.clockSize` (or its TextStyle)
- **AND** no second independent `120` / `68` literal is required inside `HmiTypography` for the same roles

### Requirement: Layout text measurement follows TextScaler

Layout-affecting `TextPainter` measurements for UI that follows user text size SHALL pass `MediaQuery.textScalerOf(context)` (or an explicit equivalent). This includes at least `WordBoundaryLabel` / `WordBoundaryBody` line packing, `ProductTopTabs` tab width measurement, and Work Mode status-bar label width measurement. Components that intentionally ignore user text size MUST document that with an explicit fixed-chrome comment.

#### Scenario: WordBoundary packing uses the page scaler

- **WHEN** `WordBoundaryLabel` packs English words under a non-1.0 `MediaQuery.textScaler`
- **THEN** width measurement and wrap decisions use that scaler
- **AND** the painted `Text` does not receive a second incompatible scale assumption such as `TextScaler.noScaling` during measure

#### Scenario: Tab width accounts for Large text

- **WHEN** text size mode is Large and primary tab labels are measured for width
- **THEN** the measured width uses the same TextScaler as painting
- **AND** the allocated tab width is not based on unscaled Medium-only glyph widths

### Requirement: Text size modes Small Medium Large

The product SHALL support three text size modes with scales **0.90 / 1.00 / 1.12** for reading UI (titles, tabs, body, settings, buttons, dialogs, tips). Display / geometry-bound text (clock, gauges, process wheel, CustomPainter glyphs) SHALL use a documented clamped scale (default **0.95 / 1.00 / 1.05**) or fixed 1.00 where product rules require it. The following safety / operation chrome SHALL remain fixed at Medium 1.00 for all three modes: Quick Mode **Manual Gas**, **Auto Wire Feed**, **Feed**, and **Retract**; Engineer Mode **Manual Gas**, **Feed**, **Retract**, **Reset Defaults**, and **Save Favorite**; and the Product Safety / Product Disclaimer agreement checkbox copy. Home Quick Action label fitting MUST NOT apply a fit-at-100% algorithm and then paint under a larger MediaQuery scaler without compensation (clamp max 1.05 and/or include TextScaler in the fit measure).

#### Scenario: Reading UI follows the selected scale

- **WHEN** the operator selects Large text size
- **THEN** ordinary UI `Text` that uses MediaQuery scaling renders at 1.12× Medium baseline sizes

#### Scenario: Display chrome does not fully track Large

- **WHEN** the operator selects Large text size
- **THEN** Home clock / dashboard display glyphs do not scale by the full 1.12 reading factor
- **AND** they follow the documented display clamp (or fixed) policy

#### Scenario: Frozen operation and safety labels ignore text-size mode

- **WHEN** the operator changes text size between Small, Medium, and Large
- **THEN** the listed Quick Mode and Engineer Mode operation labels remain at the Medium 1.00 size
- **AND** the Product Safety / Product Disclaimer agreement checkbox copy remains at the Medium 1.00 size

#### Scenario: Root MediaQuery preserves textScaler through density matching

- **WHEN** the App applies flutter-pi / simulator density rematching
- **THEN** the effective `MediaQuery.textScaler` for the subtree still matches the operator text size preference
- **AND** density rematch only adjusts size / devicePixelRatio as needed

### Requirement: Minimal layout compensation for text size modes

First-ship layout adaptation SHALL adjust a small set of Medium-based metrics (at least settings row min height, primary tab height, and dialog vertical padding / max height policy) for Small / Large rather than maintaining three complete UI constant tables. Tip and light-prompt dialogs under Large SHALL keep actions visible and allow body scroll instead of universally `FittedBox.scaleDown` undoing the user scale.

#### Scenario: Large tip body can scroll

- **WHEN** text size is Large and a tip dialog body exceeds the available height
- **THEN** the body content is scrollable
- **AND** primary actions remain visible
