## ADDED Requirements

### Requirement: eth0 addressing never blocks hmi first frame

Plan A SHALL continue to leave `network.service` and `dhcpcd.service` out of `multi-user.target.wants`. HMI-facing eth0 helpers MAY configure eth0 **after boot** when the application enables Ethernet or applies IPv4. `hmi.service` MUST continue to depend only on local-fs / performance — not on `network-online.target`, eth0 carrier, or DHCP completion.

#### Scenario: Boot does not wait for eth0

- **WHEN** the device reaches multi-user target without Ethernet cable or eth0 IPv4
- **THEN** `hmi.service` still starts and first-frame paint is not gated on eth0 link or addressing

#### Scenario: On-demand eth0 config does not change hmi dependencies

- **WHEN** an operator or the HMI runs eth0 DHCP/static helpers after boot
- **THEN** `hmi.service` unit dependencies still do not include `network-online.target` or eth0 readiness
