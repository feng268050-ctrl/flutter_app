# linux-ethernet Specification

## Purpose

Linux eth0 (RJ45) client addressing for the HMI: on-demand link up, DHCP/static IPv4 via helpers, and a reusable Dart `EthernetController` abstraction (no NetworkManager; no boot DHCP service).

## Requirements


### Requirement: Abstract Ethernet controller API for Linux eth0

The system SHALL provide a reusable Dart `EthernetController` abstraction that exposes eth0 interface enablement (admin up/down), link/carrier status streams, DHCP vs static IPv4 configuration, and link detail snapshots. Linux SHALL implement the abstraction using `iproute2` and eth0-scoped helpers without NetworkManager. Callers MUST depend on the abstract type, not the Linux concrete class.

#### Scenario: Enable brings eth0 administratively up

- **WHEN** the controller is asked to enable the interface while eth0 is administratively down
- **THEN** the Linux implementation sets eth0 up without requiring `network.service` or `dhcpcd.service` in `multi-user.target.wants`

#### Scenario: Status reports carrier and IPv4 when known

- **WHEN** eth0 is up with carrier and an IPv4 address is assigned
- **THEN** link details / status streams include a non-empty IPv4 address when known

#### Scenario: Failures do not crash the process

- **WHEN** DHCP or static configuration fails or carrier is absent
- **THEN** the controller emits a failed / no-carrier / error status and MUST NOT terminate the Flutter process

### Requirement: eth0 IPv4 supports DHCP and static modes

The Linux Ethernet path SHALL support selecting **DHCP** or **static** IPv4 configuration for **eth0 only**. Static mode SHALL apply address, prefix length, and optional gateway/DNS without modifying wlan0 or usb0. DHCP mode SHALL invoke an eth0-only DHCP helper. Changing eth0 IPv4 MUST NOT modify wlan0 addressing.

#### Scenario: DHCP client targets eth0 only

- **WHEN** IPv4 mode is DHCP and the interface is enabled
- **THEN** a DHCP client runs for `eth0` and wlan0 addressing is unchanged by that helper

#### Scenario: Static IPv4 applied on eth0

- **WHEN** IPv4 mode is static with a valid address and prefix length
- **THEN** `eth0` carries that address/prefix and wlan0 addressing is unchanged

#### Scenario: IPv4 mode persists

- **WHEN** static or DHCP configuration is saved and the HMI process restarts
- **THEN** `getIpv4Config` returns the last saved mode and static fields

### Requirement: Ethernet helpers refuse non-eth0 interfaces

Overlay helpers used for eth0 DHCP/static (and link if present) SHALL hard-refuse operating on `wlan0` and `usb0` (and MUST target `eth0` only).

#### Scenario: Static helper rejects wrong iface

- **WHEN** an eth0 static helper is invoked in a way that would configure wlan0
- **THEN** the helper exits non-zero without changing wlan0 addresses
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
