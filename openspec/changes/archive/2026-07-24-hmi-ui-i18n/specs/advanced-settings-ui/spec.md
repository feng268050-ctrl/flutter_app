## ADDED Requirements

### Requirement: Advanced Settings labels use App localization

Advanced Settings section headers, row titles, and migrated secondary hints SHALL use `AppLocalizations` for the active UI locale. EN/ZH values SHALL prefer lws-ui Advanced Settings string resources when present.

#### Scenario: Advanced Settings sections follow locale

- **WHEN** Language is `zh-CN` and the operator opens the Advanced Settings tab
- **THEN** the five section group titles render in Simplified Chinese via App localization
