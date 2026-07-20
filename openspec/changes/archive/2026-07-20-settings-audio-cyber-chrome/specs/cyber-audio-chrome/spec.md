## ADDED Requirements

### Requirement: Cyber volume chrome widget

`packages/cyber_ui` SHALL provide a volume / icon-flanked slider widget (Cyber name, e.g. `CyberVolumeSlider` or `CyberIconFlankedSlider`) suitable for Settings media volume. The widget SHALL be presentation-only: progress and change callbacks are supplied by the App; CyberUI MUST NOT call `cyber_hal` volume APIs.

#### Scenario: Volume chrome reports progress changes

- **WHEN** the operator drags the Cyber volume chrome
- **THEN** the App-supplied progress callback receives the new percent in 0–100

### Requirement: Cyber audio player card widget

`packages/cyber_ui` SHALL provide `CyberAudioPlayerCard` aligned with lws-ui `FrostAudioPlayerCard` (transport controls, seek bar, elapsed/duration labels). Playback and seeking MUST be implemented by App callbacks (`MediaAudioController` or equivalent). Seek MAY be disabled when the platform player cannot seek.

#### Scenario: Play/pause invokes App callback

- **WHEN** the user taps play/pause on `CyberAudioPlayerCard`
- **THEN** the App `onPlayPause` callback is invoked

#### Scenario: Seek disabled when unsupported

- **WHEN** the card is built with seek disabled
- **THEN** the seek bar does not commit seek callbacks (or is non-interactive)
