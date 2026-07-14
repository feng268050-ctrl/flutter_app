## ADDED Requirements

### Requirement: Deferred Wi-Fi and Bluetooth units may start on demand

Plan A SHALL continue to leave `wifibt-init.service`, `wpa_supplicant.service`, `network.service`, and `bluetooth.service` out of `multi-user.target.wants` at image build. The image MAY provide HMI-facing helpers that `systemctl start` those units **after boot** when the application enables Wi-Fi or Bluetooth. `hmi.service` MUST continue to depend only on local-fs / performance — not on `network-online.target` or Wi-Fi/BT readiness.

#### Scenario: Boot still defers wifibt and bluetooth

- **WHEN** the device reaches multi-user target without user/App radio enable
- **THEN** `wifibt-init.service`, `wpa_supplicant.service`, `network.service`, and `bluetooth.service` are not required to be active, and those units remain absent from multi-user wants

#### Scenario: On-demand start does not change hmi dependencies

- **WHEN** an operator or the HMI starts `wpa_supplicant` or `bluetooth` after boot
- **THEN** `hmi.service` unit dependencies still do not include `network-online.target` or those radio units
