## ADDED Requirements

### Requirement: Minimal wlan0 DHCP client for Wi-Fi client networking

The lws_hmi rootfs SHALL include a lightweight DHCP client usable for **wlan0** after wpa_supplicant association (e.g. `dhcpcd` or BusyBox `udhcpc`). Eth0 camera addressing MUST remain outside this client's default boot behavior. Static IPv4 on wlan0 SHALL use existing `iproute2` tooling via helpers (no requirement to enable systemd-networkd).

#### Scenario: DHCP client binary present

- **WHEN** P2.1 rootfs is deployed to device
- **THEN** a documented DHCP client binary for wlan0 (dhcpcd or udhcpc) exists and is executable

#### Scenario: Boot does not require network.service

- **WHEN** the device boots to multi-user
- **THEN** `network.service` remains not in `multi-user.target.wants` (Wi-Fi IP config is App/helper-triggered)

### Requirement: CA certificates for HTTPS

The lws_hmi rootfs SHALL include a system CA certificate bundle (`BR2_PACKAGE_CA_CERTIFICATES` or equivalent) so Dart `HttpClient` (and similar TLS clients) can verify public HTTPS endpoints used by the Demo HTTP probe.

#### Scenario: CA bundle present on rootfs

- **WHEN** P2.1 rootfs is built with the lws_hmi network fragment
- **THEN** `/etc/ssl/certs/ca-certificates.crt` exists and is non-empty
