# host-remote-ssh Specification

## Purpose

Host registry (`make connect` / `disconnect`) and unbound TCP SSH transport for registered remote IP boards alongside USB-SSH.

## Requirements

### Requirement: make connect registers a remote SSH device

The repository SHALL provide **`make connect`** that registers a reachable remote SSH board by IP. The IP SHALL be accepted as a Make goal argument (`make connect <ip>`) or via **`IP=`**. On success the host SHALL persist the registration and verify SSH login using the same credentials as USB-SSH (`root` / password via `sshpass`, overridable by existing USB-SSH env vars). The command SHALL fetch the board serial when possible and store it with the IP.

#### Scenario: Connect by positional IP

- **WHEN** the board accepts SSH at `192.168.1.50` and the host runs `make connect 192.168.1.50`
- **THEN** the IP is stored in the host SSH device registry and the command reports success including the board serial when available

#### Scenario: Connect unreachable IP fails

- **WHEN** the host runs `make connect` for an IP that does not accept SSH with the configured credentials
- **THEN** the command fails without adding the IP to the registry

### Requirement: make disconnect removes a registered SSH device

The repository SHALL provide **`make disconnect`** that removes a registered IP from the host SSH device registry. The IP SHALL be accepted as a Make goal argument or via **`IP=`**. Disconnect SHALL NOT require the board to be online.

#### Scenario: Disconnect registered IP

- **WHEN** `192.168.1.50` is registered and the host runs `make disconnect 192.168.1.50`
- **THEN** subsequent `make devices` no longer lists that IP as `MODE=SSH`

### Requirement: make devices lists registered SSH devices

**`make devices`** SHALL include registry rows with **`MODE=SSH`**, **`IP`** set to the registered IP, **`IFACE`** as `-`, and **`SN`** / **`ChipID`** from the cached or live-probed board identity when known.

#### Scenario: Registered device appears

- **WHEN** at least one IP is registered via `make connect`
- **THEN** `make devices` shows a row with `MODE` SSH and `IP` equal to that address

### Requirement: Restarting a board removes its SSH registration

Host commands that intentionally restart a Linux board SHALL remove the matching persistent `MODE=SSH` registration so `make devices` does not retain a board whose session-only SSH service stops at reboot. This applies to full-system `make upgrade` and `make reboot`; when `make reboot-loader` selects a USB-SSH board, it SHALL remove a registered SSH row with the same cached board serial when available. Ephemeral USB-SSH discovery rows require no registry mutation.

#### Scenario: Reboot unregisters a remote SSH board

- **WHEN** a registered `MODE=SSH` board is selected and the user runs `make reboot`
- **THEN** the reboot is triggered and subsequent `make devices` does not list its former registered SSH row

#### Scenario: Full-system upgrade unregisters the board

- **WHEN** a registered board starts rebooting after full-system `make upgrade`
- **THEN** its persistent SSH registry row is removed without waiting for SSH to return

### Requirement: IP selects SSH mode only

When **`IP=`** is set, host SSH interactive commands (`push-app`, `debug-app`, `shell`, `logs`, `reboot`) SHALL select the registered **`MODE=SSH`** device whose address matches and SHALL NOT select a **`USB-SSH`** row even if that row is present.

#### Scenario: IP ignores USB-SSH

- **WHEN** one USB-SSH gadget and one registered SSH device are present and the user runs `IP=<ssh-ip> make shell`
- **THEN** the shell opens on the registered SSH IP, not the USB-SSH gadget

### Requirement: SSH transport uses unbound TCP

For **`MODE=SSH`** targets, host scripts SHALL open `ssh`/`scp` to the registered IP without USB ECM **`BindInterface`** / **`BindAddress`** binding.

#### Scenario: Push over LAN IP

- **WHEN** a registered SSH device is selected and `make push-app` runs
- **THEN** artifacts are copied to that IP over normal SSH and `hmi.service` is restarted as for USB-SSH
