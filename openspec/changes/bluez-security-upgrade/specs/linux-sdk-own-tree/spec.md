## ADDED Requirements

### Requirement: bluez5_utils overlay pin remains always-injected

When `overlay/buildroot/package/bluez5_utils/` (and headers, if present) exists for the BlueZ security pin, `make apply-overlay` MUST sync that recipe into the SDK Buildroot tree on every run, and MUST still apply the existing stock-BlueZ Rockchip-patch stash so product images do not regain the Rockchip Device1 Connect(s) ABI. Platform kernel squash skip MUST NOT skip this BlueZ package sync.

#### Scenario: BlueZ pin syncs on owned tree

- **WHEN** an owned `linux-sdk` tree skips kernel re-apply and a developer runs `make apply-overlay`
- **THEN** the overlay BlueZ recipe (if present) is still installed into `buildroot/package/bluez5_utils/` and the Rockchip-only BlueZ patch remains inactive for product builds
