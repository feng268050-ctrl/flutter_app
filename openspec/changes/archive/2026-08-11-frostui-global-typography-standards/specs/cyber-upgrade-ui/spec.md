## ADDED Requirements

### Requirement: Check card and completion tip accept App typography without hardcoded 16px body

`UpgradeCheckCard`, `UpgradeCompletionTip`, and related shared widgets in `packages/cyber_upgrade_ui` SHALL NOT assume a fixed **16** logical pixel body size for product-facing explanatory copy when the App supplies a `statusStyle` / `style` override. When the App omits an override, package defaults MUST NOT contradict the product baseline of **22** for upgrade description-class copy (documented as App-owned; package may use 22 as fallback or require explicit injection). The package MUST remain free of `HmiTypography` imports.

#### Scenario: App injects upgrade description style

- **WHEN** lws_hmi builds an `UpgradeCheckCard` for System Upgrade
- **THEN** it passes a `statusStyle` derived from `context.hmiTypography.upgradeDescription`
- **AND** the rendered status body matches 22 at Medium 100%

#### Scenario: Completion tip style injection

- **WHEN** lws_hmi wraps `UpgradeCompletionTip` on an upgrade page
- **THEN** it passes a `style` derived from `upgradeDescription`
- **AND** the package does not force 16px when an override is provided

#### Scenario: Package stays theme-agnostic

- **WHEN** `cyber_upgrade_ui` is analyzed for dependencies
- **THEN** it does not import `lws_hmi` theme or `HmiTypography`
- **AND** typography baselines are supplied by the App via constructor parameters
