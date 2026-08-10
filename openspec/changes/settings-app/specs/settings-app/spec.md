## ADDED Requirements

### Requirement: Settings app installs as non-HMI Flutter bundle

The repository SHALL include Flutter project `app/settings` (Flutter API pin **3.41.9**) with path dependencies on `cyber_hal`, `cyber_ui`, and `cyber_ime`. Building with `APP=settings make build-app` SHALL install a release AOT tree under overlay/device `/opt/settings` containing `lib/libapp.so` and `data/flutter_assets`, and MUST NOT embed `libflutter_engine.so`, `icudtl.dat`, or Flutter JIT blobs under that prefix. Settings SHALL load OEM `board_profile` via HAL and MUST NOT load product `gpio.json` / `modbus.json` assets.

#### Scenario: Analyze and build settings

- **WHEN** the developer runs Flutter analyze on `app/settings` against the pinned SDK and `APP=settings make build-app`
- **THEN** analyze passes and overlay `/opt/settings` has release AOT layout without engine/ICU/JIT orphans

#### Scenario: No product register maps

- **WHEN** Settings starts on device
- **THEN** it MUST NOT require product gpio/modbus App assets to paint the top-level list

### Requirement: Settings top-level IA is a flat ordered list

The Settings app SHALL present a single ordered top-level list of platform entries matching the product plan order: About, Operating System, Storage, Wi‑Fi, Ethernet, Bluetooth, Proxy, SSH, Date & Time, Country/Region, Language, Unit, Display, Sound, Power Mode, Keyboard, Mouse, USB OTG. Logical plan group names (Basic Info, Network, …) MUST NOT render as operator-visible section headers. Landscape SHALL use master-detail (sidebar + detail); portrait SHALL use root list → push detail, switching at a single breakpoint (one App, not two).

#### Scenario: Flat list without group headers

- **WHEN** the operator opens Settings on either orientation
- **THEN** the listed top-level rows are reachable in plan order
- **AND** no Basic Info / Network / Date / Display / Input section header labels are shown

#### Scenario: Landscape master-detail

- **WHEN** the display is landscape beyond the breakpoint
- **THEN** selecting a top-level row shows its detail beside the list without replacing the whole shell

### Requirement: About Operating System and Storage pages

Settings SHALL provide:

- **About**: Brand, Model, Serial Number from product identity / HAL (same sources as HMI Device Info identity).
- **Operating System**: list summary `OS + version` from `/etc/os-release`; detail rows for Operating System, Linux Kernel, SELinux (`Disabled` \| `Permissive` \| `Enforcing`), BusyBox, Glibc, WPA Supplicant, BlueZ, OpenSSL, OpenSSH, GStreamer, Flutter, Buildroot versions via HAL probes. Any missing probe SHALL display `—` and MUST NOT crash the App.
- **Storage**: summary `n GB of m GB used`; detail with storage capacity UI plus **Secrets Seal** showing `software` or `op-tee` from HAL secrets backend status (read-only; no migrate wizard required).

#### Scenario: Missing version soft-fails

- **WHEN** a platform version probe fails or returns empty
- **THEN** that Operating System row shows `—` and Settings remains usable

#### Scenario: Secrets Seal status

- **WHEN** the operator opens Storage
- **THEN** Secrets Seal shows `software` or `op-tee` matching the active HAL secrets backend identifier

### Requirement: Copy and migrate platform feature ownership

Settings SHALL implement platform features per copy/migrate rules:

- **Copy** (also remain in product HMI Settings): Wi‑Fi, Proxy, Date & Time, Country/Region, Language, Unit, Display, Sound, Power Mode (from HMI General; HAL `/var/lib/hal/power.conf`), and About identity reads.
- **Migrate** (Settings owns; product HMI MUST remove pages/nav after Settings ships them): Ethernet, Bluetooth, SSH, Keyboard, Mouse, USB OTG.

Copied and migrated pages SHALL use the same HAL persistence paths as today’s HMI implementations (`/var/lib/hal/…` and existing network/input helpers). Product-only HMI surfaces (Advanced, Custom Home, cloud services, camera/control-board versions, process, HMI App OTA) MUST NOT appear in Settings.

#### Scenario: Migrated feature in Settings

- **WHEN** Settings Network/Input pages for Ethernet, Bluetooth, SSH, Keyboard, Mouse, and USB OTG are shipped
- **THEN** those controls are operable from Settings via HAL
- **AND** product HMI Settings MUST NOT still expose those six entries (see `settings-ui` delta)

#### Scenario: Copied Wi-Fi remains dual

- **WHEN** Settings Wi‑Fi is implemented
- **THEN** product HMI Common Settings MAY continue to expose Wi‑Fi against the same HAL store

#### Scenario: Copied Power Mode remains dual

- **WHEN** Settings Power Mode is implemented from HMI General
- **THEN** product HMI Common Settings MUST continue to expose Power Mode against `/var/lib/hal/power.conf`

### Requirement: Bluetooth local name is Brand space Model

When Settings applies the local Bluetooth adapter alias (on Bluetooth stack start and when product identity becomes readable), the display name / BlueZ Alias SHALL be `"{Brand} {Model}"` (single ASCII space) from Vendor Storage identity via HAL. When Brand or Model is missing, Settings SHALL fall back to a safe placeholder (Model-only or existing HAL default) and MUST NOT hardcode welding product marketing strings as the permanent target alias.

#### Scenario: Alias from identity

- **WHEN** Brand is `Acme` and Model is `Panel-X` and Settings enables Bluetooth
- **THEN** the adapter alias becomes `Acme Panel-X`

### Requirement: Exit returns to product HMI

Settings SHALL expose a prominent Exit (or “return to product UI”) control that invokes `switch-to-hmi` / starts `hmi.service`. Exit is the UI path that restores HMI after a Settings session started via switch.

#### Scenario: Exit starts HMI

- **WHEN** the operator taps Exit in Settings while `settings.service` is the active seat
- **THEN** `hmi.service` is started (Conflicts stops Settings) and the product HMI becomes the foreground UI
