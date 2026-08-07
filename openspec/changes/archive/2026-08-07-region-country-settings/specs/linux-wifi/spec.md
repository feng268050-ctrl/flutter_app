## ADDED Requirements

### Requirement: Wi-Fi country follows product Country preference

Linux Wi‑Fi client bring-up and runtime configuration SHALL use the product Country preference (ISO alpha-2) for wpa_supplicant `country=` and cfg80211 regulatory domain. Image seed configuration and script defaults SHALL use `country=US` (not `CN`) so pre-App bring-up matches the product default. When the App applies a Country change, Wi‑Fi SHALL update the effective country without requiring a full device reboot. Soft-fail is allowed when the radio is down; the HMI MUST NOT crash.

#### Scenario: Image seed is US

- **WHEN** rootfs `wpa_supplicant.conf` and Wi‑Fi bring-up script country defaults are inspected
- **THEN** they specify `country=US`

#### Scenario: Runtime country follows App preference

- **WHEN** the product App applies Country `DE` while the Wi‑Fi stack is available
- **THEN** wpa / regdomain effective country is `DE`
