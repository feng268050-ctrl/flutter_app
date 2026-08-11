## Why

FrostUI already has `AppTypography` → `HmiTypography` → business widgets, but production code still sprinkles bare `fontSize` literals, local `*Size = 22` constants, and `copyWith(fontSize: …)` overrides—especially on upgrade flows and settings help copy. That breaks Single Source of Truth (SoT), makes Small/Medium/Large scaling inconsistent, and forces every page to re-decide numeric sizes. The audit in [`docs/frostui_global_typography_audit_and_cleanup_plan.md`](../../../docs/frostui_global_typography_audit_and_cleanup_plan.md) defines the cleanup; this change codifies it as enforceable product requirements with two confirmed operator-facing sizes: **Upgrade Description = 22**, **Settings Help Footer = 20**.

## What Changes

- Add two independent semantic roles on `HmiTypography`: `upgradeDescription` (22) and `settingsHelpFooter` (20)—same ladder family, different roles so each can evolve without coupling.
- Route all OTA / firmware / HMI upgrade mid-card explanatory copy through `upgradeDescription`; remove `supporting.copyWith(fontSize: 22)`, `SettingsDimens.helpTextSize`, and page-local description constants.
- Route `SettingsHelpFooter` (and equivalent card footnotes) through `settingsHelpFooter`; remove ad-hoc 16/18/22 overrides on that component.
- Clear remaining upgrade-page `fontSize: 20/22` `copyWith` hacks where the visual role is already known (e.g. drop redundant `settingsRowTitle.copyWith(fontSize: 20)`).
- Replace module-local numeric constants that merely duplicate `AppTypography.*Size` with references to `*Size` or semantic `HmiTypography` roles (StatusBar, Process/Quick Mode, Monitor)—P1 scope.
- Document forbidden patterns (bare `fontSize`, business `copyWith(fontSize:)`, duplicate local size constants) and add CI/lint guardrails—P2 scope.
- Preserve Display Typography separation (`HmiDisplayTypography` for gauge/clock/dashboard); no forced mapping of display glyphs to reading roles.

## Capabilities

### New Capabilities

_(none — extends existing typography capability)_

### Modified Capabilities

- `frostui-typography`: Add `upgradeDescription` and `settingsHelpFooter` semantic roles with confirmed 100% baselines (22 / 20); forbid business bare `fontSize` and `copyWith(fontSize:)` for reading UI; classify cleanup priority (P0 upgrade + help footer, P1 module dedup, P2 gauge/lint).
- `settings-ui`: `SettingsHelpFooter` SHALL render card footnotes at the `settingsHelpFooter` role (20 at 100%), not generic `supporting` (16) or page-local overrides.
- `ota-upgrade-ui`: Upgrade check / idle / progress explanatory copy in Settings chrome SHALL use `upgradeDescription` (22 at 100%), not package defaults at 16 or ad-hoc row-value styles.
- `cyber-upgrade-ui`: Shared `UpgradeCheckCard` / completion-tip default text styles SHALL align with app `upgradeDescription` when used from lws_hmi (package may expose role hook or accept injected style; app owns 22 baseline).

## Impact

- Theme: `app/lws_hmi/lib/app/theme/hmi_typography.dart` (+ tests), possibly `app_typography.dart` comments only.
- Settings: `settings_chrome.dart` (`SettingsHelpFooter`, remove `SettingsDimens.helpTextSize` / `helpTextStyle` duplication).
- Upgrade pages: `hmi_upgrade_page.dart`, `system_upgrade_page.dart`, `control_board_upgrade_page.dart`, `camera_program_upgrade_page.dart`.
- Package: `packages/cyber_upgrade_ui` default fallback sizes for check card / completion tip.
- Follow-on (P1/P2): Process/Quick Mode, Monitor, StatusBar, gauge painters; `scripts/flutter/check_no_bare_font_size.sh` / `make check-typography`.
- Docs: audit plan remains reference; this change is the normative OpenSpec delta.
- No rootfs / HAL / Buildroot impact.
