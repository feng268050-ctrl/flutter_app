# frostui-status-indicator Specification

## Purpose
TBD - created by archiving change frostui-status-indicator. Update Purpose after archive.
## Requirements
### Requirement: FrostStatusIndicator provides four semantic states

The system SHALL provide `FrostStatusIndicator` (Compose) and `FrostStatusIndicatorView` (XML/Java interop) in `com.lasercyber.lws.frostui.control`. The indicator MUST be read-only (no click/toggle). It MUST expose **`FrostStatusState`** with exactly four values:

- **Idle** — gray soft-edged circular background, no center dot or glyph (neutral / off / not started).
- **InProgress** — gray background with a yellow filled center dot (variant-independent).
- **Success** — green semantic color (presentation depends on variant; see next requirement).
- **Failure** — red semantic color (presentation depends on variant).

The component API MUST accept state via `setState(FrostStatusState)` only. It MUST NOT expose boolean shortcuts such as `setChecked` or `setSuccess`.

#### Scenario: Idle state renders gray background only

- **WHEN** `FrostStatusIndicator` is composed with state `Idle`
- **THEN** the indicator MUST display a gray circular background with softened edge falloff
- **AND** MUST NOT display a colored center dot or check/cross glyph

#### Scenario: InProgress state renders yellow center dot

- **WHEN** `FrostStatusIndicator` is composed with state `InProgress`
- **THEN** the indicator MUST display a yellow filled center dot on the gray background
- **AND** MUST NOT display a check/cross glyph regardless of variant

### Requirement: Success and Failure support Dot and Icon variants

`FrostStatusIndicator` SHALL accept a **`FrostStatusVariant`** of **Dot** or **Icon**. Presentation by state × variant:

| State | Dot | Icon |
|-------|-----|------|
| Idle | gray background | gray background |
| InProgress | gray background + yellow dot | gray background + yellow dot |
| Success | gray background + green dot | green background + white checkmark |
| Failure | gray background + red dot | red background + white cross |

Idle and InProgress MUST ignore variant for glyphs; InProgress always uses a yellow center dot.

#### Scenario: Success Dot variant colors the center dot

- **WHEN** state is `Success` and variant is `Dot`
- **THEN** a green filled center dot MUST be visible
- **AND** the background MUST remain gray with softened edge falloff

#### Scenario: Failure Icon variant colors the background and draws cross

- **WHEN** state is `Failure` and variant is `Icon`
- **THEN** the circular background MUST be red with softened edge falloff
- **AND** a white cross glyph MUST be centered inside

#### Scenario: Success Icon variant colors the background and draws checkmark

- **WHEN** state is `Success` and variant is `Icon`
- **THEN** the circular background MUST be green with softened edge falloff
- **AND** a white checkmark glyph MUST be centered inside

### Requirement: Indicator size matches monitor status footprint

The outer diameter of `FrostStatusIndicator` SHALL equal `frost_status_indicator_size` (aliases `machine_status_indicator_size`, 36dp on monitor layouts). `FrostStatusIndicatorView` MUST default to this size via styleable attributes.

#### Scenario: Monitor tile indicator matches legacy checkbox footprint

- **WHEN** a `FrostStatusIndicatorView` is placed in `MachineStatusStatusTile` or Alarm Information rows
- **THEN** its measured width and height MUST equal the legacy 36dp checkbox indicators it replaces

### Requirement: Background uses edge softening not a flat stroke

The circular indicator SHALL be drawn as a **filled background disc** with perceptible edge softening (radial alpha falloff at the perimeter), consistent with the frosted control aesthetic. It MUST NOT render as a single hard 1px flat stroke without falloff.

#### Scenario: Background shows soft edge on device

- **WHEN** the indicator is rendered on the Android emulator at 36dp
- **THEN** the background MUST show visible edge fade/softening compared to a flat filled circle without falloff

### Requirement: Status indicator tokens live in frostui control resources

Semantic colors and dimensions for status states SHALL reside in `frostui_control_colors.xml` and `frostui_control_dimens.xml`. `frostui.control` code MUST NOT hard-code monitor-specific colors from `com.lasercyber.lws.ui`.

#### Scenario: Control package has no ui color imports for status indicator

- **WHEN** `FrostStatusIndicator.kt` is compiled
- **THEN** it MUST resolve status colors from frostui control resources or `FrostControlColors` helpers
- **AND** MUST NOT import `com.lasercyber.lws.ui.R` for status state colors

### Requirement: XML styleable exposes state and variant

`FrostStatusIndicatorView` SHALL declare frostui styleable attributes for `frostStatusState` and `frostStatusVariant`, readable from XML and settable from Java (`setState`, `setVariant`).

#### Scenario: Layout declares Icon variant for alarm row

- **WHEN** `fragment_warn_info.xml` declares a `FrostStatusIndicatorView` with `app:frostStatusVariant="icon"`
- **THEN** the view MUST render Success/Failure using the Icon presentation (colored background + check/cross)
- **AND** Java binding adapters MUST be able to update state at runtime without recreating the view

### Requirement: Monitor screens bind domain signals to state at the adapter layer

Boolean or enum domain signals MUST be mapped to `FrostStatusState` in binding adapters or mapping helpers (`MachineStatusIndicatorMapping`, `CommStatusBindingAdapter`), not inside `FrostStatusIndicatorView`. Legacy `app:machineStatusChecked` MAY remain as a boolean convenience binding that maps **on → Success**, **off → Idle** for Machine Status tiles. Full four-state consumers MUST use `app:machineStatusIndicatorState` or call `setState` directly.

#### Scenario: Machine Status tile receives on/off binding

- **WHEN** `MachineStatusBindingAdapter` applies `machineStatusChecked=true`
- **THEN** the embedded indicator MUST display `Success` in **Dot** variant
- **WHEN** `machineStatusChecked=false`
- **THEN** the indicator MUST display `Idle` (gray), not `Failure` (red)

