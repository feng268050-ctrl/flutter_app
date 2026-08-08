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
- **Cloud services** (云服务; immediately after Bluetooth in the same Network group) — opens the Cloud services sub-page defined by `settings-cloud-services`

LAN SSH debug SHALL control on-demand LAN/WLAN SSH via `SshDebug` (not persisted across reboot as an enabled-at-boot service; default off). USB OTG mode selection lives under Input → USB OTG, not as a Network row. Cloud Worker connectivity and LAN HTTP `:5580`/mDNS MUST NOT appear as always-on implicit behavior; they are controlled from the Cloud services page.

#### Scenario: Network entries reachable

- **WHEN** the operator opens Common Settings → Network
- **THEN** Wi‑Fi, HTTP Proxy, LAN SSH debug (after Proxy), Bluetooth, and Cloud services (after Bluetooth) entries are available under Network

#### Scenario: LAN SSH toggle enable

- **WHEN** the operator turns LAN SSH debug on from Settings
- **THEN** `SshDebug` is asked to enable LAN SSH debug

#### Scenario: Cloud services opens sub-page

- **WHEN** the operator taps Cloud services under Network
- **THEN** the Cloud services settings sub-page is shown

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

- Display & Sound (untitled card): **Country/Region**, Language, and Unit as persisted controls backed by `/var/lib/hmi/common-settings.json`; Country/Region drives wireless regulatory and region-aware timezone/NTP defaults per `region-country-settings`; Language drives Flutter UI locale and CyberIME for three locales; **Display** nav → Brightness (`CyberSlider` / HAL `Backlight`) + Auto Screen Off (dropdown / HAL `AutoSleep`); **Sound** nav → Volume (`CyberVolumeSlider` with speaker icons, left/right row) + Sound Effect (dropdown / `ButtonFeedback`). Order: **Country/Region before Language**, then Unit, then Display, then Sound.
- **Power Mode** (untitled card, **own group**, after Display & Sound and before RGB LED + Camera): a single nav row (same chrome pattern as **Unit**) with trailing summary of the current mode; tapping opens a Power Mode sub-page (see Power Mode requirement). Persistence remains `/var/lib/hal/power.conf` via HAL (not `common-settings.json`).
- RGB LED + Camera (untitled card, after Power Mode, before Date & Time): RGB LED entry; Camera entry → product IP-camera settings page.
- Date & Time (untitled card): Automatic sync plus Set Date / Set Time / Set Time Zone via `DateTimeController` (lws-ui parity).
- Input (untitled card): mouse settings; keyboard layout; USB OTG. **Camera is not under Input** (see Camera + RGB LED group requirement).
- Operator-visible labels SHALL come from App localization. Group section titles MUST NOT be shown.

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness on Display or volume on Sound
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Screen-off invokes AutoSleep

- **WHEN** the user selects an Auto Screen Off option on the Display page other than the current policy
- **THEN** HAL `AutoSleep` is asked to set the corresponding policy and the choice is persisted

#### Scenario: Power Mode group is separate from Display and Sound

- **WHEN** the operator opens Common Settings
- **THEN** Power Mode appears as its own untitled card (not a row inside Display & Sound)
- **AND** that card is after Display & Sound and before RGB LED + Camera

#### Scenario: Sound effect is not a stub

- **WHEN** the user selects a Sound Effect option on the Sound page
- **THEN** Effect 1 / Effect 2 / Effect 3 are selectable and the choice is persisted via `ButtonFeedback`

#### Scenario: Country/Region appears before Language

- **WHEN** the operator opens Common Settings
- **THEN** the Display & Sound card lists Country/Region above Language
- **AND** Country/Region summary reflects the persisted Country preference

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

### Requirement: Common Settings Power Mode nav opens a Unit-style sub-page

Common Settings SHALL present **Power Mode** (localized; en: Power Mode; zh-CN: 效能模式) as a **SettingsNavRow** in its own untitled card. The row SHALL show a trailing summary of the active profile (Performance / Balanced, localized 性能 / 均衡). Tapping SHALL push a dedicated Power Mode settings sub-page (same navigation chrome pattern as **Unit** → `UnitSettingsPage`). The sub-page SHALL list the two options `performance` and `balanced` for selection. Selecting an option SHALL call the HAL load-profile API (persist + apply) and update the in-App continuous-paint policy; the Common Settings trailing summary SHALL refresh to match. Operator-facing copy MUST NOT present the mode primarily as energy saving / 省电.

#### Scenario: Power Mode opens sub-page like Unit

- **WHEN** the operator taps Power Mode on Common Settings
- **THEN** a Power Mode sub-page opens (not an inline dropdown on the Common Settings list)
- **AND** the navigation pattern matches Unit (nav row → push settings page)

#### Scenario: Sub-page lists performance and balanced

- **WHEN** the operator opens the Power Mode sub-page
- **THEN** Performance (性能) and Balanced (均衡) options are available
- **AND** selecting Balanced invokes HAL setMode(`balanced`) and persists `/var/lib/hal/power.conf`
- **AND** returning to Common Settings shows the Balanced trailing summary

### Requirement: Country/Region selection lists all markets and applies region effects

Country/Region Settings SHALL list the full ISO 3166-1 alpha-2 country/territory catalog (plus `XK`) with human-readable labels (English / Simplified Chinese by UI locale) and search. Selecting a country SHALL persist via `CommonSettingsStore` and trigger region apply (wireless regulatory and Country-linked timezone/NTP defaults). Common Settings Country/Region summary MUST show the selected country label (or code). Country/Region MUST appear as a nav row before Language on the Common Settings Display & Sound card. Operator-visible title SHALL be Country/Region (zh: 国家/地区).

#### Scenario: Country page lists options with US default summary

- **WHEN** Country preference is `US` and the operator opens Common Settings
- **THEN** Country/Region summary indicates United States (or localized equivalent)
- **AND** opening Country/Region Settings shows `US` among the selectable options

#### Scenario: Selecting Germany updates summary and apply path

- **WHEN** the operator selects Germany (`DE`) on Country/Region Settings
- **THEN** the choice is persisted
- **AND** Common Settings Country/Region summary shows the matching label
- **AND** region apply runs for regulatory / linked clock defaults

### Requirement: Device Information shows available identity and version rows

Device Information SHALL display device identity and version rows in **untitled CyberUI card groups** (no section header text; same Settings chrome vocabulary as Common Settings), in this order:

1. **Identity:** Device Model (with device QR affordance), Device SN  
2. **Versions:** **OS Version** (navigation into System Upgrade), **HMI Version** (navigation into HMI Upgrade), Camera Version, Firmware Version (control-card / firmware Modbus display, navigation into Control Board Upgrade), Laser Version, Wire Feeder Version, **Auto-Check for Updates** (master switch, last row)  
3. **Storage:** used/available capacity with an iOS-style segmented bar (see Device Information storage requirement)  
4. **Accessory:** Welding Gun SN, Focus Scale Reference  

Device Model SHALL be `brand + " " + model` from HAL product identity (Vendor Storage via `ProductInfo`), with each missing part shown as `-`; if both parts are missing (computed value `- -`), the row SHALL display a single `-`. Device SN SHALL use product identity SN resolution (non-empty Vendor Storage SN, else chip/board serial). Focus Scale Reference SHALL come from App-resolved `focus_scale_ref` (`ProductInfo.get` + product default `0`) (empty after defaults still → `-` only if intentionally blanked). Camera Version SHALL use the same normalized camera software version as Camera settings (shared cache / bounded device-info read), or `-` when unavailable. Camera Type MUST NOT appear on this tab. Kernel Version and Process Library Version MUST NOT appear on this tab (Kernel on System Upgrade; Process Library on HMI Upgrade). The tab MUST NOT show a Modbus Link row. Missing or empty values SHALL show `-`. Manual **Check for Updates** SHALL live on System Upgrade / HMI Upgrade / peripheral upgrade pages; the **Auto-Check for Updates** master switch SHALL live on Device Information Versions (not as checkboxes on those upgrade pages).

#### Scenario: Device Information lists regrouped core rows

- **WHEN** the user opens the Device Information tab
- **THEN** Device Model and Device SN appear in the first card
- **AND** OS Version and HMI Version appear in the versions card
- **AND** Auto-Check for Updates is the last row of the versions card
- **AND** Kernel Version and Process Library Version are not shown on Device Information
- **AND** a storage card with a capacity bar is visible after the versions card
- **AND** Welding Gun SN and Focus Scale Reference appear together in the last card
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
- **THEN** a dismissible dialog SHALL show a QR encoding the documented v2 identity payload (including version fields as specified by device-registration / remote snapshot after the OS/HMI split), with `|` characters in fields replaced by `_`

#### Scenario: Focus scale from properties.ini

- **WHEN** `properties.ini` contains `focus_scale_ref=12`
- **THEN** Focus Scale Reference SHALL display `12`

#### Scenario: Missing focus scale uses App default

- **WHEN** `focus_scale_ref` is absent from `properties.ini`
- **THEN** Focus Scale Reference SHALL display the App default (`0` unless product docs say otherwise)

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

As CyberUI gains switch, checkbox, slider, segmented, stepper, and dialog-host widgets, Settings screens that currently use Material stand-ins for the same role SHALL migrate to the Cyber counterparts in the adoption phase (Phase G), unless a documented exception applies (e.g. platform picker that has no Cyber equivalent yet). **Text / password / numeric keyboard entry SHALL use CyberIME** rather than relying on the system soft keyboard once `cyber_ime` is integrated. Settings boolean rows and checkboxes that are already on Cyber MUST remain on `CyberSwitch` / `CyberCheckbox` (large tier 28 for checkbox faces) and MUST NOT regress to Material `Switch` / `Checkbox`.

#### Scenario: Volume and sound-effect already on Cyber path

- **WHEN** the operator opens Volume or Sound Effect under Display & Sound after Phase G
- **THEN** those screens use Cyber volume / sound-effect chrome from `cyber_ui` (or documented successor) rather than a one-off Material-only glass kit

#### Scenario: Switch rows use CyberSwitch

- **WHEN** a Settings boolean row that previously used Material `Switch` is migrated in Phase G
- **THEN** that row uses `CyberSwitch` (or package equivalent) rather than raw Material `Switch` alone

#### Scenario: Password entry uses CyberIME

- **WHEN** the operator focuses a Settings password field after CyberIME adoption
- **THEN** input is committed through CyberIME rather than the system soft keyboard alone

#### Scenario: Settings checkbox stays Cyber large

- **WHEN** a Settings row presents a checkbox control
- **THEN** it uses `CyberCheckbox` at `CyberDimens.checkboxLargeSize` (28)

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

Common Settings → Keyboard SHALL present a product layout chooser using `CyberSegmentedControl` for the three soft profiles (QWERTY, QWERTZ, AZERTY) and a phone soft-keyboard preview of the selection (same layout factory as live CyberIME). The page MAY retain HID presence / smoke-test affordances as secondary content but MUST NOT rely solely on the Demo `KeyboardDemoSection` as the primary layout UX. Default / typewriter-block / JIS preview chrome MUST NOT be shown.

#### Scenario: Keyboard page shows Segment

- **WHEN** the operator opens Settings → Keyboard
- **THEN** a segmented control with the four product profiles is visible
- **AND** a soft keyboard layout preview for the selected profile is visible

### Requirement: Restart persists layout and applies XKB

The Keyboard settings page SHALL provide a single primary **Restart** action after the operator changes the Segment selection. Restart MUST persist the selected profile for CyberIME and XKB preference, restart HMI so physical XKB takes effect, and restore navigation to the Keyboard settings page after relaunch.

#### Scenario: Restart saves and applies

- **WHEN** the operator selects a different profile and taps Restart
- **THEN** the layout preference is persisted
- **AND** HMI restarts and, after relaunch, the App opens the Keyboard settings page
- **AND** soft CyberIME and physical key events follow the persisted layout

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

Within Common Settings, Language and Unit remain as list/nav rows. **Brightness** and **Auto Screen Off** SHALL be merged into a single **Display** nav row. **Volume** and **Sound Effect** SHALL be merged into a single **Sound** nav row. Display SHALL provide Brightness via `CyberSlider` (drag-value chrome) → HAL `Backlight`, and Auto Screen Off as a dropdown → HAL `AutoSleep`. Sound SHALL provide Volume via left-label / right `CyberVolumeSlider` (speaker icons retained; no play-test card) → HAL media audio, and Sound Effect as a dropdown → `ButtonFeedback` / sound-effect store. Language SHALL continue to offer **three** App locales (`en-US`, `zh-CN`, `zh-TW`). Power Mode / load-profile selection MUST NOT live on the Display sub-page (see Power Mode requirement).

#### Scenario: Display opens brightness and screen-off

- **WHEN** the operator opens Common Settings → Display
- **THEN** Brightness can be adjusted with a CyberSlider
- **AND** Auto Screen Off can be chosen from a dropdown without a separate screen-off page
- **AND** the Display page MUST NOT host the Power Mode / performance / balanced selector

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

Common Settings SHALL present **Camera** in the same untitled card as **RGB LED**, placed **after** Power Mode (and Display & Sound) and **before** Date & Time. Camera MUST NOT be nested under Input. The row label SHALL be **Camera** (localized), not “IP Camera”. Tapping SHALL open the Camera settings page (product IP-camera session). Input SHALL retain Mouse, Keyboard, and USB OTG only (no Camera row under Input).

#### Scenario: Camera with RGB LED before Date & Time

- **WHEN** the operator opens Common Settings
- **THEN** RGB LED and Camera navigation rows appear in the same card group
- **AND** that card is after Power Mode and before Date & Time
- **AND** the Input card group does not list Camera / IP Camera

#### Scenario: Camera label

- **WHEN** Language is `en-US`
- **THEN** the Camera row title is `Camera`

### Requirement: Device Information card set (model QR, versions, focus; no camera type)

Device Information SHALL show CyberUI untitled cards with:

1. Identity: Device Model (QR), Device SN  
2. Versions: **OS Version**, **HMI Version**, Camera Version, Firmware Version (existing control-card / firmware Modbus value), Laser Version, Wire Feeder Version, **Auto-Check for Updates** (switch, last)  
3. Storage: iOS-style capacity bar with `{used} of {total} used` summary and HAL `SysInfo.storage` (System = GPT system partitions; Available = `/userdata` free)  
4. Accessory (last): Welding Gun SN, Focus Scale Reference  

Device Information MUST NOT show Camera Type. Device Information MUST NOT show Kernel Version or Process Library Version. Device Information SHALL expose **OS Version** as a navigation row into **System Upgrade** and **HMI Version** as a navigation row into **HMI Upgrade**. Manual Check for Updates SHALL live on System Upgrade, HMI Upgrade, and peripheral upgrade pages. **Auto-Check for Updates** SHALL be the Device Information Versions master switch and SHALL gate Product Home auto tips plus auto-check-on-open for System / HMI / control-board / camera upgrade pages. Auto-check MUST NOT auto-apply. Check for Updates SHALL fetch public CDN `release.json` manifests and MUST NOT require cloud services enabled or a pinned Worker API origin; when the CDN is unreachable, the check outcome MUST show failed/unavailable (not a false “up to date”). They MUST NOT report a false success, and MUST NOT remain permanently deferred/unavailable once whole-device OTA is implemented on the device image. Device Model QR and registration flows SHALL share the v2 identity payload. Cloud environment tier MUST be changed via Device SN 5×-tap (not a permanent Settings row).

#### Scenario: No Camera Type on Device Information

- **WHEN** the operator opens Device Information
- **THEN** Camera Type is not listed
- **AND** Camera Version is listed in the versions card
- **AND** Welding Gun SN and Focus Scale Reference remain visible in the last card

#### Scenario: Welding Gun SN present

- **WHEN** the operator opens Device Information
- **THEN** a Welding Gun SN (or localized equivalent) row is visible with a value or `-`
- **AND** it appears in the last card with Focus Scale Reference

#### Scenario: OS Version opens System Upgrade

- **WHEN** the operator activates the OS Version row on Device Information
- **THEN** System Upgrade is shown (shared Settings scaffold)

#### Scenario: HMI Version opens HMI Upgrade

- **WHEN** the operator activates the HMI Version row on Device Information
- **THEN** HMI Upgrade is shown (shared Settings scaffold)

#### Scenario: Check works when cloud services off

- **WHEN** cloud services are disabled and the operator activates Check for Updates on System Upgrade and the CDN manifest is reachable
- **THEN** System Upgrade runs the check against `https://cdn.lasercyber.com/{artifact}/release.json`
- **AND** MUST NOT claim the check is unavailable solely because cloud services are off

#### Scenario: No permanent cloud environment row

- **WHEN** the operator opens Device Information
- **THEN** there is no always-visible Cloud Environment settings row

#### Scenario: Kernel and process library leave Device Information

- **WHEN** the operator opens Device Information
- **THEN** Kernel Version is not listed
- **AND** Process Library Version is not listed

### Requirement: System Upgrade uses CyberUI Settings chrome

System Upgrade SHALL use the shared **Settings scaffold** and a content **SettingsPanel** that fills the remaining viewport height below the status bar (same blur / transparency / margins as other Settings pages). When not in progress-only / apply mode, the card SHALL include current **OS Version**, **Kernel Version** (value or `-`), and **Check for Updates**; check outcomes and Update Now / Later SHALL render in the card (not dialogs). **Process Library Version MUST NOT appear on System Upgrade**. The Auto-Check for Updates switch MUST NOT appear on System Upgrade (it lives on Device Information). Apply progress SHALL use the same full-height card. Host `make upgrade` SHALL use progress-only (no check footer); progress-only mode is not required to show Kernel rows.

#### Scenario: Upgrade scaffold matches Settings

- **WHEN** the operator opens System Upgrade from Device Information OS Version
- **THEN** the top chrome is the CyberUI page status bar with back and the System Upgrade title
- **AND** the content card fills remaining height with Settings / CyberUI panel chrome

#### Scenario: Check mode shows kernel but not process library

- **WHEN** the operator opens System Upgrade in check mode (not progress-only)
- **THEN** Kernel Version is visible with a value string (possibly `-`)
- **AND** OS Version remains visible
- **AND** Process Library Version is not listed

### Requirement: RGB LED Settings forces Off on enter

When the operator opens the Common Settings RGB LED page, the App SHALL suppress production RGB LED policy for the duration of the page, force red/yellow/green to Off, and present Off as the selected mode for each color until the operator chooses Steady or Blink. Leaving the page SHALL end the suppress and allow production policy to refresh.

#### Scenario: Settings entry resets indicators

- **WHEN** the operator navigates to the RGB LED settings page
- **THEN** all three colors are forced Off
- **AND** production alarm/standby/ready policy does not overwrite manual selections while the page remains open

#### Scenario: Leaving settings resumes policy

- **WHEN** the operator leaves the RGB LED settings page
- **THEN** production policy resumes and reapplies computed modes

### Requirement: Device Information changes cloud environment tier via Device SN 5×-tap

Device Information SHALL NOT show a permanent Cloud Environment row. The operator SHALL open the app environment tier picker by tapping the **Device SN** value five times within five seconds (lws-ui `SecretTapTracker` parity). The picker SHALL offer at least Test and Prod, and MAY offer Dev. Choosing a tier MUST persist the selection and trigger a fresh API-origin probe / WebSocket reconnect when cloud runtime is active. Manual Check for Updates on System Upgrade / peripheral pages uses public CDN `release.json` URLs and is independent of this tier picker (tier affects Worker API for 云服务 only); Auto-Check for Updates remains the Device Information Versions master switch.

#### Scenario: Five taps on Device SN opens tier picker

- **WHEN** the operator taps Device SN five times within five seconds
- **THEN** the cloud environment tier picker is shown

#### Scenario: Idle between taps resets the counter

- **WHEN** more than five seconds elapse between taps on Device SN
- **THEN** the tap counter resets and five new taps are required

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

### Requirement: Device Information shows storage capacity with an iOS-style bar

Device Information SHALL include an untitled storage card after the versions card and before the accessory card. The card SHALL present:

- A capacity summary line in the form **`{used} of {total} used`** (localized; human units such as `GB` / `MB`), placed below the Storage title and above the bar
- A single horizontal rounded **segmented bar** (iOS Settings storage style): colored **System** and **User Data** segments plus a trailing **Available** segment, with a legend
- System / User Data / Available legend labels with human-readable sizes

**Accounting (HAL `SysInfo.storage`):**

- **System** SHALL be the sum of full block sizes of board system GPT partitions (default PARTNAMEs: uboot, misc, boot, boot_b, recovery, backup, rootfs_a, rootfs_b, oem, private, private1, vendor0–3), not merely active `/` filesystem used space
- **User Data** SHALL be used space on `/userdata`
- **Available** SHALL be free space on `/userdata` only

When storage data is unavailable, the card SHALL still render without crashing and SHALL show `-` or an equivalent unavailable presentation. The storage card MUST NOT offer delete/clear actions in this change.

#### Scenario: Storage bar visible after versions

- **WHEN** the operator opens Device Information and HAL reports storage totals
- **THEN** a storage card appears below the versions card and above Welding Gun SN / Focus Scale Reference
- **AND** a summary line in the `{used} of {total} used` form is visible
- **AND** a segmented System / User Data / Available bar is visible

#### Scenario: System includes oem and other GPT system partitions

- **WHEN** HAL can read GPT part-label sizes for system partitions including `oem` and both `rootfs_a` / `rootfs_b`
- **THEN** the System segment size reflects the sum of those partition block sizes (and the other default system PARTNAMEs when present)
- **AND** Available does not include free space on `/`

#### Scenario: Storage unavailable soft-fails

- **WHEN** storage totals are missing from the SysInfo snapshot
- **THEN** Device Information still paints
- **AND** the storage presentation shows unavailable (`-` or equivalent) rather than crashing

