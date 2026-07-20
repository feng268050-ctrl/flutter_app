# settings-ui Specification

## Purpose
TBD - created by archiving change home-settings-ui. Update Purpose after archive.
## Requirements
### Requirement: Settings shell uses four fixed tabs

The product Settings screen SHALL present four top-level tabs in this order, matching lws-ui Device Settings structure:

1. Device Information
2. Common Settings
3. Advanced Settings
4. Custom Home Page

UI chrome SHALL use Material widgets as stand-ins for FrostUI (cards, switches, sliders, segmented controls, tabs, dialogs). Settings MUST NOT block app first paint on the Home route.

#### Scenario: Four tabs visible

- **WHEN** the user opens Settings
- **THEN** the four tab labels are visible in the order listed above

#### Scenario: Material stand-ins only

- **WHEN** Settings is rendered before CyberUI migration
- **THEN** interactive controls use Material components rather than FrostUI/CyberUI packages

### Requirement: Common Settings Network includes Wi-Fi, proxy, Ethernet, and Bluetooth

Common Settings SHALL include a Network group with operator entry points for:

- Wireless Network (Wi‑Fi) using `WifiController`
- HTTP Proxy using the HTTP/proxy abstraction
- Ethernet (RJ45 / eth0) using `EthernetController`
- Bluetooth using `BluetoothController` (explicit addition vs current lws-ui Common Network)

Network I/O MUST NOT block Home first paint. Failures MUST be local to Settings and non-fatal to the rest of the shell.

#### Scenario: Network group lists four entries

- **WHEN** the user opens Common Settings
- **THEN** Wi‑Fi, HTTP Proxy, Ethernet, and Bluetooth entries are available under Network

#### Scenario: Bluetooth entry opens Bluetooth settings

- **WHEN** the user opens Bluetooth from Common Settings Network
- **THEN** the Bluetooth settings UI can toggle the adapter and perform scan/pair/connect flows via `BluetoothController`

#### Scenario: Wi-Fi controls invoke controller

- **WHEN** the user enables Wi‑Fi or connects to an AP from Settings
- **THEN** the Wi‑Fi controller is asked to perform the corresponding action

### Requirement: Common Settings exposes display, sound, date-time, and input controls

Common Settings SHALL expose:

- Display & Sound: screen brightness via backlight controller; media volume via media audio controller; language / unit / screen-off / sound-effect rows MAY be present as UI stubs when no platform store exists yet
- Date & Time: wall clock, manual vs network sync, timezone, Apply / Sync Now via `DateTimeController`
- Input: mouse settings via `MouseSettingsController`; keyboard layout / smoke affordances via keyboard HAL as applicable

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness or volume in Common Settings
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Date and time sync actions invoke controller

- **WHEN** the user taps Apply or Sync Now in Date & Time
- **THEN** the date/time controller is asked to set the clock or sync from the network

#### Scenario: Mouse settings invoke controller

- **WHEN** the user changes a mouse setting in Common Settings
- **THEN** the mouse settings controller is asked to persist and apply the value

### Requirement: Device Information shows available identity and version rows

Device Information SHALL display available device identity and version rows (at least Device SN and System Version when resolvable), using existing sysinfo / SN / Modbus-backed values where already implemented. Missing values SHALL show `-`. OTA / secret debug gestures MAY be deferred.

#### Scenario: Device Information lists core rows

- **WHEN** the user opens the Device Information tab
- **THEN** Device SN and System Version rows are visible with a value string (possibly `-`)

### Requirement: Advanced and Custom Home tabs are structurally present

Advanced Settings and Custom Home Page tabs SHALL be reachable in the Settings shell. Until product domain migration completes, they MAY show explicit placeholders rather than full lws-ui Modbus/Room or drag-layout behavior.

#### Scenario: Advanced tab opens

- **WHEN** the user selects Advanced Settings
- **THEN** the Advanced tab content is shown (live controls and/or a clear placeholder)

#### Scenario: Custom Home tab opens

- **WHEN** the user selects Custom Home Page
- **THEN** the Custom Home tab content is shown (live controls and/or a clear placeholder)

### Requirement: Settings does not host USB or LAN SSH debug toggles

Product Settings MUST NOT expose Debug over USB or Debug over LAN toggles. Those remain on the hidden Demo route only.

#### Scenario: No debug toggles in Settings

- **WHEN** the user browses Settings tabs and Common groups
- **THEN** there is no control whose purpose is enabling USB plug-ssh host mode or LAN SSH debug

### Requirement: Display & Sound includes RGB LED controls

Common Settings Display & Sound SHALL include an RGB LED entry that opens controls for Red, Yellow, and Green modes (Steady / Blink / Off), wired to the GPIO RGB LED controller. LED I/O MUST NOT block Home first paint.

#### Scenario: LED entry under Display and Sound

- **WHEN** the user opens Display & Sound in Common Settings
- **THEN** an RGB LED (or equivalent) entry is available

#### Scenario: LED mode invokes GPIO controller

- **WHEN** the user selects Steady on the Green LED control from Settings
- **THEN** the GPIO LED controller is asked to set Green to Steady

