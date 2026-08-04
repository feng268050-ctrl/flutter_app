## ADDED Requirements

### Requirement: Camera settings Change Overlay opens a parameter dialog

Common Settings → Camera SHALL place a **Change Overlay** action **after** the live preview (not an inline Overlay settings group on the page body). Tapping Change Overlay SHALL open a dialog that presents:

- Enable (on/off) for clock + machine-name OSD
- When Enable is on: Horizontal position X (integer, range 0…384) and Vertical position Y (integer, range 0…288; effective max 238 while enabled)
- When Enable is off: Position X / Y controls MUST NOT be shown

Dialog controls SHALL edit local state only. Confirming with **Apply** SHALL invoke the shared camera OSD apply path (`camera-osd-overlay`) **once** with the current Enable / X / Y. On successful apply the dialog MUST close. On failure the dialog MUST remain open, surface a transient error, and allow another Apply. Cancel / dismiss without Apply MUST NOT invoke the apply path. While Apply is in flight, the dialog MUST prevent a second concurrent Apply (disable Apply and/or block dismiss as needed to avoid double-submit).

#### Scenario: Change Overlay after preview

- **WHEN** the operator opens Camera settings
- **THEN** a Change Overlay action is available after the live preview
- **AND** the page body MUST NOT show an inline Overlay enable / X / Y settings group

#### Scenario: Dialog hosts enable; position only when enabled

- **WHEN** the operator taps Change Overlay
- **AND** Enable is off
- **THEN** a dialog opens with the Enable control
- **AND** Position X / Y controls MUST NOT be visible

#### Scenario: Position appears when Enable turns on

- **WHEN** the Overlay dialog is open
- **AND** the operator turns Enable on
- **THEN** Position X and Y controls become visible

#### Scenario: Editing does not apply until Apply

- **WHEN** the operator changes Enable, X, or Y in the Overlay dialog
- **AND** has not tapped Apply
- **THEN** the App MUST NOT invoke the OSD apply path solely due to those edits

#### Scenario: Apply once then close on success

- **WHEN** the operator taps Apply with valid Enable / X / Y
- **AND** the OSD apply succeeds
- **THEN** exactly one OSD apply runs for that parameter set
- **AND** the dialog closes

#### Scenario: Failure keeps dialog open

- **WHEN** the operator taps Apply
- **AND** the OSD apply fails
- **THEN** the dialog remains open
- **AND** the operator sees a transient error indication
- **AND** Apply becomes available again

#### Scenario: Cancel without apply

- **WHEN** the operator cancels or dismisses the Overlay dialog without tapping Apply
- **THEN** the App MUST NOT invoke an OSD apply solely due to dismiss

## MODIFIED Requirements

### Requirement: IP Camera settings page previews live video via the product session

Common Settings → Camera SHALL open a settings page that shows product camera **Status**, **Camera Type**, **Camera Version**, a **real live video preview**, and a **Change Overlay** action after the preview (dialog for enable / X / Y per the Change Overlay requirement). On this product, preview MUST use the session-published **local MediaMTX** URL when the relay is running, and MUST NOT require opening a direct long-lived RTSP session to the camera’s native upstream as the primary multi-consumer path. The Linux/eLinux HMI implementation SHALL decode and render the stream through the GStreamer/Rockchip MPP video plugin (or a demonstrably equivalent hardware-accelerated texture path). Opening the page SHALL call `ensureReady()` (or equivalent) without blocking the Settings shell from painting; while not ready, the page SHALL show establishing/failed placeholder UI. A static placeholder or “GStreamer pending” message MUST NOT be accepted as the successful preview state. The page MUST NOT display Camera IP or Preview URL as operator-visible rows. The page MUST NOT offer a manual Retry control for connection/MediaMTX bring-up.

#### Scenario: Preview uses local relay URL on this product

- **WHEN** the product MediaMTX relay is running
- **AND** the operator opens Camera under Common Settings
- **THEN** the preview surface SHALL bind to a localhost MediaMTX URL from the product session
- **AND** after player initialization it SHALL display live moving camera frames in a Flutter video texture

#### Scenario: Successful preview is not a placeholder

- **WHEN** the camera connection and MediaMTX relay are ready
- **AND** the video player receives its first frame
- **THEN** the page SHALL replace the establishing placeholder with the live video surface
- **AND** MUST NOT show URL-only or “player pending” content as the terminal ready state

#### Scenario: Preview placeholder while connecting

- **WHEN** product UI phase is **connecting**, relay is not ready, or the video player is waiting for its first frame
- **AND** the operator opens Camera under Common Settings
- **THEN** the page SHALL show a non-blocking establishing/failed placeholder
- **AND** MUST NOT freeze Settings navigation awaiting the first video frame

#### Scenario: Preview player is disposed with the page

- **WHEN** the operator leaves the Camera settings page
- **THEN** the App SHALL pause and dispose the page-owned video controller/texture
- **AND** returning to the page SHALL be able to create a fresh preview

#### Scenario: No IP or URL rows

- **WHEN** the operator opens the Camera settings page
- **THEN** Camera IP and Preview URL rows are not shown

#### Scenario: No manual Retry control

- **WHEN** the operator opens the Camera settings page
- **THEN** no Retry button for connection/MediaMTX is shown

#### Scenario: Change Overlay follows preview

- **WHEN** the operator opens the Camera settings page
- **THEN** Change Overlay is available after the preview
- **AND** Status / Type / Version remain above the preview
