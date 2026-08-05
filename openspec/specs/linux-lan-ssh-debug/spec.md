# linux-lan-ssh-debug Specification

## Purpose

On-demand LAN/WLAN OpenSSH debug (`ssh-debug-lan.service`), default off, coexisting with USB plug-ssh.

## Requirements
### Requirement: On-demand LAN SSH debug scripts

The image SHALL provide `/usr/libexec/ssh/enable-ssh-debug.sh` and `/usr/libexec/ssh/disable-ssh-debug.sh` that start and stop **`ssh-debug-lan.service`** (on-demand LAN/WLAN OpenSSH). The unit MUST NOT be linked in `multi-user.target.wants` and scripts MUST NOT `systemctl enable` it. After a board reboot with no further action, port 22 MUST NOT be listening for LAN/WLAN solely due to a prior enable. LAN sshd MUST run **outside** `hmi.service`'s cgroup so `systemctl stop hmi` during `make push-app` does not terminate the SSH session.

#### Scenario: Enable then SSH over eth0 or wlan0

- **WHEN** eth0 or wlan0 has an address and an operator runs `enable-ssh-debug.sh`
- **THEN** SSH login as `root` to that address succeeds with the configured password

#### Scenario: Disable stops LAN listener

- **WHEN** LAN SSH debug was enabled and the operator runs `disable-ssh-debug.sh`
- **THEN** `ssh-debug-lan.service` is stopped and eth0/wlan0 no longer accept SSH solely from that debug path

#### Scenario: Not enabled at boot

- **WHEN** the board reaches multi-user after a cold boot without enabling LAN SSH debug
- **THEN** `sshd.service` / `sshd.socket` / `ssh-debug-lan.service` are not in `multi-user.target.wants` and LAN SSH debug is off

#### Scenario: push-app does not kill LAN SSH

- **WHEN** LAN SSH debug was enabled from the Demo toggle over Wi-Fi and the host runs `make push-app` over that IP
- **THEN** `wpa_supplicant` / wlan0 DHCP remain outside `hmi.service`'s cgroup so Wi-Fi stays up, LAN sshd remains available, and host `push-app` can complete (apply may still detach from the SSH channel for robustness)

### Requirement: Status query for LAN SSH debug

The image SHALL provide a status helper (argument or sibling script) that reports whether LAN SSH debug is currently running so the **Settings** UI (and HAL `SshDebug`) can initialize its toggle.

#### Scenario: Status when enabled

- **WHEN** LAN SSH debug is running
- **THEN** the status helper exits successfully and indicates enabled/on
### Requirement: USB plug-ssh coexistence with LAN debug

When LAN SSH debug is enabled, USB plug-ssh SHALL continue to run its usb0-only sshd on `192.168.55.1:22`. LAN SSH debug SHALL listen only on eth0/wlan0 addresses (never `0.0.0.0` and never `192.168.55.1`). Enabling LAN SSH MUST NOT stop the USB plug-ssh sshd process.

#### Scenario: USB cable while LAN debug on

- **WHEN** LAN SSH debug is enabled and the operator plugs USB OTG
- **THEN** `usb0` is configured with `192.168.55.1/24` and USB-SSH login to that address remains available alongside LAN SSH on eth0/wlan0

## Requirements
### Requirement: sshd config does not force USB-only listen globally

Global OpenSSH drop-in configuration used by the image SHALL NOT permanently set `ListenAddress 192.168.55.1` as the only listen address for every sshd invocation. USB plug-ssh SHALL continue to bind `192.168.55.1` via its start script overrides. LAN SSH debug SHALL listen on all interfaces (or equivalent LAN-reachable bind) while enabled.

#### Scenario: LAN enable is not constrained to 192.168.55.1

- **WHEN** LAN SSH debug is enabled and eth0 has `192.168.10.20`
- **THEN** SSH to `192.168.10.20` succeeds (not only `192.168.55.1`)
### Requirement: Dart SshDebug lives under hal/network

On-demand LAN SSH control SHALL be exposed as portable **`SshDebug`** under **`package:cyber_hal/network`** (peer of proxy), not under `hal/debug`.

#### Scenario: Settings uses network SshDebug

- **WHEN** Settings toggles LAN SSH debug
- **THEN** it uses `SshDebug` from the network module
