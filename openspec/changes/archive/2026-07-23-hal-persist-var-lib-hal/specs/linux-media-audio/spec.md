## MODIFIED Requirements

### Requirement: Persist media volume via change-volume helper

Setting media volume percent on Linux SHALL go through `change-volume` / `change-volume.sh` when present, or the HAL media audio backend, which MUST apply the ALSA mixer path used by boot restore and persist the clamped percent (0–100) in `/var/lib/hal/sound.conf` under key `volume` (not a legacy standalone `media-volume` file).

#### Scenario: Set volume persists

- **WHEN** the operator sets media volume to 55 via Demo or Settings
- **THEN** `/var/lib/hal/sound.conf` (key `volume`) contains `55` and audible level matches approximately that percent when playback runs

#### Scenario: Restore uses same preference path

- **WHEN** `/var/lib/hal/sound.conf` (key `volume`) contains a valid percent and HAL restore runs
- **THEN** volume is re-applied from that path
