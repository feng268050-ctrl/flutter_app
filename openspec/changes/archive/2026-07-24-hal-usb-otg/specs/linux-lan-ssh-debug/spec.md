## MODIFIED Requirements

### Requirement: Status query for LAN SSH debug

The image SHALL provide a status helper (argument or sibling script) that reports whether LAN SSH debug is currently running so the **Settings** UI (and HAL `SshDebug`) can initialize its toggle.

#### Scenario: Status when enabled

- **WHEN** LAN SSH debug is running
- **THEN** the status helper exits successfully and indicates enabled/on

## ADDED Requirements

### Requirement: Dart SshDebug lives under hal/network

On-demand LAN SSH control SHALL be exposed as portable **`SshDebug`** under **`package:cyber_hal/network`** (peer of proxy), not under `hal/debug`.

#### Scenario: Settings uses network SshDebug

- **WHEN** Settings toggles LAN SSH debug
- **THEN** it uses `SshDebug` from the network module
