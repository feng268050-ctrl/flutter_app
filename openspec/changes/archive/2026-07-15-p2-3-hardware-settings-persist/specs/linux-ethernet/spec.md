## ADDED Requirements

### Requirement: Ethernet apply outside HMI cgroup

Long-lived eth0 DHCP (or apply that leaves dhcpcd running) SHALL run under `eth0-network.service` (or an equivalent unit) outside `hmi.service`'s cgroup so `systemctl stop hmi` does not remove eth0 addressing started from Demo.

#### Scenario: HMI restart keeps eth0

- **WHEN** eth0 has been applied with DHCP or static IPv4 and the operator restarts `hmi.service`
- **THEN** eth0 retains its configured IPv4 addressing

### Requirement: Wanted marker for eth0

When eth0 is enabled/applied successfully, the system SHALL create `/var/lib/network/eth0-wanted`. When eth0 is disabled, that file SHALL be removed.

#### Scenario: Apply writes wanted

- **WHEN** the operator enables eth0 and applies IPv4 successfully
- **THEN** `/var/lib/network/eth0-wanted` exists
