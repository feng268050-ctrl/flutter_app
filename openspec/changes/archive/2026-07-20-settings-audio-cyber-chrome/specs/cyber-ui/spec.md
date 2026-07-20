## ADDED Requirements

### Requirement: Click backend honors App-persisted effect index

CyberUI SHALL keep `CyberClickSound` / `CyberClickSoundRegistry` as a fire-and-forget `playClick()` API (no index parameter on the registry). The product App’s registered backend SHALL select among multiple bundled click samples using the App-persisted sound-effect index. CyberUI MUST NOT hard-depend on `cyber_hal` or prefs files for click playback.

#### Scenario: Registry API stays index-free

- **WHEN** a Cyber control calls `CyberClickSoundRegistry.playClick()`
- **THEN** the call does not pass an effect index; sample selection is entirely inside the registered App backend
