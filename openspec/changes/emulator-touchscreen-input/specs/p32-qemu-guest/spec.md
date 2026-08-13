## REMOVED Requirements

### Requirement: Absolute pointer and playback audio

**Reason:** Emulator primary input SHALL match product touch panel semantics (and Android Emulator host-mouse-as-touch), not absolute mouse/tablet pointer. Playback-audio portion moves to the replacement requirement below.

**Migration:** Operators who need legacy pointer debugging SHALL set `EMULATOR_INPUT=tablet` when starting the emulator (documented in `docs/p32-emulator.md`).

## ADDED Requirements

### Requirement: Touchscreen input and playback audio

The emulator SHALL present a **virtio multitouch** input device (or equivalent) bound to the primary virtio-gpu display so host mouse actions in the QEMU window produce guest **touch** events (single-contact down/move/up) without requiring mouse grab. It SHALL present virtio sound suitable for host playback (capture MAY be omitted when the host backend is unreliable). When no USB pointer HID is attached, the guest compositor/HMI SHALL NOT show a persistent software cursor (touch-only UX aligned with ynh960 panel).

#### Scenario: Host mouse maps to touch

- **WHEN** the operator presses, moves, or releases the host mouse button over the active QEMU display while `EMULATOR_INPUT` is unset or `touch`
- **THEN** the guest SHALL deliver touch contact lifecycle events to libinput (not sole reliance on a virtio-tablet pointer device)
- **AND** the operator SHALL NOT need a mouse-grab release chord to move the host cursor outside the window

#### Scenario: Touch device visible in guest

- **WHEN** the emulator guest has booted with default launcher input settings
- **THEN** `libinput list-devices` (or equivalent) SHALL report at least one device classified as touch on the primary seat
- **AND** the HMI SHALL respond to tap and drag gestures on interactive controls

#### Scenario: Optional tablet pointer mode

- **WHEN** the operator starts the emulator with `EMULATOR_INPUT=tablet`
- **THEN** the launcher SHALL attach `virtio-tablet-pci` (or equivalent absolute pointer) instead of default multitouch
- **AND** pointer-style debugging SHALL remain available without changing the device rootfs

#### Scenario: Playback audio unchanged

- **WHEN** the emulator starts with the documented default audio configuration
- **THEN** guest audio playback SHALL still use virtio-sound with a host audiodev backend as today
