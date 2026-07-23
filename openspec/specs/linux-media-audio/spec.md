# linux-media-audio Specification

## Purpose

Reusable percent-based media audio controller for flutter-pi: play/stop bundled assets via ALSA, without blocking first frame.

## Requirements

### Requirement: Media audio controller API is percent-based and asset-capable

The HMI SHALL provide a reusable `MediaAudioController` (name may vary; behavior is normative) that can play a Flutter/bundled audio asset, stop playback, and get/set volume as an integer **percent in 0–100** (clamped). The controller SHALL NOT require Android `AudioManager`.

#### Scenario: Volume clamp

- **WHEN** the client sets volume to 150 or −10
- **THEN** the stored/applied volume is clamped to 100 or 0 respectively

#### Scenario: Play then stop

- **WHEN** the client plays a valid asset and later calls stop
- **THEN** audible playback ceases without throwing an unhandled error to the UI isolate

### Requirement: Linux backend drives speaker via ALSA path

On Linux/flutter-pi, the media audio implementation SHALL produce audible output through the board speaker path using ALSA (plugin or ALSA-backed helper process). Volume percent SHALL map to the ALSA mixer and/or player gain so that increasing the percent increases loudness under normal amp configuration.

#### Scenario: Demo track plays on device

- **WHEN** the controller plays `assets/audio/shanghai_tan.mp3` on ynh960 with ALSA stack present
- **THEN** the track is audible on the speaker without crashing the HMI process

#### Scenario: Missing audio device does not crash app

- **WHEN** ALSA device open or playback fails
- **THEN** the app remains running and the controller reports failure without an unhandled UI isolate error

### Requirement: Media open stays off the critical first-frame path

The app SHALL NOT block `runApp` / first frame on successful audio engine or ALSA initialization.

#### Scenario: First frame without audio ready

- **WHEN** the app starts with audio subsystem unavailable
- **THEN** the first home frame still renders and audio controls remain visible for a later retry

### Requirement: Persist media volume via change-volume helper

Setting media volume percent on Linux SHALL go through `change-volume` / `change-volume.sh` when present, or the HAL media audio backend, which MUST apply the ALSA mixer path used by boot restore and persist the clamped percent (0–100) in `/var/lib/hmi/sound.conf` under key `volume` (not a legacy standalone `media-volume` file).

#### Scenario: Set volume persists

- **WHEN** the operator sets media volume to 55 via Demo or Settings
- **THEN** `/var/lib/hmi/sound.conf` (key `volume`) contains `55` and audible level matches approximately that percent when playback runs

#### Scenario: Restore uses same preference path

- **WHEN** `/var/lib/hmi/sound.conf` (key `volume`) contains a valid percent and HAL restore runs
- **THEN** volume is re-applied from that path
