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

UI chrome MAY use Material widgets where CyberUI counterparts are not yet available. New frost / volume / sound-effect chrome introduced by this change SHALL use CyberUI. Settings MUST NOT block app first paint on the Home route.

#### Scenario: Four tabs visible

- **WHEN** the user opens Settings
- **THEN** the four tab labels are visible in the order listed above

#### Scenario: CyberUI used for new audio chrome

- **WHEN** Settings Volume or Sound Effect surfaces introduced by this change are rendered
- **THEN** they use CyberUI widgets for volume chrome / effect selection rather than inventing a parallel glass kit

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

- Display & Sound: screen brightness via backlight controller; media volume via media audio controller using **Cyber volume chrome** where CyberUI is available; language / unit / screen-off rows MAY remain UI stubs when no platform store exists yet; **sound-effect SHALL be a real Effect 1/2/3 control with persistence** (see `settings-sound-effect`)
- Date & Time: wall clock, manual vs network sync, timezone, Apply / Sync Now via `DateTimeController`
- Input: mouse settings via `MouseSettingsController`; keyboard layout / smoke affordances via keyboard HAL as applicable

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness or volume in Common Settings
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Volume page uses Cyber volume chrome

- **WHEN** the user opens Volume under Display & Sound
- **THEN** the volume control is rendered with CyberUI volume chrome (not a bare Material-only Settings stand-in as the long-term target)

#### Scenario: Sound effect is not a stub

- **WHEN** the user opens Sound Effect under Display & Sound
- **THEN** Effect 1 / Effect 2 / Effect 3 are selectable and the choice is persisted

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

### Requirement: Settings may adopt CyberUI incrementally

Settings shell tabs MAY remain Material. When Settings introduces frosted cards or Cyber dialogs, it SHALL use `packages/cyber_ui` APIs and MUST NOT add a parallel Settings-local glass toolkit.

#### Scenario: Settings stays usable without full glass migration

- **WHEN** CyberUI v1 lands and Settings tabs are not yet fully glass-migrated
- **THEN** Settings remains navigable with Material tab content and existing HAL-backed controls

#### Scenario: New Settings glass uses CyberUI

- **WHEN** a Settings surface adds frosted card or Cyber dialog chrome after this change
- **THEN** that chrome is implemented via CyberUI widgets

### Requirement: Prefer Cyber controls when available

As CyberUI gains switch, checkbox, slider, segmented, stepper, and dialog-host widgets, Settings screens that currently use Material stand-ins for the same role SHALL migrate to the Cyber counterparts in the adoption phase (Phase G), unless a documented exception applies (e.g. platform picker that has no Cyber equivalent yet).

#### Scenario: Volume and sound-effect already on Cyber path

- **WHEN** the operator opens Volume or Sound Effect
- **THEN** those surfaces continue to use Cyber volume / effect selection chrome introduced earlier

#### Scenario: Binary settings rows use CyberSwitch when migrated

- **WHEN** Phase G has migrated a Settings toggle row
- **THEN** that row uses `CyberSwitch` (or package equivalent) rather than raw Material `Switch` alone

### Requirement: Misc Show Startup Self-Check is persisted

Common Settings → Misc SHALL expose an interactive “Show Startup Self-Check” switch backed by the unified Misc JSON store at `/var/lib/hmi/misc-settings.json` (not a dedicated `boot-self-check` file as the ongoing source of truth). The control MUST NOT remain a disabled stub with “Not persisted yet”.

#### Scenario: Switch is interactive

- **WHEN** the operator opens Common Settings → Misc
- **THEN** “Show Startup Self-Check” reflects the current value from `misc-settings.json` (or its default / legacy-imported value)
- **AND** toggling it updates the preference in `misc-settings.json` for subsequent process starts

### Requirement: Misc preferences use unified misc-settings.json

Common Settings → Misc operator preferences SHALL be persisted in a single JSON file at `/var/lib/hmi/misc-settings.json` (or `${OsPaths.varHmi}/misc-settings.json`). The App SHALL NOT introduce additional per-toggle preference files under `/var/lib/hmi/` for new Misc switches. Keys for at least Show Startup Self-Check and Show System Status Overlay SHALL live in this file. Missing file or missing keys SHALL apply documented per-key defaults. Corrupt JSON MUST NOT crash the App (soft-fail to defaults).

#### Scenario: Fresh board uses JSON defaults

- **WHEN** `/var/lib/hmi/misc-settings.json` is absent
- **THEN** Misc preferences use their documented defaults (Show Startup Self-Check enabled; Show System Status Overlay disabled)

#### Scenario: Toggle writes the unified file

- **WHEN** the operator changes a Misc switch (Show Startup Self-Check or Show System Status Overlay)
- **THEN** `/var/lib/hmi/misc-settings.json` is updated to reflect the new value
- **AND** other Misc keys already present in the file remain intact

### Requirement: Misc Show System Status Overlay is persisted

Common Settings → Misc SHALL expose an interactive “Show System Status Overlay” switch backed by the unified Misc JSON store. The control MUST NOT remain a disabled stub with “Not persisted yet”. The preference SHALL default to **off** (overlay hidden). Toggling the switch SHALL update overlay visibility for the current session and for subsequent process starts.

#### Scenario: Switch is interactive and defaults off

- **WHEN** the operator opens Common Settings → Misc on a fresh Misc preference store
- **THEN** “Show System Status Overlay” is present and reflects the disabled (off) state

#### Scenario: Toggle updates preference

- **WHEN** the operator turns “Show System Status Overlay” on or off
- **THEN** the preference is updated in `/var/lib/hmi/misc-settings.json` immediately
- **AND** the global system status card appears or disappears accordingly without requiring an app restart

