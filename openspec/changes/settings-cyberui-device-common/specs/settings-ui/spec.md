## ADDED Requirements

### Requirement: Device Information and Common Settings use CyberUI cards without visible group titles

Device Information and Common Settings SHALL render settings groups with CyberUI card chrome (`CyberCard` or shared Settings wrappers built on CyberUI). Operator-visible **group section titles** (e.g. Network, Display & Sound, Identity, Versions) MUST NOT appear on these tabs. Group boundaries SHALL be conveyed by separate cards and spacing only. Source code MAY retain comment labels naming each group for maintainers.

#### Scenario: Common Settings has no group header text

- **WHEN** the operator opens Common Settings
- **THEN** no uppercase/localized section header widgets for Network / Display & Sound / Date & Time / Input / Misc (or equivalent) are visible above the cards
- **AND** the Wi‑Fi and Language controls remain reachable inside card groups

#### Scenario: Device Information has no group header text

- **WHEN** the operator opens Device Information
- **THEN** no Identity / Versions / Platform section header text is visible
- **AND** identity and version rows remain visible inside CyberUI cards

#### Scenario: CyberUI cards not Material Card as primary shell

- **WHEN** Device Information or Common Settings paints a settings group
- **THEN** the group shell uses CyberUI frosted card chrome rather than Material `Card` as the long-term primary shell

### Requirement: Common Settings Display and Sound controls are inline CyberUI where lws-ui is inline

Within Common Settings, Language, Unit, Brightness, Auto Screen Off, Volume, and Sound Effects SHALL be operable from the main tab using CyberUI controls (segmented control, capsule slider, volume slider) without requiring a chevron push for the primary adjustment path, matching lws-ui Frost inline composition. Language SHALL continue to offer **three** App locales (`en-US`, `zh-CN`, `zh-TW`) — MUST NOT regress to lws-ui’s bilingual-only choice. Persistence and HAL bindings remain as today’s stores/controllers.

#### Scenario: Brightness adjusts on the Common Settings tab

- **WHEN** the operator moves the brightness control on Common Settings
- **THEN** HAL `Backlight` is asked to set the corresponding percent without opening a dedicated Brightness sub-page as the only path

#### Scenario: Language still lists three locales

- **WHEN** the operator changes Language on Common Settings
- **THEN** English, 简体中文, and 繁體中文 remain available
- **AND** the choice persists via `CommonSettingsStore` and updates UI locale

### Requirement: Common Settings Date and Time follows Automatic plus conditional rows

Common Settings SHALL present Date & Time in an untitled CyberUI card with an **Automatic** switch and **Set Date** / **Set Time** / **Set Time Zone** rows that open CyberUI dialogs (or equivalent) when Automatic is off, matching lws-ui behavior. A sync status line MAY appear below the card. Controls SHALL use `DateTimeController`.

#### Scenario: Automatic hides manual rows

- **WHEN** Automatic is on
- **THEN** Set Date / Set Time / Set Time Zone rows are hidden or disabled per lws-ui parity
- **AND** network time sync policy is enabled via the date/time controller

#### Scenario: Manual date dialog

- **WHEN** Automatic is off and the operator opens Set Date
- **THEN** a CyberUI dialog allows choosing a calendar date and applying it through `DateTimeController`

### Requirement: Camera is its own Common Settings group named Camera

Common Settings SHALL present **Camera** as a dedicated untitled card group (not nested under Input). The row label SHALL be **Camera** (localized), not “IP Camera”. Tapping SHALL open the Camera settings page (product IP-camera session). Input SHALL retain Mouse, Keyboard, and USB OTG only (no Camera row under Input).

#### Scenario: Camera group separate from Input

- **WHEN** the operator opens Common Settings
- **THEN** a Camera navigation row appears in its own card group
- **AND** the Input card group does not list Camera / IP Camera

#### Scenario: Camera label

- **WHEN** Language is `en-US`
- **THEN** the Camera row title is `Camera`

### Requirement: Device Information row set matches lws-ui without Camera Type or Camera Version

Device Information SHALL show CyberUI untitled cards with at least:

1. Identity: Device Model (QR), Device SN, Welding Gun SN  
2. Versions: System Version, Process Library Version (when available), Firmware Version (existing control-card / firmware Modbus value), Laser Version, Wire Feeder Version — and MAY retain HMI-only Kernel Version / Display Stack  
3. Focus: Focus Scale Reference  

Device Information MUST NOT show Camera Type or Camera Version. OTA footer controls (**Check for Updates**, **Automatically check for updates**) SHALL be present; when no OTA client is available they SHALL report an unavailable/deferred status rather than a false success. Secret 5×-tap debug entry points MUST NOT be implemented.

#### Scenario: No Camera Type on Device Information

- **WHEN** the operator opens Device Information
- **THEN** Camera Type is not listed
- **AND** Focus Scale Reference remains visible

#### Scenario: Welding Gun SN present

- **WHEN** the operator opens Device Information
- **THEN** a Welding Gun SN (or localized equivalent) row is visible with a value or `-`

#### Scenario: Check for Updates visible

- **WHEN** the operator opens Device Information
- **THEN** a Check for Updates action is visible

## MODIFIED Requirements

### Requirement: Common Settings exposes display, sound, date-time, and input controls

Common Settings SHALL expose:

- Display & Sound (untitled card): Language and Unit as persisted controls backed by `/var/lib/hmi/common-settings.json`; Language drives Flutter UI locale and CyberIME for three locales; brightness via HAL `Backlight`; screen-off via HAL `AutoSleep`; media volume via Cyber volume chrome; sound-effect Effect 1/2/3 via HAL `ButtonFeedback`. Primary adjustments SHALL be inline CyberUI on the Common Settings tab (lws-ui parity). Order: Language and Unit before brightness / screen-off; display before sound.
- Date & Time (untitled card): Automatic sync plus Set Date / Set Time / Set Time Zone via `DateTimeController` (lws-ui parity).
- Input (untitled card): mouse settings; keyboard layout; USB OTG. **Camera is not under Input** (see Camera group requirement).
- Camera (untitled card): Camera entry → product IP-camera settings page.
- Operator-visible labels SHALL come from App localization. Group section titles MUST NOT be shown.

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness or volume in Common Settings
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Screen-off invokes AutoSleep

- **WHEN** the user selects a Screen-off Time option other than the current policy
- **THEN** HAL `AutoSleep` is asked to set the corresponding policy and the choice is persisted

#### Scenario: Sound effect is not a stub

- **WHEN** the user selects a Sound Effect option on Common Settings
- **THEN** Effect 1 / Effect 2 / Effect 3 are selectable and the choice is persisted via `ButtonFeedback`

#### Scenario: Language is persisted

- **WHEN** the user selects a Language option other than the current value
- **THEN** the choice is persisted in `/var/lib/hmi/common-settings.json` and Common Settings shows the matching Language summary or segment

#### Scenario: Unit is persisted

- **WHEN** the user selects a Unit option other than the current value
- **THEN** the choice is persisted in `/var/lib/hmi/common-settings.json`

#### Scenario: Date and time sync actions invoke controllers

- **WHEN** the user enables Automatic or applies a manual date/time/zone change
- **THEN** the date/time controller is asked to set the corresponding policy or wall clock

#### Scenario: Mouse settings invoke controller

- **WHEN** the user changes a mouse setting from Common Settings
- **THEN** the mouse settings controller is asked to persist and apply the value

#### Scenario: Camera is not under Input

- **WHEN** the operator opens Common Settings
- **THEN** Camera is reachable from its own group
- **AND** Input does not list IP Camera / Camera

#### Scenario: Common Settings chrome follows UI locale

- **WHEN** Language is `zh-CN` and the operator opens Common Settings
- **THEN** migrated row titles and control labels render in Simplified Chinese via App localization

### Requirement: Device Information shows available identity and version rows

Device Information SHALL display device identity and version rows in **untitled CyberUI card groups** (no section header text; same Settings chrome vocabulary as Common Settings):

1. **Identity:** Device Model (with device QR affordance), Device SN, Welding Gun SN  
2. **Versions:** System Version, Process Library Version when available, Firmware Version (control-card / firmware Modbus display), Laser Version, Wire Feeder Version; HMI MAY also show Kernel Version and Display Stack  
3. **Focus:** Focus Scale Reference  

Device Model SHALL be `brand + " " + model` from HAL product identity (`product.ini`), with each missing part shown as `-`; if both parts are missing (computed value `- -`), the row SHALL display a single `-`. Device SN SHALL use product identity SN resolution (non-empty `product.ini` `sn`, else chip/board serial). Focus Scale Reference SHALL come from `product.ini` `focus_scale_ref` via HAL `ProductInfo` (empty → `-`). Camera Type and Camera Version MUST NOT appear on this tab. The tab MUST NOT show a Modbus Link row. Missing or empty values SHALL show `-`. OTA check-update controls SHALL appear per the Device Information row-set requirement.

#### Scenario: Device Information lists grouped core rows

- **WHEN** the user opens the Device Information tab
- **THEN** Device Model, Device SN, System Version, and Focus Scale Reference rows are visible with a value string (possibly `-`)
- **AND** Device Model appears in the first card before Device SN
- **AND** Focus Scale Reference appears in a card below the versions card
- **AND** Camera Type is not shown
- **AND** Modbus Link is not shown

#### Scenario: Empty brand and model show single dash

- **WHEN** product brand and model are both empty
- **THEN** the Device Model row SHALL display `-` (not `- -`)

#### Scenario: Combined brand and model

- **WHEN** product brand is `Innohi` and model is `YNH960`
- **THEN** the Device Model row SHALL display `Innohi YNH960`

#### Scenario: Device QR opens identity payload

- **WHEN** the user activates the device QR control on the Device Model row
- **THEN** a dismissible dialog SHALL show a QR encoding `SN|2|Model|SystemVersion` (v2), with `|` characters in fields replaced by `_`

#### Scenario: Focus scale from product.ini

- **WHEN** `product.ini` contains `focus_scale_ref=12`
- **THEN** Focus Scale Reference SHALL display `12`

### Requirement: Display & Sound includes RGB LED controls

Common Settings SHALL include an RGB LED entry in an **untitled** card **after** the main Display & Sound controls card (the card that contains language / unit / brightness / screen-off / volume / sound-effect), not as a mid-group row among those controls. The entry opens controls for Red, Yellow, and Green modes (Steady / Blink / Off), wired to the GPIO RGB LED controller. LED I/O MUST NOT block Home first paint. No visible “Display & Sound” section title is required.

#### Scenario: LED entry after display-sound group

- **WHEN** the user opens Common Settings
- **THEN** an RGB LED (or equivalent) entry is available in a card after the main Display & Sound controls card

#### Scenario: LED mode invokes GPIO controller

- **WHEN** the user selects Steady on the Green LED control from Settings
- **THEN** the GPIO LED controller is asked to set Green to Steady

### Requirement: IP Camera settings page previews live video via the product session

Common Settings → Camera SHALL open a settings page that shows product camera **Status**, **Camera Type**, **Camera Version**, and a **real live video preview**. On this product, preview MUST use the session-published **local MediaMTX** URL when the relay is running, and MUST NOT require opening a direct long-lived RTSP session to the camera’s native upstream as the primary multi-consumer path. The Linux/flutter-pi implementation SHALL decode and render the stream through the GStreamer/Rockchip MPP video plugin (or a demonstrably equivalent hardware-accelerated texture path). Opening the page SHALL call `ensureReady()` (or equivalent) without blocking the Settings shell from painting; while not ready, the page SHALL show establishing/failed placeholder UI. A static placeholder or “GStreamer pending” message MUST NOT be accepted as the successful preview state. The page MUST NOT display Camera IP or Preview URL as operator-visible rows. The page MUST NOT offer a manual Retry control for connection/MediaMTX bring-up.

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

### Requirement: IP Camera settings provides a recording demonstration

The Camera settings page SHALL place a Record/Stop control below the live
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
