## MODIFIED Requirements

### Requirement: eth0 DHCP runs in dedicated systemd unit

Long-lived eth0 DHCP SHALL run under **`eth0-network.service`** outside `hmi.service`'s cgroup. Helpers MUST live under **`/usr/libexec/network/`**. State MUST live under **`/var/lib/network/`**.

#### Scenario: eth0 survives hmi stop

- **WHEN** eth0 is configured via Demo and operator stops `hmi.service`
- **THEN** `eth0-network.service` remains active

### Requirement: eth0 wanted marker tracks enable state

When eth0 is enabled successfully, the system SHALL create **`/var/lib/network/eth0-wanted`**. When disabled, that file SHALL be removed.

#### Scenario: eth0-wanted created on enable

- **WHEN** eth0 is enabled successfully from Demo
- **THEN** `/var/lib/network/eth0-wanted` exists
