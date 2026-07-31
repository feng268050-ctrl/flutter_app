## MODIFIED Requirements

### Requirement: Flutter IDE exposes lws-hmi as a custom debug device

The repository SHALL provide an idempotent setup/doctor path for the pinned Flutter SDK's Custom Devices feature and SHALL define a stable lws-hmi device whose commands delegate to repository USB-SSH adapters.

The repository SHALL include VS Code / Cursor Flutter launch configuration that can be selected in Run & Debug and starts the application on that custom device through the Flutter extension.

Implementation SHALL validate the P5.1-pinned Flutter **3.41.x** SDK/engine/eLinux triplet (`flutter-engine-p51`) with `hmi-bundle (flutter assemble)` / `make debug-app`. A failure of the debugger or DevTools workflow on that pin MUST be treated as a defect in this stack (or a follow-up fix), not as a reason to remain on Flutter 3.24.4.

#### Scenario: First-time IDE setup

- **WHEN** a developer completes the documented setup with the pinned Flutter SDK
- **THEN** Flutter device discovery and the VS Code / Cursor Flutter extension show the lws-hmi custom device

#### Scenario: Start from Run and Debug

- **WHEN** the developer selects the checked-in lws-hmi Flutter launch configuration and starts debugging
- **THEN** the Flutter extension builds, installs, and launches the app on the selected physical board and binds source breakpoints

#### Scenario: Custom device configuration drifts

- **WHEN** the user-scoped custom-device definition is missing or differs from the repository definition
- **THEN** the setup/doctor path restores it idempotently or reports the exact corrective action

#### Scenario: P5.1 pin supports IDE debugging

- **WHEN** validation runs against the P5.1 Flutter 3.41.x pin and matching eLinux/engine prebuilts
- **THEN** Custom Device, debugger, and DevTools behavior required by this capability are available without falling back to Flutter 3.24.4
