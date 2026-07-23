# hal-button-feedback Specification

## Purpose
TBD - created by archiving change refactor-cyber-hal-output. Update Purpose after archive.
## Requirements
### Requirement: ButtonFeedback selects asset and plays via audio HAL

The HAL SHALL expose a portable `ButtonFeedback` API under `hal/output/sound` that gets and sets the active **Flutter asset key** (string) used for UI click feedback. `ButtonFeedback.play()` SHALL play that asset through an injected media/audio HAL (`MediaAudioController` or equivalent). Product Apps MUST NOT call the media HAL directly for click playback when `ButtonFeedback` is available; Settings UI MAY present a catalog of assets and call `setAssetKey` / `play` for selection and preview.

#### Scenario: Set asset key is readable

- **WHEN** the client sets ButtonFeedback asset key to `assets/audio/click_effect_2.mp3`
- **THEN** a subsequent get returns that same key

#### Scenario: play uses media HAL

- **WHEN** `play()` is invoked with an active asset key
- **THEN** the injected media audio controller is asked to play that asset as a one-shot (or equivalent short SFX path)

### Requirement: ButtonFeedback preference stores asset key

`ButtonFeedback` SHALL persist the active asset key at `/var/lib/hmi/sound.conf` (key `button_feedback`). Boot `settings-restore.service` is NOT required to apply ButtonFeedback.

#### Scenario: Preference survives relaunch

- **WHEN** the active asset key is set and the HMI process restarts
- **THEN** warm-read / get returns the same asset key from `/var/lib/hmi/sound.conf` (key `button_feedback`)
