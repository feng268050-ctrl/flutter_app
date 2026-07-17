## ADDED Requirements

### Requirement: Settings restore unit at multi-user

`settings-restore.service` SHALL be enabled in `multi-user.target.wants`. On-demand Wi‑Fi/eth0 units (`wlan-wpa.service`, `wlan-dhcp.service`, `eth0-network.service`) MUST remain disabled at boot via preset and MUST NOT appear in `multi-user.target.wants` except as started by restore or Demo.

#### Scenario: Preset disables on-demand radio units

- **WHEN** the image is built
- **THEN** preset disables `wlan-wpa.service`, `wlan-dhcp.service`, and `eth0-network.service`

### Requirement: HMI does not own settings cgroup

`hmi.service` MUST continue to start without `network-online.target`. Stopping `hmi.service` MUST NOT be the stop path for settings network units.

#### Scenario: hmi has no network-online dependency

- **WHEN** inspecting `hmi.service`
- **THEN** it does not require `network-online.target`
