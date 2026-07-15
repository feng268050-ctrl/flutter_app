## MODIFIED Requirements

### Requirement: Demo exposes LAN SSH debug toggle after HTTP / Proxy

The P2/P2.1 demo home SHALL include a **Debug** group after the HTTP / Proxy section with two toggles: **Debug over USB** and **Debug over LAN**. Debug over USB SHALL control Micro-USB plug-ssh vs host via `UsbDebugController` (persisted, default on). Debug over LAN SHALL control on-demand LAN/WLAN SSH via `SshDebugController` (not persisted, default off). Toggle I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables Debug over LAN

- **WHEN** the user turns Debug over LAN on after first frame
- **THEN** the SSH debug controller is asked to enable LAN SSH debug

#### Scenario: Toggle disables Debug over LAN

- **WHEN** the user turns Debug over LAN off while it was on
- **THEN** the SSH debug controller is asked to disable LAN SSH debug

#### Scenario: Toggle disables Debug over USB for keyboard

- **WHEN** the user turns Debug over USB off after first frame
- **THEN** the USB debug controller is asked to disable USB Debug (host mode)

#### Scenario: Section placement

- **WHEN** the user scrolls the Demo home past HTTP / Proxy
- **THEN** the Debug group appears before Bluetooth
