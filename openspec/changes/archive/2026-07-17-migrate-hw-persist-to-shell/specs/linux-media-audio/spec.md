## ADDED Requirements

### Requirement: Persist media volume via change-volume helper

Setting media volume percent on Linux SHALL go through `change-volume` / `change-volume.sh`, which MUST apply the ALSA mixer path used by boot restore and persist the clamped percent (0–100) to `/var/lib/lws-hmi/media-volume`. The Linux Flutter media audio backend MUST NOT write that preference file directly.

#### Scenario: Set volume persists

- **WHEN** the operator sets media volume to 55 via Demo or `change-volume`
- **THEN** `/var/lib/lws-hmi/media-volume` contains `55` and audible level matches approximately that percent when playback runs

#### Scenario: Restore uses same helper path

- **WHEN** `media-volume` contains a valid percent and `restore-settings` runs
- **THEN** volume is re-applied consistently with `change-volume` (restore MAY call the helper)
