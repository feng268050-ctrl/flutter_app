## ADDED Requirements

### Requirement: Demo exposes Ethernet management section above Wi-Fi

The P2/P2.1 demo home SHALL include an Ethernet (RJ45 / eth0) management section that uses the abstract `EthernetController`: interface enable toggle; link/carrier status (and IPv4 when known); **DHCP vs static IPv4** controls for eth0. The Ethernet section SHALL appear **above** the Wi-Fi management section. Ethernet I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables interface via controller

- **WHEN** the user turns the Ethernet toggle on after first frame
- **THEN** the Ethernet controller is asked to enable the interface

#### Scenario: Static IPv4 form invokes controller

- **WHEN** the user selects static mode and applies a valid address/prefix
- **THEN** the Ethernet controller is asked to set static IPv4 configuration

#### Scenario: DHCP mode invokes controller

- **WHEN** the user selects DHCP mode and applies
- **THEN** the Ethernet controller is asked to set DHCP IPv4 configuration

#### Scenario: Ethernet appears before Wi-Fi

- **WHEN** the user scrolls the demo home after network sections are ready
- **THEN** the Ethernet management section is laid out above the Wi-Fi management section
