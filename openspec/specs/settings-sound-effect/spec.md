# settings-sound-effect Specification

## Purpose
TBD - created by archiving change settings-audio-cyber-chrome. Update Purpose after archive.
## Requirements
### Requirement: Three click samples and Effect 1/2/3 index

The App SHALL ship three UI click assets corresponding to lws-ui `GlobalSoundManager` order:

| Index | Asset key (App) | lws-ui raw | Settings label |
|------:|-----------------|------------|----------------|
| 0 | `assets/audio/click_effect_1.mp3` (from `click_mp3_2.mp3`) | `click_mp3_2` | Effect 1 |
| 1 | `assets/audio/click_effect_2.mp3` (from `click_mp3.mp3`) | `click_mp3` | Effect 2 |
| 2 | `assets/audio/click_effect_3.mp3` (from `click_mp3_1.mp3`) | `click_mp3_1` | Effect 3 |

The persisted sound-effect index SHALL be an integer in `0..2` (default `0`). The App click backend registered with `CyberClickSoundRegistry` SHALL play the sample for the active index on `playClick()`.

#### Scenario: playClick uses active index

- **WHEN** the active sound-effect index is `2` and a Cyber control with click sound enabled is activated
- **THEN** the Effect 3 sample is played (not Effect 1/2)

### Requirement: Settings Sound Effect selection persists and previews

Settings Sound Effect UI SHALL present Effect 1 / Effect 2 / Effect 3 (segmented or equivalent). Changing the selection SHALL persist the index and preview that sample (lws-ui `GlobalSoundManager.openEffect` behavior). Preference MUST survive process restart.

#### Scenario: Selecting Effect 2 persists

- **WHEN** the user selects Effect 2 and later relaunches the HMI
- **THEN** Effect 2 remains selected and click SFX uses index `1`

#### Scenario: Selecting an effect previews it

- **WHEN** the user changes the Sound Effect control to Effect 3
- **THEN** the Effect 3 sample plays once as preview and the index is persisted

### Requirement: Registry wiring mirrors FrostUiDialogBridge

At App bootstrap the product SHALL register the click backend into `CyberClickSoundRegistry` (same role as lws-ui `FrostUiDialogBridge.register(GlobalSoundManager::playClickSound)`). CyberUI widgets continue to call only `CyberClickSoundRegistry.playClick()` and MUST NOT load assets or read prefs themselves.

#### Scenario: Unregistered backend remains no-op

- **WHEN** no click backend is registered
- **THEN** `playClick()` does not throw

