## ADDED Requirements

### Requirement: eth0 DHCP/static helpers in rootfs overlay

The lws_hmi rootfs SHALL include eth0-scoped helper scripts for DHCP and static IPv4 (e.g. `eth0-dhcp.sh`, `eth0-static.sh` under `/usr/lib/lws-hmi/`) usable from the HMI after boot. Eth0 DHCP MUST remain outside `dhcpcd.service` / `network.service` default boot enablement. Static IPv4 on eth0 SHALL use `iproute2` via those helpers (no requirement to enable systemd-networkd).

#### Scenario: eth0 helpers present

- **WHEN** P2.1 rootfs is deployed to device after this change
- **THEN** documented eth0 DHCP and static helper scripts exist and are executable under `/usr/lib/lws-hmi/`

#### Scenario: Boot does not enable dhcpcd for eth0

- **WHEN** the device boots to multi-user without App-triggered eth0 config
- **THEN** `dhcpcd.service` and `network.service` remain not in `multi-user.target.wants`

## MODIFIED Requirements

### Requirement: Minimal wlan0 DHCP client for Wi-Fi client networking

The lws_hmi rootfs SHALL include a lightweight DHCP client usable for **wlan0** after wpa_supplicant association (e.g. `dhcpcd` or BusyBox `udhcpc`). The same client binary MAY also be invoked by **eth0-scoped App helpers** after operator or Demo action. Neither wlan0 nor eth0 addressing MUST require enabling `dhcpcd.service` or `network.service` at boot. Static IPv4 on wlan0 or eth0 SHALL use existing `iproute2` tooling via per-iface helpers (no requirement to enable systemd-networkd). Eth0 IPC camera segment scripting remains a separate P5.1 concern and MUST NOT be required for this DHCP client package to exist.

#### Scenario: DHCP client binary present

- **WHEN** P2.1 rootfs is deployed to device
- **THEN** a documented DHCP client binary for wlan0 (dhcpcd or udhcpc) exists and is executable

#### Scenario: Boot does not require network.service

- **WHEN** the device boots to multi-user
- **THEN** `network.service` remains not in `multi-user.target.wants` (Wi-Fi and Ethernet IP config are App/helper-triggered)
