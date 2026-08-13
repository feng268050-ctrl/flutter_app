## REMOVED Requirements

### Requirement: Absolute pointer and playback audio

**Reason:** Emulator primary input SHALL match product touch panel semantics (and Android Emulator host-mouse-as-touch), not absolute mouse/tablet pointer as the sole seat path. Playback-audio portion moves to the replacement requirement below.

**Migration:** Operators who need legacy pointer debugging SHALL set `EMULATOR_INPUT=tablet` when starting the emulator (documented in `docs/p32-emulator.md`). The guest touch bridge then no-ops.

## ADDED Requirements

### Requirement: Touchscreen input and playback audio

The emulator SHALL map host pointer actions in the QEMU window to guest **touch** events (single-contact down/move/up) without requiring mouse grab. On hosts where the display backend only delivers pointer events to absolute devices (e.g. qemu-virgl cocoa), the launcher SHALL attach **`virtio-tablet-pci`** and the guest SHALL run a **uinput bridge** (`emulator-tablet-to-touch` or equivalent) that grabs the tablet and exposes a libinput **touch** device; it MUST NOT rely on `virtio-multitouch-pci` alone on such hosts. Host wheel / trackpad scroll SHALL be delivered as **relative wheel** events to the guest (not as instantaneous touch flicks). It SHALL present virtio sound suitable for host playback (capture MAY be omitted when the host backend is unreliable). When no USB pointer HID is attached, the guest compositor/HMI SHALL NOT show a persistent software cursor (touch-only UX aligned with ynh960 panel). The host display backend SHOULD keep the host cursor visible (`show-cursor=on` or equivalent) while the guest cursor is hidden.

#### Scenario: Host mouse maps to touch

- **WHEN** the operator presses, moves, or releases the host mouse button over the active QEMU display while `EMULATOR_INPUT` is unset or `touch`
- **THEN** the guest SHALL deliver touch contact lifecycle events to libinput via the bridge touch device (tablet pointer MUST be grabbed so it is not the sole seat path)
- **AND** the operator SHALL NOT need a mouse-grab release chord to move the host cursor outside the window

#### Scenario: Touch device visible in guest

- **WHEN** the emulator guest has booted with default launcher input settings
- **THEN** `libinput list-devices` (or equivalent) SHALL report at least one device classified as touch on the primary seat (e.g. LWS Emulator Touch)
- **AND** the HMI SHALL respond to tap and drag gestures on interactive controls

#### Scenario: Host scroll maps to wheel

- **WHEN** the operator scrolls with the host wheel or trackpad over the QEMU display in default touch mode
- **THEN** the guest SHALL receive relative wheel events suitable for smooth UI scrolling
- **AND** scroll direction SHALL follow the host OS preference (no extra guest inversion of already-naturalized host deltas)

#### Scenario: Optional tablet pointer mode

- **WHEN** the operator starts the emulator with `EMULATOR_INPUT=tablet`
- **THEN** the launcher SHALL attach `virtio-tablet-pci` and skip (or no-op) the guest touch bridge
- **AND** pointer-style debugging SHALL remain available without changing the device rootfs image contents beyond cmdline

#### Scenario: Playback audio unchanged

- **WHEN** the emulator starts with the documented default audio configuration
- **THEN** guest audio playback SHALL still use virtio-sound with a host audiodev backend as today
