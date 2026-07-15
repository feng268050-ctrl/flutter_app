## ADDED Requirements

### Requirement: Demo exposes LAN SSH debug toggle after HTTP / Proxy

The P2/P2.1 demo home SHALL include a LAN SSH debug section immediately **after** the HTTP / Proxy section. The section SHALL provide a toggle that enables or disables on-demand LAN/WLAN SSH debug via the platform SSH debug controller (backing `enable-ssh-debug.sh` / `disable-ssh-debug.sh`). Toggle I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables LAN SSH debug

- **WHEN** the user turns the LAN SSH debug toggle on after first frame
- **THEN** the SSH debug controller is asked to enable LAN SSH debug

#### Scenario: Toggle disables LAN SSH debug

- **WHEN** the user turns the LAN SSH debug toggle off while it was on
- **THEN** the SSH debug controller is asked to disable LAN SSH debug

#### Scenario: Section order

- **WHEN** the user scrolls the demo home after network sections are ready
- **THEN** the LAN SSH debug section appears after the HTTP / Proxy section
