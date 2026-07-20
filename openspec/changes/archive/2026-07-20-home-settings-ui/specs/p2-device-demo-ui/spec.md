## ADDED Requirements

### Requirement: Demo is available only on a hidden named route

The P2 Demo screen SHALL remain implemented and reachable via the app’s Demo named route (see `hmi-app-navigation`), but MUST NOT be the application launcher home. Product Home and Settings own the operator-facing entry points.

#### Scenario: Demo opens on Demo route

- **WHEN** navigation targets the Demo route
- **THEN** the trimmed P2 Demo screen is displayed

#### Scenario: Demo is not the launcher

- **WHEN** the app starts on the initial route
- **THEN** the P2 Demo is not the first screen shown

### Requirement: Demo omits Settings-owned platform sections

The Demo screen MUST NOT include operator sections for Ethernet, Wi‑Fi, HTTP proxy, Bluetooth, Date & Time, mouse settings, keyboard settings, media volume/play-test, backlight brightness, RGB LED mode controls, or host/gun temperature lists that product Home or Settings own. Those capabilities SHALL be exercised from product Settings (`settings-ui`) or product Home (`product-home-ui`) as applicable. Demo MAY retain device-information rows, Alarm Information **comm status** rows, and Debug over USB/LAN toggles, and MUST continue to omit display-orientation controls.

#### Scenario: Settings sections absent on Demo

- **WHEN** the user views the Demo route after this change
- **THEN** Ethernet, Wi‑Fi, HTTP proxy, Bluetooth, Date & Time, mouse, keyboard, speaker/volume, brightness, RGB LED, and temperature list sections are not present

#### Scenario: Core smoke sections remain

- **WHEN** the user views the Demo route after this change
- **THEN** device-information rows, Alarm Information comm-status rows, and Debug over USB/LAN toggles remain available

## MODIFIED Requirements

### Requirement: Home screen lists Alarm Information status and temperatures

On the trimmed Demo route, Alarm Information SHALL list Pump / Gun / Feeder Comm Status (as applicable). Host SoC/GPU and welding-gun temperature rows MUST NOT be required on Demo; temperatures live on product Home. Comm-status values that fail SHALL display exactly `-`.

#### Scenario: Comm status rows visible on Demo

- **WHEN** the user views the Demo route Alarm Information group
- **THEN** Pump, Gun, and Feeder Comm Status rows are visible with a value string (possibly `-`)

#### Scenario: Temperature lists not required on Demo

- **WHEN** the user views the Demo route after this change
- **THEN** SoC/GPU and gun temperature rows are not required to be present on Demo

### Requirement: Demo exposes LAN SSH debug toggle after HTTP / Proxy

The Demo route SHALL include a **Debug** group with two toggles: **Debug over USB** and **Debug over LAN**. Debug over USB SHALL control Micro-USB plug-ssh vs host via `UsbDebugController` (persisted, default on). Debug over LAN SHALL control on-demand LAN/WLAN SSH via `SshDebugController` (not persisted, default off). Toggle I/O MUST NOT block first-frame paint. Placement MAY follow device/alarm/LED content; it MUST NOT depend on HTTP Proxy or Bluetooth sections remaining on Demo.

#### Scenario: Toggle enables Debug over LAN

- **WHEN** the user turns Debug over LAN on after first frame
- **THEN** the SSH debug controller is asked to enable LAN SSH debug

#### Scenario: Toggle disables Debug over LAN

- **WHEN** the user turns Debug over LAN off while it was on
- **THEN** the SSH debug controller is asked to disable LAN SSH debug

#### Scenario: Toggle disables Debug over USB for keyboard

- **WHEN** the user turns Debug over USB off after first frame
- **THEN** the USB debug controller is asked to disable USB Debug (host mode)

#### Scenario: Debug group visible on Demo

- **WHEN** the user views the Demo route
- **THEN** the Debug group with USB and LAN toggles is visible

## REMOVED Requirements

### Requirement: Demo exposes Ethernet management section above Wi-Fi

**Reason**: Ethernet operator UI moves to product Settings Common → Network.
**Migration**: Use `settings-ui` Network Ethernet entry wired to `EthernetController`.

### Requirement: Demo exposes Wi-Fi management section

**Reason**: Wi‑Fi operator UI moves to product Settings.
**Migration**: Use `settings-ui` Network Wireless Network entry and shared Wi‑Fi panels.

### Requirement: Demo exposes HTTP proxy and network request probe

**Reason**: Proxy (and optional probe) moves to product Settings.
**Migration**: Use `settings-ui` HTTP Proxy entry; probe may remain Advanced/Settings-only.

### Requirement: Demo exposes Bluetooth visibility, scanning, and device management

**Reason**: Bluetooth operator UI moves to product Settings (explicit Common Network addition).
**Migration**: Use `settings-ui` Bluetooth settings backed by `BluetoothController`.

### Requirement: Demo exposes audio play control and volume slider

**Reason**: Volume (and speaker test) leave Demo; volume lives under Settings Display & Sound.
**Migration**: Use `settings-ui` volume control via media audio controller; play-test optional in Settings or omitted.

### Requirement: Demo exposes brightness slider

**Reason**: Brightness moves to Settings Display & Sound.
**Migration**: Use `settings-ui` brightness slider via backlight controller.

### Requirement: Demo exposes Date & Time section

**Reason**: Date & Time moves to Common Settings.
**Migration**: Use `settings-ui` Date & Time group via `DateTimeController`.

### Requirement: Demo home includes USB keyboard smoke section

**Reason**: Keyboard operator/smoke UI moves under Settings input; Demo is no longer the settings surface.
**Migration**: Use `settings-ui` keyboard controls; HID bring-up notes may live there.

### Requirement: Demo home includes USB mouse smoke and settings section

**Reason**: Mouse settings move to Common Settings input.
**Migration**: Use `settings-ui` mouse controls via `MouseSettingsController`.

### Requirement: Three exclusive LED mode rows

**Reason**: RGB LED operator controls move to product Settings Display & Sound.
**Migration**: Use `settings-ui` LED page wired to GPIO RGB LED controller.

### Requirement: UI wires to Modbus and GPIO adapters

**Reason**: LED GPIO wiring follows the Settings LED page; Demo no longer hosts LED rows. Modbus-backed device-info rows on Demo remain covered by device-information requirements.
**Migration**: Settings LED page invokes GPIO; Demo device-info continues Modbus refresh without LED UI.
