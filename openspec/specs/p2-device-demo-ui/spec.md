# p2-device-demo-ui Specification

## Purpose

P2 Flutter home demo: device-information rows (iSerial + Modbus), Alarm Information temperatures, mutually exclusive RGB LED mode controls, P2.1 Ethernet / Wi-Fi / HTTP proxy probe / Bluetooth (local adapter + central scan/HID) / USB keyboard / USB mouse sections, P2.2 Date & Time (manual / network), plus audio / brightness controls. Display orientation is **not** a Demo setting (fixed at flutter-pi launch / board default; in-app video rotation stays App-layer).
## Requirements
### Requirement: Home screen lists device-info rows

The P2 home (or primary demo) screen SHALL display device-information rows as simple `label: value` text (English labels matching lws-ui Device Information naming where applicable), including at least:

1. Device SN
2. Gunhead SN
3. System Version (Flutter app `versionName`)
4. Kernel Version
5. Control Card Version (Modbus attribute `device.control_card_version`; not “firmware” — that word is reserved for the packaged appliance image)
6. Laser Version
7. Wire Feeder Version

A missing or failed value SHALL display exactly `-`.

#### Scenario: All rows visible

- **WHEN** the user views the P2 demo home after first frame
- **THEN** the listed labels are visible with a value string (possibly `-`)

#### Scenario: Device SN from iSerial identity

- **WHEN** board iSerial / `read-serial` identity is available
- **THEN** Device SN shows that serial string and is NOT read from Modbus

#### Scenario: Device SN unavailable

- **WHEN** iSerial / `read-serial` identity cannot be obtained
- **THEN** Device SN displays `-`

### Requirement: Home screen lists Alarm Information status and temperatures

On the trimmed Demo route, Alarm Information SHALL list Pump / Gun / Feeder Comm Status (as applicable). Host SoC/GPU and welding-gun temperature rows MUST NOT be required on Demo; temperatures live on product Home. Comm-status values that fail SHALL display exactly `-`.

#### Scenario: Comm status rows visible on Demo

- **WHEN** the user views the Demo route Alarm Information group
- **THEN** Pump, Gun, and Feeder Comm Status rows are visible with a value string (possibly `-`)

#### Scenario: Temperature lists not required on Demo

- **WHEN** the user views the Demo route after this change
- **THEN** SoC/GPU and gun temperature rows are not required to be present on Demo

### Requirement: Demo does not expose display orientation controls

The demo home MUST NOT provide Portrait / Landscape (or equivalent) controls that change flutter-pi `-o` / HMI restart orientation. Panel orientation is fixed by image/board launch configuration. Any temporary layout change for media (e.g. video landscape while chrome is portrait) SHALL be product App UI work, not a Demo platform setting.

#### Scenario: No orientation segmented control
- **WHEN** the operator opens the P2 demo home
- **THEN** there is no Demo control whose purpose is to switch system display orientation between portrait and landscape

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

