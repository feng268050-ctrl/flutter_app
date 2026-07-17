## ADDED Requirements

### Requirement: Event-driven Ethernet status via netlink

The Linux `EthernetController` implementation SHALL observe eth0 admin, carrier/operstate, and IPv4 address changes primarily via a **long-lived netlink** (or equivalent kernel event) subscription for `eth0`. Events SHALL update in-memory state and emit on existing `admin` / `link` Streams. Periodic `Process.run` of `ip`/`cat sysfs` on a fixed Timer MUST NOT be the primary status path.

#### Scenario: External link down updates Streams

- **WHEN** eth0 is enabled in the controller sense and an operator runs `ip link set eth0 down` or removes carrier
- **THEN** the `admin` and/or `link` Streams update to reflect down / no-carrier without a Demo tap

#### Scenario: Address assignment updates Streams

- **WHEN** eth0 obtains or loses an IPv4 address (DHCP or static applied outside or inside the HMI)
- **THEN** the `link` Stream includes or clears IPv4 fields accordingly

#### Scenario: Wanted restore without duplicate bring-up race

- **WHEN** `/var/lib/network/eth0-wanted` exists at Demo open and restore has not yet finished applying eth0
- **THEN** the controller MAY show starting/configuring and attach netlink when the iface exists, without requiring the Demo to re-toggle the interface

## MODIFIED Requirements

### Requirement: Abstract Ethernet controller API for Linux eth0

The system SHALL provide a reusable Dart `EthernetController` abstraction that exposes eth0 interface enablement (admin up/down), link/carrier status streams, DHCP vs static IPv4 configuration, and link detail snapshots. Linux SHALL implement the abstraction using eth0-scoped helpers for control **without NetworkManager**, and SHALL drive status streams from netlink (or equivalent) events. Callers MUST depend on the abstract type, not the Linux concrete class.

#### Scenario: Enable brings eth0 administratively up

- **WHEN** the controller is asked to enable the interface while eth0 is administratively down
- **THEN** the Linux implementation sets eth0 up without requiring `network.service` or `dhcpcd.service` in `multi-user.target.wants`

#### Scenario: Status reports carrier and IPv4 when known

- **WHEN** eth0 is up with carrier and an IPv4 address is assigned
- **THEN** link details / status streams include a non-empty IPv4 address when known

#### Scenario: Failures do not crash the process

- **WHEN** DHCP or static configuration fails or carrier is absent
- **THEN** the controller emits a failed / no-carrier / error status and MUST NOT terminate the Flutter process
