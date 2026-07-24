## ADDED Requirements

### Requirement: Monitor chrome and labels use App localization

Monitor shell title, tab labels, and migrated operator-visible row/tile labels SHALL use `AppLocalizations` for the active UI locale. Alarm Information list labels for catalogued codes SHALL follow the same localization resolution as warn presentation (`cyber-alarm` / App catalog keys).

#### Scenario: Monitor title follows locale

- **WHEN** Language is `zh-CN` and the operator opens Monitor
- **THEN** the Monitor page status-bar title and migrated tab labels render in Simplified Chinese

#### Scenario: Machine Status labels follow locale

- **WHEN** Language is `zh-CN` and the operator opens Machine Status
- **THEN** migrated gauge and run-tile labels render in Simplified Chinese via App localization
