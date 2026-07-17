## ADDED Requirements

### Requirement: Mouse settings OS abstraction

The HMI app SHALL provide a reusable **`MouseSettingsController`** abstraction (Linux implementation in P2.1; Android MAY plug later) that gets and sets OS-common mouse preferences: **natural scrolling**, **scroll speed**, **pointer speed**, and **primary button** (left vs right / left-handed). Implementations MUST persist preferences under `/var/lib/hmi/` and apply them through the Linux input / flutter-pi path — not by re-decoding HID events in Dart. Controls whose backend is unavailable on the device MUST NOT silently claim success (disable or report unsupported).

#### Scenario: Read defaults when no pref file

- **WHEN** no mouse preference file exists under `/var/lib/hmi/`
- **THEN** `getSettings` returns documented defaults (natural scroll off; mid scroll/pointer speed; primary button left)

#### Scenario: Persist and apply natural scroll

- **WHEN** the controller sets natural scrolling on
- **THEN** the preference is written under `/var/lib/hmi/` and subsequent mouse wheel vertical motion is inverted at the platform input layer relative to natural scroll off

#### Scenario: Persist and apply scroll speed

- **WHEN** the operator sets scroll speed from a low to a high value via the controller
- **THEN** the same physical wheel notch produces a larger Flutter scroll delta at the high setting than at the low setting

#### Scenario: Persist and apply pointer speed

- **WHEN** the operator sets pointer speed from low to high via the controller
- **THEN** the same physical mouse movement produces faster on-screen pointer travel at the high setting than at the low setting (within libinput accel capability)

#### Scenario: Primary button swap

- **WHEN** the controller sets primary button to right (left-handed)
- **THEN** the physical right button generates Flutter primary-button semantics (and left generates secondary), until restored to left-primary

#### Scenario: Prefs survive HMI restart

- **WHEN** mouse preferences are saved and `hmi.service` / flutter-pi restarts
- **THEN** the saved preferences are applied again without requiring the operator to re-enter Demo controls
