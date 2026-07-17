## MODIFIED Requirements

### Requirement: Wi-Fi stack runs in dedicated systemd units

Long-lived Wi‑Fi and wlan0 DHCP processes SHALL run under dedicated systemd units (`wlan-wpa.service`, `wlan-dhcp.service`) outside `hmi.service`'s cgroup. Helpers MUST live under **`/usr/libexec/wpa/`**.

#### Scenario: Wi-Fi enable starts dedicated units

- **WHEN** user enables Wi‑Fi radio from Demo
- **THEN** `wlan-wpa.service` is active and scripts run from `/usr/libexec/wpa/`

### Requirement: Wi-Fi wanted marker tracks radio enable state

When Wi‑Fi radio is enabled successfully, the system SHALL create **`/var/lib/wpa_supplicant/wifi-wanted`**. When disabled, that file SHALL be removed.

#### Scenario: wifi-wanted created on enable

- **WHEN** Wi‑Fi radio is enabled successfully from Demo
- **THEN** `/var/lib/wpa_supplicant/wifi-wanted` exists

#### Scenario: wifi-wanted removed on disable

- **WHEN** Wi‑Fi radio is disabled from Demo
- **THEN** `/var/lib/wpa_supplicant/wifi-wanted` is absent

### Requirement: Saved networks persist under wpa_supplicant state dir

Saved networks SHALL persist in **`/var/lib/wpa_supplicant/wpa_supplicant.conf`** with `update_config` enabled.

#### Scenario: PSK survives disable and re-enable

- **WHEN** user saves a network, disables Wi‑Fi, then re-enables
- **THEN** reconnect proceeds without re-entering credentials from `/var/lib/wpa_supplicant/wpa_supplicant.conf`
