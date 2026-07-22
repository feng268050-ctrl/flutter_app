## MODIFIED Requirements

### Requirement: Common Settings Network includes Wi-Fi, proxy, Ethernet, and Bluetooth

Common Settings SHALL include a Network group with operator entry points for:

- Wireless Network (Wi‑Fi) using the existing Wi‑Fi settings flow
- HTTP Proxy
- Bluetooth

Common Settings MUST NOT expose an Ethernet (RJ45 / eth0) operator settings entry. On this product the wired port is reserved for the IPC dedicated link and is brought up by the product IP-camera session, not by a Common Settings Ethernet page.

#### Scenario: Network group lists Wi-Fi, proxy, and Bluetooth only

- **WHEN** the operator opens Common Settings
- **THEN** Wi‑Fi, HTTP Proxy, and Bluetooth entries are available under Network
- **AND** an Ethernet settings row MUST NOT be listed

#### Scenario: Ethernet page is not reachable from Common Settings

- **WHEN** the operator navigates only through Common Settings Network rows
- **THEN** the App MUST NOT open the former Ethernet settings page

### Requirement: Common Settings exposes display, sound, date-time, and input controls

Common Settings SHALL expose:

- Display & Sound: screen brightness via backlight controller; media volume via media audio controller using **Cyber volume chrome** where CyberUI is available; language / unit / screen-off rows MAY remain UI stubs when no platform store exists yet; **sound-effect SHALL be a real Effect 1/2/3 control with persistence** (see `settings-sound-effect`)
- Date & Time: wall clock, manual vs network sync, timezone, Apply / Sync Now via `DateTimeController`
- Input: mouse settings via `MouseSettingsController`; keyboard layout / smoke affordances via keyboard HAL as applicable; **IP Camera** entry that navigates to a live preview page backed by the product IP-camera session (HAL `ip_camera` + this product’s path/relay)

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness or volume in Common Settings
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Volume page uses Cyber volume chrome

- **WHEN** the user opens Volume under Display & Sound
- **THEN** the volume control is rendered with CyberUI volume chrome (not a bare Material-only Settings stand-in as the long-term target)

#### Scenario: Sound effect is not a stub

- **WHEN** the user opens Sound Effect under Display & Sound
- **THEN** Effect 1 / Effect 2 / Effect 3 are selectable and the choice is persisted

#### Scenario: Date and time sync actions invoke controllers

- **WHEN** the user taps Apply or Sync Now in Date & Time
- **THEN** the date/time controller is asked to set the clock or sync from the network

#### Scenario: Mouse settings invoke controller

- **WHEN** the user changes a mouse setting in Common Settings
- **THEN** the mouse settings controller is asked to persist and apply the value

#### Scenario: Input lists IP Camera

- **WHEN** the operator opens Common Settings
- **THEN** an IP Camera row SHALL be available under Input alongside Mouse and Keyboard

## ADDED Requirements

### Requirement: IP Camera settings page previews live video via the product session

Common Settings → Input → IP Camera SHALL open a settings page that shows product IP-camera UI status and a **real live video preview**. On this product, preview MUST use the session-published **local MediaMTX** URL when the relay is running, and MUST NOT require opening a direct long-lived RTSP session to the camera’s native upstream as the primary multi-consumer path. The Linux/flutter-pi implementation SHALL decode and render the stream through the GStreamer/Rockchip MPP video plugin (or a demonstrably equivalent hardware-accelerated texture path). Opening the page SHALL call `ensureReady()` (or equivalent) without blocking the Settings shell from painting; while not ready, the page SHALL show establishing/failed placeholder UI. A static placeholder, RTSP URL text, or “GStreamer pending” message MUST NOT be accepted as the successful preview state.

#### Scenario: Preview uses local relay URL on this product

- **WHEN** the product MediaMTX relay is running
- **AND** the operator opens IP Camera under Input
- **THEN** the preview surface SHALL bind to a localhost MediaMTX URL from the product session
- **AND** after player initialization it SHALL display live moving camera frames in a Flutter video texture

#### Scenario: Successful preview is not a placeholder

- **WHEN** the camera connection and MediaMTX relay are ready
- **AND** the video player receives its first frame
- **THEN** the page SHALL replace the establishing placeholder with the live video surface
- **AND** MUST NOT show URL-only or “player pending” content as the terminal ready state

#### Scenario: Preview placeholder while connecting

- **WHEN** product UI phase is **connecting**, relay is not ready, or the video player is waiting for its first frame
- **AND** the operator opens IP Camera under Input
- **THEN** the page SHALL show a non-blocking establishing/failed placeholder
- **AND** MUST NOT freeze Settings navigation awaiting the first video frame

#### Scenario: Preview player is disposed with the page

- **WHEN** the operator leaves the IP Camera settings page
- **THEN** the App SHALL pause and dispose the page-owned video controller/texture
- **AND** returning to the page SHALL be able to create a fresh preview

#### Scenario: Decoder or RTSP error is retryable

- **WHEN** the GStreamer player reports an initialization, decoder, or RTSP error
- **THEN** the page SHALL show a failed/retryable state instead of a false live preview
- **AND** a later retry SHALL recreate the player against the local MediaMTX URL

### Requirement: IP Camera settings provides a recording demonstration

The IP Camera settings page SHALL place a Record/Stop control below the live
preview. This control is a settings demonstration only: it SHALL call the
`ip_camera` HAL recording controller against this product's local MediaMTX PR0
URL and SHALL NOT reuse or define future Quick Mode / Engineer Mode business
recording workflows. Files SHALL be saved under
`/userdata/storage/Videos/movie/<yyyy-MM-dd>/<yy-MM-dd_HH-mm-ss>.mp4`.
No file browser, database row, cover extraction, process metadata, or upload
workflow is required. After a successful stop, the page SHALL tell the operator
the exact saved path.

#### Scenario: Record remains preparing until HAL confirms media

- **WHEN** the operator presses Record while the relay is available
- **THEN** the page SHALL show a preparing state from HAL
- **AND** MUST NOT label the operation recording until HAL confirms stream/muxer readiness

#### Scenario: Stop reports saved location

- **WHEN** the operator presses Stop during an active recording
- **AND** HAL successfully finalizes the file
- **THEN** the page SHALL return to the Record action
- **AND** SHALL display a transient message containing the exact saved path

#### Scenario: Demo recording is isolated from future business recording

- **WHEN** a settings-page recording completes
- **THEN** it SHALL leave only the video file in the configured directory
- **AND** MUST NOT create Quick/Engineer process records or expose file-management UI
