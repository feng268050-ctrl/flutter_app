## MODIFIED Requirements

### Requirement: Debug deployment uses existing repository device selection

Debug host commands SHALL reuse `.env` and the shared device selection contract used by other repository commands, including `FLUTTER_SDK`, `SERIAL`, `IP` (SSH registry only), USB/SSH target credentials, reachability timeout, and transport-appropriate SSH/SCP routing (ECM bind for USB-SSH; unbound TCP for registered SSH).

#### Scenario: Multiple boards without SERIAL

- **WHEN** multiple USB-SSH boards are connected and no serial or IP is configured
- **THEN** the debug command fails with instructions to run `make devices` and set `SERIAL` or `IP`

#### Scenario: SERIAL selects one board

- **WHEN** multiple boards share target address `192.168.55.1` and `SERIAL=<iSerial>` selects one board
- **THEN** all debug upload, launch, stop, and port-forward traffic uses only the ECM interface associated with that board

#### Scenario: IP selects registered SSH board

- **WHEN** a remote SSH device is registered and `IP=<ip> make debug-app` is run
- **THEN** all debug upload, launch, stop, and port-forward traffic targets that IP over unbound SSH

#### Scenario: Configuration loaded from dotenv

- **WHEN** the developer configures the pinned SDK and board serial in the repository `.env`
- **THEN** `make debug-app` and the IDE device adapter use those values without a second IDE-specific copy
