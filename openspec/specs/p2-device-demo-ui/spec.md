# p2-device-demo-ui Specification

## Purpose

P2 Flutter home demo: device-information rows (iSerial + Modbus), Alarm Information temperatures, mutually exclusive RGB LED mode controls, P2.1 Ethernet / Wi-Fi / HTTP proxy probe / Bluetooth discoverable sections, plus audio / brightness / orientation controls.

## Requirements

### Requirement: Home screen lists five device-info rows

The P2 home (or primary demo) screen SHALL display exactly these rows as simple `label: value` text (English labels matching lws-ui Device Information naming):

1. Device SN
2. Gunhead SN
3. Firmware Version
4. Laser Version
5. Wire Feeder Version

A missing or failed value SHALL display exactly `-`.

#### Scenario: All rows visible

- **WHEN** the user views the P2 demo home after first frame
- **THEN** all five labels are visible with a value string (possibly `-`)

#### Scenario: Device SN from iSerial identity

- **WHEN** board iSerial / `read-serial` identity is available
- **THEN** Device SN shows that serial string and is NOT read from Modbus

#### Scenario: Device SN unavailable

- **WHEN** iSerial / `read-serial` identity cannot be obtained
- **THEN** Device SN displays `-`

### Requirement: Home screen lists four Alarm Information temperatures

The P2 demo SHALL also list the four welding-gun sensor temperatures from lws-ui Monitor → **Alarm Information**, as simple `label: value` rows:

1. Motor Temperature
2. Motor Driver Temperature
3. Protective Mirror Temperature
4. Collimator Temperature

Values SHALL use lws-ui scaling (signed register ÷ 10, one decimal, `°C`). Unconnected / error readings (`raw <= -999`) and Modbus failures SHALL display exactly `-`.

#### Scenario: Alarm temperature rows visible

- **WHEN** the user views the P2 demo home after first frame
- **THEN** all four Alarm Information temperature labels are visible with a value string (possibly `-`)

### Requirement: Three exclusive LED mode rows

The demo SHALL provide three control rows labeled for Red, Yellow, and Green. Each row SHALL offer three mutually exclusive choices: **Steady**, **Blink**, and **Off**. Selecting one choice in a row MUST deselect the other two in that row. Rows MUST NOT force a single global mode across colors.

#### Scenario: Exclusive selection within a row

- **WHEN** the user selects Blink on the Red row while Steady was selected
- **THEN** Red is Blink (not Steady), and Yellow/Green selections are unchanged

#### Scenario: Initial mode is Off

- **WHEN** the demo screen first appears
- **THEN** each LED row’s selected mode is Off

### Requirement: UI wires to Modbus and GPIO adapters

Tapping Steady / Blink / Off SHALL invoke the Linux GPIO RGB LED API for that color. Modbus-backed rows SHALL refresh from the Linux Modbus RTU client (on appear and/or a simple refresh), without blocking first paint on success.

#### Scenario: LED control invokes GPIO

- **WHEN** the user selects Steady on the Green row
- **THEN** the GPIO LED controller is asked to set Green to Steady

#### Scenario: Modbus fields refresh without crash

- **WHEN** Modbus is offline
- **THEN** Gunhead SN, Firmware Version, Laser Version, and Wire Feeder Version show `-` and the LED controls remain usable

### Requirement: Demo exposes Ethernet management section above Wi-Fi

The P2/P2.1 demo home SHALL include an Ethernet (RJ45 / eth0) management section that uses the abstract `EthernetController`: interface enable toggle; link/carrier status (and IPv4 when known); **DHCP vs static IPv4** controls for eth0. The Ethernet section SHALL appear **above** the Wi-Fi management section. Ethernet I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables interface via controller

- **WHEN** the user turns the Ethernet toggle on after first frame
- **THEN** the Ethernet controller is asked to enable the interface

#### Scenario: Static IPv4 form invokes controller

- **WHEN** the user selects static mode and applies a valid address/prefix
- **THEN** the Ethernet controller is asked to set static IPv4 configuration

#### Scenario: DHCP mode invokes controller

- **WHEN** the user selects DHCP mode and applies
- **THEN** the Ethernet controller is asked to set DHCP IPv4 configuration

#### Scenario: Ethernet appears before Wi-Fi

- **WHEN** the user scrolls the demo home after network sections are ready
- **THEN** the Ethernet management section is laid out above the Wi-Fi management section

### Requirement: Demo exposes Wi-Fi management section

The P2/P2.1 demo home SHALL include a Wi-Fi management section that uses the abstract `WifiController`: radio toggle; connection status (state, SSID, IPv4 when known); scan + connect to visible APs; **connect to a hidden SSID** via manual SSID + passphrase; **DHCP vs static IPv4** controls for wlan0; disconnect/forget. Wi-Fi I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables radio via controller

- **WHEN** the user turns the Wi-Fi toggle on after first frame
- **THEN** the Wi-Fi controller is asked to enable the radio

#### Scenario: Hidden network connect invokes controller

- **WHEN** the user submits a hidden SSID form with passphrase
- **THEN** the Wi-Fi controller is asked to connect with hidden=true for that SSID

#### Scenario: Static IPv4 form invokes controller

- **WHEN** the user selects static mode and applies a valid address/prefix
- **THEN** the Wi-Fi controller is asked to set static IPv4 configuration

### Requirement: Demo exposes HTTP proxy and network request probe

The demo home SHALL expose HTTP(S) proxy fields (enable, host, port, optional credentials) via the HTTP client abstraction and a control to **send a network request** (configurable URL) that **displays the result** (status code and truncated body, or error). Proxy/request I/O MUST NOT block first-frame paint.

#### Scenario: User runs HTTP probe and sees result

- **WHEN** the user taps the request action with a URL after first frame
- **THEN** the HTTP client controller performs the request and the demo shows status or error text from the result

#### Scenario: Proxy save invokes controller

- **WHEN** the user saves proxy settings
- **THEN** the HTTP client controller is asked to persist those settings

### Requirement: Demo exposes Bluetooth visibility and incoming peers

The demo home SHALL include a Bluetooth section for **being discovered/connected to**: adapter toggle; local name/address; discoverable and pairable controls; list of **incoming** paired/connected remotes with disconnect/remove. The demo MUST NOT present a central “scan for other Bluetooth devices” flow. Bluetooth I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables adapter via controller

- **WHEN** the user turns the Bluetooth toggle on after first frame
- **THEN** the Bluetooth controller is asked to enable the adapter

#### Scenario: Discoverable toggle invokes controller

- **WHEN** the user enables Discoverable
- **THEN** the Bluetooth controller is asked to set discoverable true

#### Scenario: Incoming remote actions invoke controller

- **WHEN** the user taps Disconnect or Remove on a listed incoming remote
- **THEN** the Bluetooth controller is asked to disconnect or remove that address

### Requirement: Demo exposes audio play control and volume slider

The P2/P2.1 demo home SHALL include a control to play/stop the bundled `shanghai_tan.mp3` test track and a volume slider spanning 0–100 that calls the media audio controller. Play/stop and volume changes MUST NOT block first-frame paint.

#### Scenario: Play invokes media audio controller

- **WHEN** the user taps Play (while idle)
- **THEN** the media audio controller is asked to play the shanghai tan asset

#### Scenario: Volume slider sets percent

- **WHEN** the user moves the volume slider to 40
- **THEN** the media audio controller is asked to set volume percent 40

### Requirement: Demo exposes brightness slider

The demo home SHALL include a brightness slider spanning 0–100 that calls the backlight controller. The slider SHOULD initialize from a successful backlight get after first frame when available.

#### Scenario: Brightness slider sets percent

- **WHEN** the user moves the brightness slider to 25
- **THEN** the backlight controller is asked to set brightness percent 25

### Requirement: Demo exposes exclusive portrait/landscape controls

The demo home SHALL provide a mutually exclusive Portrait / Landscape control group. Selecting one MUST deselect the other. Selecting a mode SHALL call the display-orientation API for that mode.

#### Scenario: Exclusive orientation selection

- **WHEN** the user selects Portrait while Landscape was selected
- **THEN** Portrait is selected (not Landscape) and the orientation API is asked to set portrait

#### Scenario: Initial selection matches preference

- **WHEN** the demo screen first appears and the persisted preference is landscape
- **THEN** the Landscape control is the selected mode
