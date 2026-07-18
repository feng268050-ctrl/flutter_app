# p2-device-demo-ui Specification

## Purpose

P2 Flutter home demo: device-information rows (iSerial + Modbus), Alarm Information temperatures, mutually exclusive RGB LED mode controls, P2.1 Ethernet / Wi-Fi / HTTP proxy probe / Bluetooth (local adapter + central scan/HID) / USB keyboard / USB mouse sections, P2.2 Date & Time (manual / network), plus audio / brightness controls. Display orientation is **not** a Demo setting (fixed at flutter-pi launch / board default; in-app video rotation stays App-layer).
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

### Requirement: Demo exposes Bluetooth visibility, scanning, and device management

The demo home SHALL include a Bluetooth section that supports both existing local-adapter roles and outbound peripheral management: adapter toggle; local name/address; discoverable and pairable controls; opt-in A2DP Sink control; a unified list of paired/connected remotes with disconnect/remove; bounded scan/stop controls; nearby-device results; and pair/connect actions. The section SHALL display scan and per-device operation state, best-effort device type and signal strength when available, and pairing instructions or challenges required to complete keyboard/mouse pairing. Bluetooth I/O MUST NOT block first-frame paint, and failures MUST remain local to the section without crashing or disabling unrelated controls.

#### Scenario: Toggle enables adapter via controller

- **WHEN** the user turns the Bluetooth toggle on after first frame
- **THEN** the Bluetooth controller is asked to enable the adapter

#### Scenario: Discoverable toggle invokes controller

- **WHEN** the user enables Discoverable
- **THEN** the Bluetooth controller is asked to set discoverable true

#### Scenario: Scan shows nearby devices

- **WHEN** the adapter is on and the user taps Scan
- **THEN** the controller starts bounded discovery and the section updates from its scan/device streams with deduplicated nearby-device rows that follow Settings-style filtering (HID / phone / computer / audio and named devices with relevant services — not anonymous MAC-only LE advertisers)

#### Scenario: Scan hides anonymous LE spam

- **WHEN** discovery reports devices whose alias/name is empty or equal to their address
- **THEN** those devices MUST NOT appear in the Demo nearby list

#### Scenario: Scan results persist after discovery stops

- **WHEN** a bounded scan ends and BlueZ removes temporary Device1 objects
- **THEN** Settings-relevant nearby rows from that scan session remain visible until the next Scan

#### Scenario: User pairs and connects a scan result

- **WHEN** the user selects Pair or Connect for a nearby supported device
- **THEN** the Bluetooth controller is asked to pair/connect that device and the row shows progress followed by connected state or a non-fatal error

#### Scenario: Keyboard passkey instructions are visible

- **WHEN** pairing a keyboard requires the user to type a displayed passkey on that keyboard
- **THEN** the Bluetooth section shows the device identity, passkey, and completion instructions until the request completes or is cancelled

#### Scenario: Existing remote actions invoke controller

- **WHEN** the user taps Disconnect or Remove on a listed bonded or connected remote
- **THEN** the Bluetooth controller is asked to disconnect or remove that address

#### Scenario: Existing Bluetooth roles remain controllable

- **WHEN** central scan/connect controls are present
- **THEN** the same section still exposes discoverable, pairable, incoming-peer management, and opt-in A2DP Sink controls

#### Scenario: Bluetooth failure does not block Demo

- **WHEN** scanning, pairing, or connection fails
- **THEN** the section shows an actionable error while the rest of the Demo remains painted and usable

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

### Requirement: Demo does not expose display orientation controls

The demo home MUST NOT provide Portrait / Landscape (or equivalent) controls that change flutter-pi `-o` / HMI restart orientation. Panel orientation is fixed by image/board launch configuration. Any temporary layout change for media (e.g. video landscape while chrome is portrait) SHALL be product App UI work, not a Demo platform setting.

#### Scenario: No orientation segmented control
- **WHEN** the operator opens the P2 demo home
- **THEN** there is no Demo control whose purpose is to switch system display orientation between portrait and landscape

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

### Requirement: Demo exposes Date & Time section

The P2 demo SHALL include a **Date & Time** section that:

1. Displays the current wall clock (updating while the section is visible)
2. Allows editing date and time for **manual** apply
3. Allows selecting timezone from a curated list that includes at least `UTC` and `Asia/Shanghai`
4. Offers **Manual** vs **Network** sync mode controls
5. Offers **Apply** (manual set) and **Sync Now** (network sync) actions wired to `DateTimeController`

Failures MUST show a non-fatal status/error string and MUST NOT crash the demo. Initialization of the section MUST NOT block first paint (post-frame / after network sections pattern is acceptable).

#### Scenario: Section visible

- **WHEN** the user scrolls to the Date & Time demo section after it has initialized
- **THEN** current time, mode controls, timezone control, Apply, and Sync Now are visible

#### Scenario: Apply sets manual time

- **WHEN** the user enters a valid date/time and taps Apply
- **THEN** the date/time controller is asked to set the wall clock (and mode becomes manual per platform rules)

#### Scenario: Sync Now requests network sync

- **WHEN** the user taps Sync Now
- **THEN** the date/time controller is asked to sync from the network and the section shows success or a structured failure message

#### Scenario: Mode toggle persists via controller

- **WHEN** the user selects Network mode
- **THEN** the date/time controller is asked to set sync mode to `network`

### Requirement: Demo home includes USB keyboard smoke section

The P2/P2.1 demo home SHALL include a USB keyboard smoke section that: shows best-effort keyboard presence/status; provides a focusable text field for typing verification; and notes that this is hardware HID bring-up via the **1 mm USB host expansion** (not product soft IME; not the on-board Micro-USB OTG plug-ssh jack). Keyboard I/O MUST NOT block first-frame paint. On the demo home scroll order, the USB keyboard section SHALL appear **before** the Date & Time section.

#### Scenario: Section visible after first frame

- **WHEN** the user views the P2 demo home after first frame
- **THEN** the USB keyboard smoke section is visible with a text field that can receive focus

#### Scenario: Typing smoke

- **WHEN** a USB HID keyboard is connected via the 1 mm host expansion and the Demo text field has focus
- **THEN** characters typed on the keyboard appear in the field

#### Scenario: Init failure non-fatal

- **WHEN** keyboard presence detection fails or no keyboard is attached
- **THEN** the Demo still paints and the section shows an unavailable / not-detected status without crashing the app

### Requirement: Demo home includes USB mouse smoke and settings section

The P2/P2.1 demo home SHALL include a USB mouse section that: shows best-effort mouse presence/status; allows operators to verify that a **visible** pointer tracks the mouse; and exposes OS-common mouse setting controls (natural scroll, scroll speed, pointer speed, primary button) wired to `MouseSettingsController`. Mouse I/O and settings init MUST NOT block first-frame paint. On the demo home scroll order, the USB mouse section SHALL appear **immediately after** the USB keyboard section and **before** the Date & Time section.

#### Scenario: Section visible after first frame

- **WHEN** the user views the P2 demo home after first frame
- **THEN** the USB mouse section is visible with presence status and setting controls

#### Scenario: Pointer smoke

- **WHEN** a USB HID mouse is connected and the operator moves it
- **THEN** a visible pointer tracks on screen over the Demo UI

#### Scenario: Settings controls call controller

- **WHEN** the user toggles natural scroll or adjusts a speed slider in the mouse Demo section
- **THEN** the mouse settings controller is asked to persist and apply the new value

#### Scenario: Init failure non-fatal

- **WHEN** mouse presence detection or settings load fails
- **THEN** the Demo still paints and the section shows an unavailable / degraded status without crashing the app

