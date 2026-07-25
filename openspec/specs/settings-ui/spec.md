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

- Wi‑Fi
- Ethernet (when the product exposes it)
- HTTP Proxy
- **LAN SSH debug** (immediately after HTTP Proxy in the same Network group)
- Bluetooth

LAN SSH debug SHALL control on-demand LAN/WLAN SSH via `SshDebug` (not persisted across reboot as an enabled-at-boot service; default off). USB OTG mode selection lives under Input → USB OTG, not as a Network row.

#### Scenario: Network entries reachable

- **WHEN** the operator opens Common Settings → Network
- **THEN** Wi‑Fi, HTTP Proxy, LAN SSH debug (after Proxy), and Bluetooth entries are available under Network

#### Scenario: LAN SSH toggle enable

- **WHEN** the operator turns LAN SSH debug on from Settings
- **THEN** `SshDebug` is asked to enable LAN SSH debug
### Requirement: Language selection applies UI locale and lists supported endonyms

Language Settings SHALL offer the App-supported locales `en-US`, `zh-CN`, and `zh-TW` with endonym labels (English / 简体中文 / 繁體中文). Selecting a locale SHALL persist via `CommonSettingsStore` and apply both Flutter UI locale and CyberIME language mapping. Language Settings and Common Settings Language summary MUST NOT claim that Language applies only to the soft keyboard once UI localization for that surface has shipped.

#### Scenario: Language page lists three locales

- **WHEN** the operator opens Language Settings
- **THEN** English, 简体中文, and 繁體中文 options are available

#### Scenario: Selecting Simplified Chinese updates UI and summary

- **WHEN** the operator selects 简体中文
- **THEN** the choice is persisted
- **AND** Common Settings Language summary shows the matching endonym
- **AND** migrated Settings chrome uses Simplified Chinese strings

### Requirement: Common Settings exposes display, sound, date-time, and input controls

Common Settings SHALL expose:

- Display & Sound (untitled card): Language and Unit as persisted controls backed by `/var/lib/hmi/common-settings.json`; Language drives Flutter UI locale and CyberIME for three locales; **Display** nav → Brightness (`CyberSlider` / HAL `Backlight`) + Auto Screen Off (dropdown / HAL `AutoSleep`); **Sound** nav → Volume (`CyberVolumeSlider` with speaker icons, left/right row) + Sound Effect (dropdown / `ButtonFeedback`). Order: Language and Unit before Display before Sound.
- RGB LED + Camera (untitled card, after Display & Sound, before Date & Time): RGB LED entry; Camera entry → product IP-camera settings page.
- Date & Time (untitled card): Automatic sync plus Set Date / Set Time / Set Time Zone via `DateTimeController` (lws-ui parity).
- Input (untitled card): mouse settings; keyboard layout; USB OTG. **Camera is not under Input** (see Camera + RGB LED group requirement).
- Operator-visible labels SHALL come from App localization. Group section titles MUST NOT be shown.

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness on Display or volume on Sound
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Screen-off invokes AutoSleep

- **WHEN** the user selects an Auto Screen Off option on the Display page other than the current policy
- **THEN** HAL `AutoSleep` is asked to set the corresponding policy and the choice is persisted

#### Scenario: Sound effect is not a stub

- **WHEN** the user selects a Sound Effect option on the Sound page
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
- **THEN** Camera is reachable from the RGB LED + Camera card before Date & Time
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

### Requirement: Advanced and Custom Home tabs are structurally present

Advanced Settings and Custom Home Page tabs SHALL be reachable in the Settings shell. Advanced Settings SHALL present live product content (see `advanced-settings-ui`). Custom Home Page MAY show an explicit placeholder until drag-layout migration completes.

#### Scenario: Advanced tab opens

- **WHEN** the user selects Advanced Settings
- **THEN** the Advanced tab content is shown with live sections and CyberUI toggles (not placeholder-only)

#### Scenario: Custom Home tab opens

- **WHEN** the user selects Custom Home Page
- **THEN** the Custom Home tab content is shown (live controls and/or a clear placeholder)

### Requirement: Advanced Settings tab is live product content

Once Advanced Settings migration for this change is applied, the Advanced Settings tab SHALL present the live Advanced Settings UI (sections and CyberUI toggles) rather than a placeholder-only pane. Custom Home Page MAY remain a placeholder.

#### Scenario: Advanced is not placeholder-only

- **WHEN** the user opens Advanced Settings after this capability lands
- **THEN** AI Assistance and Dangerous Operations controls are interactive
- **AND** the tab MUST NOT show only the deferred-migration placeholder text

### Requirement: Display & Sound includes RGB LED controls

Common Settings SHALL include an RGB LED entry in an **untitled** card **after** the main Display & Sound controls card (the card that contains language / unit / Display / Sound) and **before** Date & Time, sharing that card with Camera (not as a mid-group row among Display & Sound controls). The entry opens controls for Red, Yellow, and Green modes (Steady / Blink / Off), wired to the GPIO RGB LED controller. LED I/O MUST NOT block Home first paint. No visible “Display & Sound” section title is required.

#### Scenario: LED entry after display-sound group

- **WHEN** the user opens Common Settings
- **THEN** an RGB LED (or equivalent) entry is available in a card after Display & Sound and before Date & Time
- **AND** that card also contains the Camera navigation row

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

### Requirement: Settings text entry uses CyberIME when available

Settings surfaces that collect free text, passwords, or numeric parameters through operator keyboards (at least Wi‑Fi password / connect, HTTP proxy host or port, and one numeric Settings field) SHALL attach a CyberIME session for those fields when `cyber_ime` is a product dependency. Those fields MUST NOT depend on the OEM/system soft keyboard as the primary input method on Linux HMI.

#### Scenario: Wi-Fi password field uses CyberIME

- **WHEN** the operator focuses the Wi‑Fi password field in Settings
- **THEN** the CyberIME keyboard panel is shown for that field type profile
- **AND** committed characters update the password field

#### Scenario: HTTP proxy field uses CyberIME

- **WHEN** the operator focuses an HTTP proxy text or port field that requires keyboard entry
- **THEN** a CyberIME session is attached with the appropriate field type (Text or Number)

### Requirement: Prefer Cyber controls when available

As CyberUI gains switch, checkbox, slider, segmented, stepper, and dialog-host widgets, Settings screens that currently use Material stand-ins for the same role SHALL migrate to the Cyber counterparts in the adoption phase (Phase G), unless a documented exception applies (e.g. platform picker that has no Cyber equivalent yet). **Text / password / numeric keyboard entry SHALL use CyberIME** rather than relying on the system soft keyboard once `cyber_ime` is integrated.

#### Scenario: Volume and sound-effect already on Cyber path

- **WHEN** the operator opens Volume or Sound Effect under Display & Sound after Phase G
- **THEN** those screens use Cyber volume / sound-effect chrome from `cyber_ui` (or documented successor) rather than a one-off Material-only glass kit

#### Scenario: Switch rows use CyberSwitch

- **WHEN** a Settings boolean row that previously used Material `Switch` is migrated in Phase G
- **THEN** that row uses `CyberSwitch` (or package equivalent) rather than raw Material `Switch` alone

#### Scenario: Password entry uses CyberIME

- **WHEN** the operator focuses a Settings password field after CyberIME adoption
- **THEN** input is committed through CyberIME rather than the system soft keyboard alone

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

### Requirement: Keyboard page offers four-layout Segment and preview

Common Settings → Keyboard SHALL present a product layout chooser using `CyberSegmentedControl` for the four profiles (ANSI US, ISO DE, ISO FR, JIS JP) and a typewriter-block preview of the selection. The page MAY retain HID presence / smoke-test affordances as secondary content but MUST NOT rely solely on the Demo `KeyboardDemoSection` as the primary layout UX.

#### Scenario: Keyboard page shows Segment

- **WHEN** the operator opens Settings → Keyboard
- **THEN** a segmented control with the four product profiles is visible
- **AND** a layout preview for the selected profile is visible

### Requirement: Restart persists layout and applies XKB

The Keyboard settings page SHALL provide a single primary **Restart** action after the operator changes the Segment selection. Restart MUST persist the selected profile for CyberIME and XKB preference, restart HMI so physical XKB takes effect, and restore navigation to the Keyboard settings page after relaunch.

#### Scenario: Restart saves and applies

- **WHEN** the operator selects a different profile and taps Restart
- **THEN** the layout preference is persisted
- **AND** HMI restarts and, after relaunch, the App opens the Keyboard settings page
- **AND** soft CyberIME and physical key events follow the persisted layout

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

### Requirement: Settings shell and sub-pages use the CyberUI page status bar

The Settings shell and Settings sub-pages hosted by the shared Settings scaffold SHALL use the CyberUI **page status bar** (leading back, centered title, trailing extensible `CyberHomeStatusBar` + compact clock). For this product’s current icon set the trailing bar SHALL include Wi‑Fi · Bluetooth · camera. Sub-pages MUST inherit this chrome from the shared scaffold so operators see consistent top chrome without per-page one-off AppBars or App-local status-bar forks. Existing Settings body content, tabs, and CyberUI/Material content chrome requirements remain unchanged.

#### Scenario: Settings shell top chrome includes status and clock

- **WHEN** the operator opens Settings
- **THEN** the Settings top chrome is the CyberUI page status bar showing back, the Settings title, this product’s current status icons, and a compact clock

#### Scenario: Settings sub-page scaffold includes status and clock

- **WHEN** the operator opens Common Settings → Wi‑Fi (or another Settings scaffold sub-page)
- **THEN** the sub-page top chrome is the CyberUI page status bar showing back, that page’s title, this product’s current status icons, and a compact clock
### Requirement: Settings Input includes USB OTG mode

Common Settings → Input SHALL include a **USB OTG** entry that lets the operator choose among modes allowed by `/etc/usb-otg.ini` (`debug` / `mtp` / `host`, or debug-only). Choosing a mode SHALL call `UsbOtg.setMode` (persist + apply). The page MUST NOT depend on cable attach/detach events.

#### Scenario: Three modes on ynh960

- **WHEN** the operator opens Settings → Input → USB OTG on ynh960 (`debug_only=false`, `auto_host_support=false`)
- **THEN** Debug, MTP, and Host choices are available

#### Scenario: Selection persists

- **WHEN** the operator selects MTP
- **THEN** `UsbOtg.setMode(mtp)` persists `mode=mtp` and applies MTP gadget behavior

#### Scenario: debug_only locks Debug

- **WHEN** `debug_only=true`
- **THEN** Settings offers only Debug and does not allow switching to mtp/host

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

### Requirement: Common Settings Display and Sound — Display and Sound sub-pages

Within Common Settings, Language and Unit remain as list/nav rows. **Brightness** and **Auto Screen Off** SHALL be merged into a single **Display** nav row. **Volume** and **Sound Effect** SHALL be merged into a single **Sound** nav row. Display SHALL provide Brightness via `CyberSlider` (drag-value chrome) → HAL `Backlight`, and Auto Screen Off as a dropdown → HAL `AutoSleep`. Sound SHALL provide Volume via left-label / right `CyberVolumeSlider` (speaker icons retained; no play-test card) → HAL media audio, and Sound Effect as a dropdown → `ButtonFeedback` / sound-effect store. Language SHALL continue to offer **three** App locales (`en-US`, `zh-CN`, `zh-TW`).

#### Scenario: Display opens brightness and screen-off

- **WHEN** the operator opens Common Settings → Display
- **THEN** Brightness can be adjusted with a CyberSlider
- **AND** Auto Screen Off can be chosen from a dropdown without a separate screen-off page

#### Scenario: Sound opens volume and sound effect

- **WHEN** the operator opens Common Settings → Sound
- **THEN** Volume uses a left-label / right speaker-flanked CyberVolumeSlider
- **AND** Sound Effect can be chosen from a dropdown
- **AND** no music play-test card is shown

#### Scenario: Brightness invokes Backlight

- **WHEN** the operator changes Brightness on the Display page
- **THEN** HAL `Backlight` is asked to set the corresponding percent

#### Scenario: Language still lists three locales

- **WHEN** the operator changes Language on Common Settings
- **THEN** English, 简体中文, and 繁體中文 remain available
- **AND** the choice persists via `CommonSettingsStore` and updates UI locale

### Requirement: Common Settings Date and Time follows Automatic plus conditional rows

Common Settings SHALL present Date & Time in an untitled CyberUI card. The Common Settings nav row SHALL show a trailing **Auto** / **Manual** summary from `DateTimeController` sync mode (`network` → Auto, `manual` → Manual). The Date & Time page SHALL provide an **Automatic** switch and **Set Date** / **Set Time** / **Set Time Zone** rows that open CyberUI dialogs (or equivalent) when Automatic is off, matching lws-ui behavior. A sync status line MAY appear below the card. Controls SHALL use `DateTimeController`.

#### Scenario: Common Settings shows Auto or Manual

- **WHEN** the operator opens Common Settings and sync mode is network
- **THEN** the Date & Time row trailing value is Auto (localized)
- **AND** when sync mode is manual, the trailing value is Manual (localized)

#### Scenario: Automatic hides manual rows

- **WHEN** Automatic is on
- **THEN** Set Date / Set Time / Set Time Zone rows are hidden or disabled per lws-ui parity
- **AND** network time sync policy is enabled via the date/time controller

#### Scenario: Manual date dialog

- **WHEN** Automatic is off and the operator opens Set Date
- **THEN** a CyberUI dialog allows choosing a calendar date and applying it through `DateTimeController`

### Requirement: Camera shares an untitled card with RGB LED (not under Input)

Common Settings SHALL present **Camera** in the same untitled card as **RGB LED**, placed **after** Display & Sound and **before** Date & Time. Camera MUST NOT be nested under Input. The row label SHALL be **Camera** (localized), not “IP Camera”. Tapping SHALL open the Camera settings page (product IP-camera session). Input SHALL retain Mouse, Keyboard, and USB OTG only (no Camera row under Input).

#### Scenario: Camera with RGB LED before Date & Time

- **WHEN** the operator opens Common Settings
- **THEN** RGB LED and Camera navigation rows appear in the same card group
- **AND** that card is after Display & Sound and before Date & Time
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
