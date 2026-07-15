## ADDED Requirements

### Requirement: Overlay includes settings isolation units

The lws_hmi rootfs overlay SHALL include `lws-hmi-wpa.service`, `lws-hmi-wlan0-dhcp.service`, `lws-hmi-eth0.service`, `lws-hmi-settings-restore.service`, `lws-hmi-wpa-run.sh`, and `lws-hmi-settings-restore.sh`. `verify-rootfs-overlay` SHALL fail if `wifi-stack-up.sh` still starts `wpa_supplicant -B` directly instead of the dedicated unit.

#### Scenario: verify catches in-cgroup wpa

- **WHEN** `verify-rootfs-overlay.sh` runs against a staging target whose `wifi-stack-up.sh` still embeds `wpa_supplicant -B`
- **THEN** verification fails
