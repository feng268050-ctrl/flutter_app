## ADDED Requirements

### Requirement: USB plug-ssh start tolerates active LAN SSH debug

When LAN/WLAN on-demand SSH debug is already listening on port 22, USB plug-ssh start SHALL still bring up the ECM gadget and `usb0` addressing and SHALL NOT fail solely because a second usb0-only sshd process cannot bind.

#### Scenario: Plug USB while LAN debug enabled

- **WHEN** `enable-ssh-debug.sh` has started LAN sshd and the operator connects USB OTG
- **THEN** `usb0` is configured with `192.168.55.1/24` and plug-ssh start completes successfully

### Requirement: Replug re-enumerates USB debug

After VBUS detach, a subsequent VBUS attach SHALL force a clean `g_ether` reload (including when the module was still sticky) so the host re-enumerates the ECM gadget and `make devices` lists a USB-SSH row again. Concurrent VBUS extcon events during debounce MUST NOT drop the final plug state.

#### Scenario: Unplug then replug

- **WHEN** the OTG cable is unplugged and then replugged during Linux runtime
- **THEN** within 15 seconds the host observes the gadget again and `make devices` shows a USB-SSH row
