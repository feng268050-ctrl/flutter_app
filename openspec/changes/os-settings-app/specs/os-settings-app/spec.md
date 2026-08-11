## ADDED Requirements

### Requirement: OS Settings app installs as non-HMI Flutter bundle

The repository SHALL include Flutter project `app/os_settings` (Flutter API pin **3.41.9**) with path dependencies on `cyber_hal`, `cyber_ui`, and `cyber_ime`. Building with `APP=os_settings make build-app` SHALL install a release AOT tree under overlay/device `/opt/os_settings` containing `lib/libapp.so` and `data/flutter_assets`, and MUST NOT embed `libflutter_engine.so`, `icudtl.dat`, or Flutter JIT blobs under that prefix. OS Settings SHALL load OEM `board_profile` via HAL and MUST NOT load product `gpio.json` / `modbus.json` assets.

#### Scenario: Analyze and build os_settings

- **WHEN** the developer runs Flutter analyze on `app/os_settings` against the pinned SDK and `APP=os_settings make build-app`
- **THEN** analyze passes and overlay `/opt/os_settings` has release AOT layout without engine/ICU/JIT orphans

#### Scenario: No product register maps

- **WHEN** OS Settings starts on device
- **THEN** it MUST NOT require product gpio/modbus App assets to paint the top-level list

### Requirement: OS Settings top-level IA is multi-card untitled frost like HMI General

The OS Settings app SHALL present platform entries as **multiple untitled frosted SettingsGroup cards**. Logical group names MUST NOT render as operator-visible section headers. Card contents and order SHALL be:

1. Basic Info: About, Operating System, Storage  
2. Network: Wi‑Fi, Ethernet, Bluetooth, Proxy, SSH, **Cloud Environment**  
3. Date & Time: Date & Time  
4. Locale: Country/Region, Language, Unit  
5. Display & Sound: Display, Sound, Power Mode  
6. Input: Keyboard, Mouse, USB OTG  

Chrome SHALL match product HMI Device Info / General Settings: frosted plates, `SettingsNavRow` → push detail, `SettingsScrollView` top-only padding. Landscape and portrait SHALL use the **same** list→push layout (MUST NOT use master-detail).

#### Scenario: Multi-card list without group header labels

- **WHEN** the operator opens OS Settings on either orientation
- **THEN** the listed top-level rows are reachable in plan order inside untitled frosted cards matching the six logical groups
- **AND** no Basic Info / Network / Date / Locale / Display / Input section header labels are shown
- **AND** Cloud Environment is present in the Network card after SSH

#### Scenario: Single layout landscape and portrait

- **WHEN** the display is landscape or portrait
- **THEN** selecting a top-level row pushes its detail page over the root list
- **AND** the shell MUST NOT present a persistent sidebar + detail master-detail split

### Requirement: About Operating System and Storage pages

OS Settings SHALL provide:

- **About**: Brand, Model, Serial Number from product identity / HAL.
- **Operating System**: list summary from `/etc/os-release`; detail rows for Operating System, Linux Kernel, SELinux (`Disabled` \| `Permissive` \| `Enforcing`), BusyBox, Glibc, WPA Supplicant, BlueZ, OpenSSL, OpenSSH, GStreamer, Flutter, Buildroot via HAL probes. Missing → `—`, MUST NOT crash.
- **Storage**: capacity UI (used / total bar). Secrets Seal is **not** on Storage.
- **Operating System**: grouped inventory; the first **Platform** group MUST NOT show a section title. **Security** includes SELinux / OpenSSL / OpenSSH plus **Secrets Seal** `software` \| `op-tee` (read-only).

#### Scenario: Missing version soft-fails

- **WHEN** a platform version probe fails or returns empty
- **THEN** that Operating System row shows `—` and Settings remains usable

#### Scenario: Secrets Seal status

- **WHEN** the operator opens Operating System → Security
- **THEN** Secrets Seal shows `software` or `op-tee` matching the active HAL secrets backend identifier

#### Scenario: Platform group has no section title

- **WHEN** the operator opens Operating System
- **THEN** the first Platform inventory group is shown without a "Platform" section header

### Requirement: Copy migrate and OS-only platform feature ownership

OS Settings SHALL implement platform features per:

- **Copy** (remain in product HMI Settings): Wi‑Fi, Proxy, Date & Time, Country/Region, Language, Unit, Display (brightness / auto-sleep / wallpaper; **not** UI Scale), Sound volume, About identity reads. **Copy** means presentation parity (same Settings chrome/structure), not thin HAL stubs.
- **Migrate** (OS Settings owns; HMI MUST remove Settings entry): Ethernet, Bluetooth, SSH, Keyboard, Mouse, USB OTG, Power Mode (`/var/lib/hal/power.conf`).
- **OS-only** (not in HMI Settings): UI Scale, Cloud Environment, Operating System inventory, Secrets Seal row.

Copied/migrated/OS-only pages SHALL use HAL / system paths under `/var/lib/hal/…`, `/var/lib/network/…` (including Cloud Environment at `/var/lib/network/cloud.conf`), and Bluetooth state paths. OS Settings **MUST NOT** read or write `/var/lib/hmi/common-settings.json`. Product-only HMI surfaces (Advanced, Custom Home, product cloud services, camera business, process, HMI App OTA, text size) MUST NOT appear in OS Settings. Product HMI cloud opt-in toggles MAY remain under `/var/lib/hmi/cloud-settings.json` (not the shared API env tier).

#### Scenario: Migrated feature in Settings

- **WHEN** migrated Network/Input/Power Mode pages are shipped
- **THEN** those controls are operable from OS Settings via HAL
- **AND** product HMI Settings MUST NOT still expose those migrated entries

#### Scenario: Copied Wi-Fi remains dual

- **WHEN** OS Settings Wi‑Fi is implemented
- **THEN** product HMI Common Settings MAY continue to expose Wi‑Fi against the same HAL store

#### Scenario: Power Mode is OS Settings only

- **WHEN** OS Settings Power Mode is shipped
- **THEN** product HMI Common Settings MUST NOT expose a Power Mode Settings entry
- **AND** product HMI MAY still read `/var/lib/hal/power.conf` for continuous-paint / motion policy

#### Scenario: No common-settings.json from OS Settings

- **WHEN** the operator changes Language, Unit, Region, Display, Sound, Power Mode, or UI Scale in OS Settings
- **THEN** persistence MUST NOT write `/var/lib/hmi/common-settings.json`

### Requirement: Ethernet page matches Wi-Fi Details IPv4 and DNS interaction

OS Settings Ethernet SHALL present:

1. Untitled group: interface **switch** with **cable link** status as a value row under the switch when the interface is on.
2. Shared **IPv4 Address** section: Configure IP Automatic/Manual segmented control; Automatic shows read-only IP / subnet / gateway; Manual shows nav rows that open IME editors.
3. Shared **DNS** section: Configure DNS Automatic/Manual; Automatic shows live DNS; Manual lists up to three editable servers plus add control.
4. Others: MAC address, link speed.

The page MUST NOT expose a separate “Configure IP” group whose only job is navigating into DHCP vs Manual as a distinct flow. IPv4/DNS chrome SHALL be reusable with Wi‑Fi Details (shared widget or equivalent). HAL Ethernet IPv4 config SHALL support DNS mode + server list independently of DHCP vs static address mode.

#### Scenario: Cable link under switch

- **WHEN** Ethernet is enabled
- **THEN** cable link status appears in the same group under the Ethernet switch
- **AND** no separate top-level “Link only” card is required for that status

#### Scenario: Manual IPv4 inline edit

- **WHEN** the operator selects Manual under IPv4 Address
- **THEN** IP Address, Subnet Mask, and Gateway are editable via IME from nav rows
- **AND** there is no intermediate Configure IP destination page for mode alone

#### Scenario: Shared groups with Wi-Fi Details

- **WHEN** Wi‑Fi Details and Ethernet both show IPv4/DNS
- **THEN** both use the same Automatic/Manual + inline-edit interaction pattern

### Requirement: Display includes UI Scale with physical 1.0 identity

OS Settings Display SHALL expose brightness, auto-sleep, wallpaper (as implemented), and **UI Scale** persisted at `/var/lib/hal/display.conf` key `ui_scale` (range supporting non-integers e.g. `0.85`–`1.25`). **`ui_scale=1.0` (default) SHALL mean physical 1:1** — both OS Settings and product HMI MUST apply `matchEmbedderDensity` such that **no** FittedBox rematch runs when the effective scale is `1.0` (including simulator / QEMU). Non-`1.0` values SHALL multiply the embedder MediaQuery only. Product HMI MUST NOT expose a UI Scale slider. Host/QEMU operators MAY set ~`1.13` manually for former ynh960 rematch parity; Apps MUST NOT hard-code that factor when `ui_scale` is `1.0`.

#### Scenario: UI scale 1.0 is identity

- **WHEN** `ui_scale` is `1.0` or absent (defaults to `1.0`)
- **THEN** neither seat applies design-density FittedBox rematch from `matchEmbedderDensity`

#### Scenario: UI scale shared across seats

- **WHEN** field service sets UI scale to `1.10` in OS Settings Display
- **AND** switches to product HMI
- **THEN** HMI reads `ui_scale=1.10` and applies the same multiplier

### Requirement: Cloud Environment tier in Network

OS Settings Network SHALL include **Cloud Environment** (Production default / Test) persisted at `/var/lib/network/cloud.conf` (`environment_tier=`). HAL `CloudApiOriginProber` SHALL select Worker/hyurl candidates from this tier; product HMI and other Apps MUST use the resulting pin when connecting. HMI MUST NOT expose the env-tier picker (product cloud toggles remain HMI-only under `/var/lib/hmi/cloud-settings.json`).

#### Scenario: Tier persists for HMI cloud

- **WHEN** the operator selects Test in OS Settings Cloud Environment
- **THEN** `/var/lib/network/cloud.conf` records the test tier
- **AND** product HMI cloud clients honor that tier on subsequent connect

### Requirement: Sound is volume only

OS Settings Sound SHALL expose media volume only. It MUST NOT bundle product click MP3 catalogs or a sound-effect picker. Click playback MAY use samples installed by product HMI beside `sound.conf` via HAL.

#### Scenario: No effect picker in OS Settings

- **WHEN** the operator opens OS Settings Sound
- **THEN** volume is adjustable
- **AND** Effect 1/2/3 picker is not present

### Requirement: Power Mode page under Display and Sound

OS Settings SHALL present **Power Mode** under Display & Sound with options `performance` / `balanced` via HAL load-profile (`/var/lib/hal/power.conf`). Operator copy MUST NOT present the mode primarily as energy saving / 省电.

#### Scenario: Balanced persists

- **WHEN** the operator selects Balanced on OS Settings Power Mode
- **THEN** HAL setMode(`balanced`) runs and `/var/lib/hal/power.conf` contains `mode=balanced`

### Requirement: Bluetooth local name is Brand space Model

When Settings applies the local Bluetooth adapter alias (on Bluetooth stack start and when product identity becomes readable), the display name / BlueZ Alias SHALL be `"{Brand} {Model}"` (single ASCII space) from Vendor Storage identity via HAL. When Brand or Model is missing, Settings SHALL fall back to a safe placeholder and MUST NOT hardcode welding product marketing strings as the permanent target alias.

#### Scenario: Alias from identity

- **WHEN** Brand is `Acme` and Model is `Panel-X` and OS Settings enables Bluetooth
- **THEN** the adapter alias becomes `Acme Panel-X`

### Requirement: Seat switch preserves platform stacks

Switching between `hmi.service` and `os-settings.service` MUST NOT disable or tear down Wi‑Fi, Ethernet, Bluetooth, HTTP proxy, or LAN SSH debug. Both Apps are UI only.

#### Scenario: Wi-Fi survives seat switch

- **WHEN** Wi‑Fi is associated under HMI and the operator switches to OS Settings
- **THEN** association remains up and OS Settings Wi‑Fi UI reflects live state after sync

### Requirement: Exit returns to product HMI

OS Settings SHALL expose a prominent Exit control that invokes `switch-to-hmi` / starts `hmi.service`. Chrome SHALL use cyber_ui status bar patterns (not a one-off Material AppBar).

#### Scenario: Exit starts HMI

- **WHEN** the operator taps Exit in OS Settings while `os-settings.service` is the active seat
- **THEN** `hmi.service` is started (Conflicts stops Settings) and the product HMI becomes the foreground UI
