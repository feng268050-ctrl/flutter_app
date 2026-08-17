## MODIFIED Requirements

### Requirement: Mouse settings OS abstraction

The HMI app SHALL provide a reusable **`MouseSettingsController`** abstraction (Linux implementation in P2.1; Android MAY plug later) that gets and sets OS-common mouse preferences: **natural scrolling**, **scroll speed**, **pointer speed**, and **primary button** (left vs right / left-handed). On Linux, set operations MUST go through `apply-mouse-settings` / `apply-mouse-settings.sh`, which persists under `/var/lib/hal/mouse.conf` and is applied through the Linux input / eLinux HMI path — not by re-decoding HID events in Dart and not by Dart being the sole writer of `mouse.conf`. Controls whose backend is unavailable on the device MUST NOT silently claim success (disable or report unsupported). When `physical_mouse_enabled=0` in `/var/lib/hal/input.conf`, `isPresent` SHALL return false and `setSettings` SHALL NOT invoke `apply-mouse-settings`.

#### Scenario: Policy off hides mouse

- **WHEN** physical mouse is disabled in input policy
- **THEN** `isPresent` returns false and mouse preference apply is skipped
