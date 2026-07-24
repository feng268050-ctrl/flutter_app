## ADDED Requirements

### Requirement: Boot self-check dialog copy uses App localization

Boot self-check dialog title, item labels, status words (checking / pass / fail), footer controls (“don’t show again”, Close), and related operator-visible strings SHALL use `AppLocalizations` for the active UI locale. EN/ZH values SHALL prefer lws-ui `boot_self_check_*` strings when present.

#### Scenario: Self-check dialog follows locale

- **WHEN** Language is `zh-CN` and boot self-check presents its dialog
- **THEN** the dialog title and migrated item/status/footer strings render in Simplified Chinese
