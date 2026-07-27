## ADDED Requirements

### Requirement: Host SDK workflow includes trim before overlay

The host build documentation and Make help SHALL describe the owned-SDK workflow: extract vendor volumes into `linux-sdk/`, optionally or by default after extract run `trim-linux-sdk`, then `apply-overlay`, then kernel/rootfs builds. On macOS Docker volume builds, documentation SHALL require volume init or sync after trim so deleted vendor trees are not retained in the volume.

#### Scenario: make help lists trim and check

- **WHEN** a developer runs `make help`
- **THEN** help text includes `trim-linux-sdk` and `check-linux-sdk` (or equivalent names)

#### Scenario: README documents trim after extract

- **WHEN** a developer follows first-time Linux SDK setup in README
- **THEN** the documented sequence includes trimming (or `TRIM=1` extract) before relying on daily `apply-overlay` / build targets

### Requirement: apply-overlay keeps third-party packages on overlay path

`make apply-overlay` MUST continue to sync custom and third-party Buildroot packages from `overlay/buildroot/package/` (and related third-party pins) into the SDK. Platform kernel/device steps MAY no-op when the owned-tree marker is present, but package overlay injection MUST NOT be removed or relocated into the committed monorepo as part of W3.

#### Scenario: flutter package sync still runs

- **WHEN** `make apply-overlay` runs on an owned (trimmed) tree
- **THEN** overlay Flutter / libserialport / bluez-alsa / font package recipes are still copied into the SDK Buildroot package directories
