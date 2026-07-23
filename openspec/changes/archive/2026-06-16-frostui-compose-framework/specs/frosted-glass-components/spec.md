## ADDED Requirements

### Requirement: frostui provides canonical Compose implementation for glass components

The system SHALL implement the visual and interaction contract of `FrostedGlassCard` and `FrostedGlassButton` in `com.lasercyber.lws.frostui.card` as `FrostCard` and `FrostButton` Composables backed by `frostui.border` painters. These Composables MUST be the canonical implementation for new frostui-based UI. Visual tokens MUST be sourced from split `frostui_*` resource files.

#### Scenario: FrostCard matches FrostedGlassCard visual contract

- **WHEN** `FrostCard` is rendered with default styling
- **THEN** it MUST use the shared frosted-glass fill, corner radius, and border tokens
- **AND** child content MUST be clipped within rounded card bounds consistent with the existing dialog panel

#### Scenario: FrostButton matches FrostedGlassButton variants

- **WHEN** `FrostButton` is configured as `default`, `primary`, or `secondary`
- **THEN** emphasis styling MUST match the corresponding `FrostedGlassButton` variant rules in this specification
- **AND** rounded capsule buttons MUST use localized border rendering per the existing localized-border requirement

### Requirement: FrostedGlass View components may delegate to frostui during migration

During migration, existing `FrostedGlassCard` and `FrostedGlassButton` View classes MAY remain as thin wrappers or interop facades over frostui until all call sites migrate to `FrostCardView`/`FrostButtonView` or Compose. When a View wrapper is retained, it MUST NOT duplicate independent drawable logic that diverges from `frostui.border`.

#### Scenario: View wrapper does not fork border painting

- **WHEN** a legacy `FrostedGlassCard` or `FrostedGlassButton` View remains in the codebase during migration
- **THEN** its glass chrome MUST be supplied by frostui framework primitives or interop wrappers
- **AND** standalone duplicate implementations of `FrostedGlassPanelDrawable` logic MUST NOT be introduced alongside frostui.border
