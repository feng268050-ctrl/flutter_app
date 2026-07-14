## ADDED Requirements

### Requirement: Minimal ALSA userland for P2.1 speaker smoke

The lws_hmi rootfs SHALL include a minimal ALSA userland sufficient to play a local media file and adjust output volume on ynh960 (ALSA libraries plus mixer/player tooling required by the Linux media-audio backend). This SHALL NOT require enabling the full P5 MediaMTX / RTSP GStreamer product stack solely for speaker smoke.

#### Scenario: ALSA mixer tooling present

- **WHEN** P2.1 rootfs is deployed to device
- **THEN** an ALSA mixer utility usable by the media-audio backend (e.g. `amixer`) is present on the target

#### Scenario: Playback helper present when plugin path needs it

- **WHEN** the chosen Linux media-audio backend relies on an external decoder/player
- **THEN** that binary is present on the target rootfs and invocable by the HMI process
