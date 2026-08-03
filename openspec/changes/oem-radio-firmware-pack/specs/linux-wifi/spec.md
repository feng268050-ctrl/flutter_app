## ADDED Requirements

### Requirement: Wi-Fi modem bring-up loads firmware from OEM radio pack

On boards that use an OEM `helpers.wifi_modem` (or equivalent) for combo Wi‑Fi/BT, the bring-up path SHALL treat the board OEM `radio/firmware/` directory as the authoritative source of module firmware blobs, ensuring driver search paths can resolve the required AIC (or board-specific) files. Bring-up MUST NOT depend on a rootfs multi-vendor firmware kitchen sink. Missing OEM radio firmware MUST soft-fail without crashing the HMI process.

#### Scenario: ynh960 bringup finds fmacfw under OEM

- **WHEN** `/oem` is mounted with the ynh960 radio pack and Wi‑Fi modem bring-up runs
- **THEN** the helper MUST successfully resolve `fmacfw_8800d80_u02.bin` via the OEM radio pack (directly or via symlink/bind into the driver firmware path)

#### Scenario: Missing OEM radio does not crash HMI

- **WHEN** OEM radio firmware is absent and modem bring-up is invoked
- **THEN** bring-up MUST fail soft (log / non-zero) and the HMI App process MUST remain running
