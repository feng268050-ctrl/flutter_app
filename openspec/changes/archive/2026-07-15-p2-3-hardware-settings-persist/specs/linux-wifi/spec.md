## ADDED Requirements

### Requirement: Settings daemons outside HMI cgroup

Long-lived Wi‑Fi and wlan0 DHCP processes SHALL run under dedicated systemd units (`wlan-wpa.service`, `wlan-dhcp.service`) that are not part of `hmi.service`'s cgroup. Enabling Wi‑Fi from the HMI MUST start those units (or equivalent escaped helpers) and MUST NOT leave `wpa_supplicant` started solely as a child of the HMI process tree.

#### Scenario: HMI restart keeps Wi-Fi

- **WHEN** Wi‑Fi is associated with an address and the operator restarts `hmi.service`
- **THEN** `wlan0` remains associated with an IPv4 address and LAN SSH to that address (if enabled) remains usable

### Requirement: Wanted marker for Wi-Fi radio

When Wi‑Fi radio is enabled successfully, the system SHALL create `/var/lib/wpa_supplicant/wifi-wanted`. When radio is disabled, that file SHALL be removed.

#### Scenario: Enable writes wanted

- **WHEN** the operator enables Wi‑Fi radio successfully
- **THEN** `/var/lib/wpa_supplicant/wifi-wanted` exists

#### Scenario: Disable clears wanted

- **WHEN** the operator disables Wi‑Fi radio
- **THEN** `/var/lib/wpa_supplicant/wifi-wanted` is absent and the Wi‑Fi stack is torn down
