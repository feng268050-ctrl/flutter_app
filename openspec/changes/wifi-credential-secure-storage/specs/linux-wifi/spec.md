## MODIFIED Requirements

### Requirement: Wi-Fi credentials persist across HMI restarts

Saved networks SHALL persist in a wpa_supplicant configuration under `/var/lib/wpa_supplicant/` (or an equivalent documented path) with `update_config` enabled so a later radio enable can reconnect without re-entering the PSK. **Operator PSK / passphrase secrets SHALL persist in the encrypted Wi‑Fi credential vault** (see `wifi-credential-secure-storage`), sealed via HAL Secrets (`hal-secrets-kek`), not as plaintext `psk=` / passphrase lines in `wpa_supplicant.conf`. After connect or migration, SaveConfig MUST NOT leave plaintext PSK material in the conf file. Reconnect after reboot SHALL use vault inject into wpa memory (`mem_only_psk` or equivalent).

#### Scenario: Saved network survives app restart

- **WHEN** a network was saved via connect with save enabled and the HMI process restarts with Wi-Fi later enabled
- **THEN** the saved SSID remains present in the persisted configuration

#### Scenario: PSK not plaintext in conf after save

- **WHEN** a PSK-protected network is connected and configuration is saved
- **THEN** `wpa_supplicant.conf` does not contain a plaintext `psk=` or passphrase assignment for that network
- **AND** the encrypted vault contains the secret for that SSID

#### Scenario: Reboot reconnect without re-entry

- **WHEN** a PSK-protected network was saved and the device reboots with Wi-Fi enabled
- **THEN** association can complete using the vault-injected PSK without the operator re-entering the passphrase
