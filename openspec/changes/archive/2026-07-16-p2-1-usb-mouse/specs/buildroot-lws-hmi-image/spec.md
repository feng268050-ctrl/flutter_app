## ADDED Requirements

### Requirement: flutter-pi cursor and mouse pref support in image

The Buildroot/lws-hmi image SHALL ship a flutter-pi build that: (1) shows a reliable on-screen mouse pointer when a USB mouse is attached on ynh960; and (2) applies mouse preferences from `/var/lib/hmi/` (natural scroll, scroll speed, pointer speed, primary button) at process start and when pointer devices are added. Any package patches required for cursor fallback or pref apply MUST be present under the repository flutter-pi package overlay and baked into the prebuilt used by rootfs.

#### Scenario: Prebuilt includes mouse/cursor patches

- **WHEN** `make check-prebuilt` / rootfs packaging runs after this change
- **THEN** the shipped flutter-pi binary includes the cursor visibility and mouse preference apply support required by `linux-usb-hid-mouse` and `linux-mouse-settings`

#### Scenario: verify-rootfs accepts mouse pref path

- **WHEN** `scripts/verify-rootfs-overlay.sh` runs against an overlay that documents or stages mouse preference defaults
- **THEN** verification passes (or explicitly skips non-staged optional default files without failing the image)
