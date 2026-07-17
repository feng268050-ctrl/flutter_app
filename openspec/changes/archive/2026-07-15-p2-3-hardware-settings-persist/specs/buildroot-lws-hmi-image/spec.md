## ADDED Requirements

### Requirement: Overlay includes settings isolation units

The lws_hmi rootfs overlay SHALL include `wlan-wpa.service`, `wlan-dhcp.service`, `eth0-network.service`, `settings-restore.service`, `wlan-wpa.service-run.sh`, and `restore-settings.sh`. `verify-rootfs-overlay` SHALL fail if `wifi-stack-up.sh` still starts `wpa_supplicant -B` directly instead of the dedicated unit.

#### Scenario: verify catches in-cgroup wpa

- **WHEN** `verify-rootfs-overlay.sh` runs against a staging target whose `wifi-stack-up.sh` still embeds `wpa_supplicant -B`
- **THEN** verification fails
