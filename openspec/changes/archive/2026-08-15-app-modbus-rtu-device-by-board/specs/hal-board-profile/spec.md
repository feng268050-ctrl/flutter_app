## MODIFIED Requirements

### Requirement: Runtime profile prefers OEM compose export

On Linux HMI startup, the product App SHALL load board profile **only** from `/run/hmi/board_profile.json` (written by oem-compose), then merge App gpio/modbus assets via `withProductConfigs`. A missing or unreadable compose export SHALL fail hard. The App MUST NOT fall back to `/oem/boards/<board_id>/board_profile.json` or any App-bundled `board_profile.json` asset on device. Non-Linux host/desktop MAY construct an in-code stub profile (not shipped as a Flutter asset) for UI work without an OEM partition.

#### Scenario: Compose export is required on Linux

- **WHEN** the HMI starts on Linux and `/run/hmi/board_profile.json` is missing
- **THEN** startup SHALL throw / fail visibly with no App asset board-profile fallback

#### Scenario: No App-bundled board profile asset

- **WHEN** inspecting the shipping `lws_hmi` Flutter assets under `assets/hal/`
- **THEN** `board_profile.json` SHALL NOT be present
