## 1. HmiTypography semantic roles (P0)

- [x] 1.1 Add `upgradeDescription` (`AppTypography.sectionTitle`, 22 at 100%) and `settingsHelpFooter` (`AppTypography.control`, 20 at 100%) to `HmiTypography` including `copyWith` / lerp
- [x] 1.2 Add unit tests asserting `upgradeDescription.fontSize == 22` and `settingsHelpFooter.fontSize == 20` at Medium 100%

## 2. SettingsHelpFooter migration (P0)

- [x] 2.1 Change `SettingsHelpFooter` default to `context.hmiTypography.settingsHelpFooter.copyWith(color: Colors.white54, height: 1.35)`
- [x] 2.2 Remove `SettingsDimens.helpTextSize` and `SettingsDimens.helpTextStyle`; migrate any callers to the semantic role
- [x] 2.3 Remove Keyboard settings custom 18px footnote override (use default footer role)

## 3. Upgrade pages — upgradeDescription (P0)

- [x] 3.1 Migrate `hmi_upgrade_page.dart` check status / completion tip / in-progress copy to `upgradeDescription`
- [x] 3.2 Migrate `system_upgrade_page.dart` the same way
- [x] 3.3 Migrate `control_board_upgrade_page.dart` the same way
- [x] 3.4 Migrate `camera_program_upgrade_page.dart` the same way
- [x] 3.5 Remove redundant `settingsRowTitle.copyWith(fontSize: 20/22)` on upgrade pages where role already matches

## 4. cyber_upgrade_ui alignment (P0)

- [x] 4.1 Update `UpgradeCheckCard` / `UpgradeCompletionTip` default fallback from 16 to 22 (or document injection-only) without importing App theme
- [x] 4.2 Update package widget tests for new default / injected style contract

## 5. Verification (P0)

- [x] 5.1 Grep `lib/features/**` for `helpTextSize`, `helpTextStyle`, `copyWith(\n*fontSize: 22` on upgrade/settings paths; fix stragglers
- [x] 5.2 Run `flutter test` for typography + affected upgrade/settings tests; `flutter analyze` on touched files
- [x] 5.3 Emulator spot-check: Settings footnote (Language/Keyboard) at 20; System/HMI upgrade idle copy at 22; Large text size scales both

## 6. Module constant dedup (P1)

- [x] 6.1 Replace StatusBar / Home label size duplicates with `AppTypography.*Size` or semantic roles
- [x] 6.2 Replace Process/Quick Mode wheel and dashboard unit duplicates (`22/20/16/24/44`) with ladder references or `HmiTypography` roles
- [x] 6.3 Replace Monitor tab / metric local sizes that mirror the ladder
- [x] 6.4 Stop importing `AppTypography` directly in ordinary feature widgets where a semantic role exists

## 7. Specialty tokens & CI (P2)

- [x] 7.1 Register remaining special sizes (CNC guide title 38, process toast 41, numeric input, etc.) as named `HmiTypography` or `HmiDisplayTypography` roles — partial: `cncGuideTitleSize` + ladder aliases; toast/numeric already on `HmiTypography`
- [x] 7.2 Extend `scripts/flutter/check_no_bare_font_size.sh` / `make check-typography` to flag `copyWith(fontSize:` in `lib/features/**` and product `lib/ui/**` (whitelist theme + approved painters)
- [x] 7.3 Document allowed bare-fontSize paths in audit plan or AGENTS.md rebuild table if lint scope changes — audit plan §5.2 footer baseline updated to 20
