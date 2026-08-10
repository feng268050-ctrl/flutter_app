## MODIFIED Requirements

### Requirement: Wi-Fi country follows product Country preference

Linux Wi‑Fi client bring-up and runtime configuration SHALL use the product **Region** preference (ISO alpha-2 from `cyber_hal` locale) for wpa_supplicant `country=` (conf upsert + runtime `wpa_cli set country`, optional `iw reg set` when packaged). Image seed configuration and script defaults SHALL use `country=US` (not `CN`) so pre-App bring-up matches the product default. When HAL locale applies a Region change (invoked from the product App General Settings or bootstrap), Wi‑Fi SHALL update the effective country without requiring a full device reboot. Soft-fail is allowed when the radio is down; the HMI MUST NOT crash.

#### Scenario: Image seed is US

- **WHEN** rootfs `wpa_supplicant.conf` and Wi‑Fi bring-up script country defaults are inspected
- **THEN** they specify `country=US`

#### Scenario: Runtime country follows App preference

- **WHEN** HAL locale applies Region `GB` while the Wi‑Fi stack is available
- **THEN** wpa effective country is `GB`
