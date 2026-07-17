## ADDED Requirements

### Requirement: External mixer volume changes are observable

The Linux media audio implementation SHALL, where the ALSA mixer stack allows, observe hardware/soft volume changes made **outside** the controller (e.g. `amixer sset`) via mixer event notification or equivalent fd subscribe, and expose the updated percent to callers. Periodic `amixer` get on a fixed Timer MUST NOT be the primary observation path. If the board mixer cannot notify, the implementation SHALL document the limitation and still MUST NOT introduce a primary Timer+Process volume poll; Demo remains authoritative after local sets.

#### Scenario: External amixer update when notify is available

- **WHEN** mixer notification is supported and an operator changes the active playback volume control via `amixer`
- **THEN** a subscribed observer can obtain the new percent without moving the Demo volume slider
