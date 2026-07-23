## MODIFIED Requirements

### Requirement: Three click samples and Effect 1/2/3 index

The App SHALL ship three UI click assets corresponding to lws-ui `GlobalSoundManager` order:

| Index | Asset key (App) | lws-ui raw | Settings label |
|------:|-----------------|------------|----------------|
| 0 | `assets/audio/click_effect_1.mp3` (from `click_mp3_2.mp3`) | `click_mp3_2` | Effect 1 |
| 1 | `assets/audio/click_effect_2.mp3` (from `click_mp3.mp3`) | `click_mp3` | Effect 2 |
| 2 | `assets/audio/click_effect_3.mp3` (from `click_mp3_1.mp3`) | `click_mp3_1` | Effect 3 |

Settings presents Effect 1/2/3 as a UI catalog. Selecting an effect SHALL call HAL `ButtonFeedback.setAssetKey` with the corresponding asset key (not persist an integer index in HAL). The App click backend registered with `CyberClickSoundRegistry` SHALL call `ButtonFeedback.play()` on `playClick()`.

#### Scenario: playClick uses active asset

- **WHEN** the active ButtonFeedback asset is Effect 3’s key and a Cyber control with click sound enabled is activated
- **THEN** `ButtonFeedback.play()` plays that asset via the media HAL

### Requirement: Settings Sound Effect selection persists and previews

Settings Sound Effect UI SHALL present Effect 1 / Effect 2 / Effect 3. Changing the selection SHALL set the HAL asset key and preview via `ButtonFeedback.play()`. Preference MUST survive process restart.

#### Scenario: Selecting Effect 2 persists

- **WHEN** the user selects Effect 2 and later relaunches the HMI
- **THEN** Effect 2 remains selected and click SFX plays Effect 2’s asset

#### Scenario: Selecting an effect previews it

- **WHEN** the user changes the Sound Effect control to Effect 3
- **THEN** Effect 3’s sample plays once as preview and the asset key is persisted
