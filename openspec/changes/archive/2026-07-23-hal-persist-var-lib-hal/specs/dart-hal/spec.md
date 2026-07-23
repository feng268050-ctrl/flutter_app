## MODIFIED Requirements

### Requirement: Backend taxonomy

Every HAL module SHALL declare exactly one primary backend kind: **device/sysfs**, **D-Bus**, or **OS component/helper**. Volume SHALL bind ALSA mixer (card/control) plus preference path, NOT a volume device node. Prefs under `/var/lib/hal/*` (and App prefs under `/var/lib/hmi/*` when App-owned) SHALL be treated as policy storage for restore, not as device files.

#### Scenario: Volume is mixer not device

- **WHEN** an App constructs the volume API
- **THEN** constructor/bindings SHALL accept ALSA card/control (and optional pref path) and MUST NOT require a char-device path for volume

### Requirement: Persist cohesion with existing FHS

HAL mid-session writes SHALL use `/var/lib/{wpa_supplicant,network,bluetooth,hal}/` (and documented helpers) for platform state. HMI App-owned stores remain under `/var/lib/hmi/`. HAL SHALL NOT invent a parallel preference tree (e.g. `/var/lib/hal-alt/`) that breaks `settings-restore.service`. Boot restore of Wi‑Fi, ethernet, Bluetooth, backlight, volume, and **system proxy** MAY remain shell/systemd-owned. System proxy persist SHALL live under `/var/lib/network/` (see `hal-network-proxy`), not under `/var/lib/hal/` or a legacy `/var/lib/hmi/http-proxy` primary path.

#### Scenario: Reboot still restores Wi‑Fi

- **WHEN** Wi‑Fi was enabled via HAL and the device reboots
- **THEN** existing restore hooks SHALL still bring the stack back when `wifi-wanted` (or equivalent) is set

### Requirement: Physical keyboard layout via XKB pref

Physical USB/BT HID keyboard layout SHALL be applied through flutter-pi / libxkbcommon (XKB). `hal/input/keyboard` SHALL expose get/set/list layout APIs that persist layout (via `/etc/default/keyboard` and/or `/var/lib/hal/keyboard.conf`). For v1, applying a new layout SHALL take effect by restarting flutter-pi / `hmi.service` so XKB is rebuilt at keyboard init. After that restart, the product App SHALL restore navigation to the previous route/page (brief flash is acceptable; most devices rarely change layout). Soft-keyboard layouts remain CyberIME and MUST NOT be implemented as Dart remapping of HID scancodes. A flutter-pi mtime hot-reload path MAY be added later as a non-blocking enhancement. **Product Settings SHALL offer at least the US / DE / FR / JP layouts** corresponding to ANSI / QWERTZ / AZERTY / JIS profiles; Demo-only layouts (e.g. `ru`) MAY remain available to Demo surfaces without appearing in the product Segment.

#### Scenario: US to Russian

- **WHEN** the App calls setLayout for `ru` (or equivalent) with xkeyboard-config present and flutter-pi has been restarted after persist
- **THEN** subsequent physical key events SHALL produce Russian layout characters

#### Scenario: Apply restarts then returns to prior page

- **WHEN** layout preference is changed via HAL in v1
- **THEN** flutter-pi / HMI SHALL restart to apply XKB, and after relaunch the App SHALL open the previous route/page rather than only the default home

#### Scenario: Apply German layout from product profile

- **WHEN** the product Keyboard settings applies the ISO DE profile via HAL setLayout
- **THEN** after HMI restart, physical key events follow the German XKB layout

### Requirement: Mouse settings via existing pref contract

`hal/input/mouse` SHALL formalize the P2.1 mouse preference contract: settings persist in `/var/lib/hal/mouse.conf` and are applied through `apply-mouse-settings` (or equivalent injectable helper); flutter-pi SHALL continue to reload on file mtime without `SIGHUP` or HMI restart. Supported keys SHALL include at least `natural_scroll`, `scroll_speed`, `pointer_speed`, `pointer_size`, `primary_button`, and `pointer_axes`. Presence SHALL be observed via `/dev/input/by-id` (with documented fallbacks). The HAL MUST NOT synthesize pointer events in Dart and MUST NOT introduce a parallel preference tree. Bluetooth pairing/HOGP remains outside mouse (stays bluetooth).

#### Scenario: Settings apply without restart

- **WHEN** the App changes natural scroll or pointer speed via HAL
- **THEN** flutter-pi SHALL pick up `/var/lib/hal/mouse.conf` via mtime poll and apply without restarting `hmi.service`

#### Scenario: Package migration preserves conf

- **WHEN** Demo migrates to `hal/input/mouse`
- **THEN** existing on-device `mouse.conf` contents SHALL remain valid and readable/writable through the HAL API

### Requirement: Industry-style public API

Portable HAL public types SHALL use system-service vocabulary including at least: `Capabilities` / `BoardInfo`; under `hal/network`: network device/role APIs plus `ProxySettings`; under `hal/output`: **display** (`Backlight`, `AutoSleep`, **`Orientation`**) and **sound** (`Volume`, `ButtonFeedback`); under `hal/input`: keyboard and mouse; `hal/gpio`; `hal/modbus`; under `hal/debug`: SSH and USB debug; `BluetoothManager` / related; `TimeService`; `SysInfo`. Implementation types (`Linux*`, `*Backend`) MUST NOT be required by product App code. Temporary `*Controller` wrappers MAY exist during migration. The HAL package MUST NOT expose a top-level `hal/http` module. Long-term public layout SHALL use grouped packages where decided (`hal/output`, `hal/input`, `hal/network`, `hal/debug`) and top-level `hal/gpio` / `hal/modbus` (not under an `io`/`media` umbrella). URL probe UI stays in the App. System proxy policy SHALL live under `hal/network/proxy`. Panel orientation SHALL live under `hal/output/display` (not a top-level `hal/orientation` entrypoint). Embedder/stack detection (`DisplayStack`) SHALL live under `hal/sys_info`. The package MUST NOT expose a top-level `hal/display` / `package:cyber_hal/display.dart` entrypoint.

#### Scenario: New integration uses network module

- **WHEN** a new Settings page integrates Wi‑Fi through HAL
- **THEN** documented imports SHALL be under `package:cyber_hal/network` (e.g. wifi subpackage), not a new portable type whose primary name is `WifiController`

#### Scenario: Orientation under output display

- **WHEN** a product App sets panel orientation
- **THEN** it SHALL import `package:cyber_hal/output/display/orientation.dart` (or `output/display.dart`) and MUST NOT use a top-level `hal/orientation` module

### Requirement: DisplayStack under sys_info

Embedder/stack detection (`DisplayStack`, probe helpers, and mouse-setting availability gates derived from the stack) SHALL be exported from `package:cyber_hal/sys_info.dart`. Product Apps MUST NOT import a top-level `package:cyber_hal/display.dart`. Default stamp paths SHALL be `/run/display-stack` (runtime) and `/etc/display-stack` (image), not under `/run/hmi/` or `/etc/hmi/`.

#### Scenario: App resolves stack via sys_info

- **WHEN** Settings needs the active display stack label or mouse-knob gates
- **THEN** it SHALL obtain `DisplayStack` through `sys_info` (or `BoardBindings.displayStack`) without importing `cyber_hal/display.dart`

#### Scenario: Probe defaults are OS paths

- **WHEN** `DisplayStackProbe` is constructed with default paths
- **THEN** it reads `/run/display-stack` then `/etc/display-stack`

### Requirement: Domain package grouping

Related capabilities SHALL be grouped under domain packages with optional sub-imports where naming fits: `hal/network` {ethernet, wifi, proxy}; `hal/output` {**display** {backlight, auto-sleep, **orientation**}, **sound** {volume, button-feedback}}; `hal/input` {keyboard, mouse}; `hal/debug` {ssh, usb}. `hal/gpio` and `hal/modbus` SHALL remain separate top-level modules. Apps MUST be able to import a single subpackage without pulling unused siblings.

#### Scenario: Volume without backlight

- **WHEN** a product App needs only volume
- **THEN** it SHALL be able to import `hal/output/sound/volume` (or `hal/output/sound`) without importing backlight / auto-sleep / orientation

#### Scenario: Orientation without volume

- **WHEN** a product App needs only panel orientation
- **THEN** it SHALL be able to import `hal/output/display/orientation` (or `hal/output/display`) without importing volume / button-feedback

#### Scenario: Gpio without modbus

- **WHEN** a product App needs only gpio lines
- **THEN** it SHALL import `hal/gpio` and MUST NOT be required to depend on `hal/modbus`

## REMOVED Requirements

### Requirement: No portable orientation HAL

**Reason:** Panel orientation is shared OS/HAL policy across Apps and display stacks (flutter-pi and Weston). Leaving it as an App-only façade blocked multi-App reuse.

**Migration:** Use `Orientation` under `hal/output/display`; Linux applies via `change-orientation` + `hmi.service` restart; `hmi-launch.sh` remains the stack-specific mapper. Temporary in-App media layout rotation stays product UI. Demo UI for orientation remains optional (not required by this change).

## ADDED Requirements

### Requirement: DisplayStack stamps use OS paths

`DisplayStackProbe` (and board launch/post-build writers) SHALL use:

- **Image stamp:** `/etc/display-stack` (baked by rootfs post-build; `weston` XOR `flutter-pi`)
- **Runtime stamp:** `/run/display-stack` (written when the embedder path is chosen)

Detection priority remains: runtime stamp → image stamp → `WAYLAND_DISPLAY` / platform fallbacks. Tokens (`weston` / `wayland` / `elinux` / `flutter-pi` / …) are unchanged. Writers MUST NOT use `/etc/hmi/display-stack` or `/run/hmi/display-stack` as the primary path. Probe MAY read those legacy paths only as a one-shot fallback when the new stamps are absent.

#### Scenario: Runtime stamp wins

- **WHEN** `/run/display-stack` contains `weston` and `/etc/display-stack` contains `flutter-pi`
- **THEN** `DisplayStackProbe.detect` returns Weston

#### Scenario: Image stamp when runtime missing

- **WHEN** `/run/display-stack` is absent and `/etc/display-stack` contains `flutter-pi`
- **THEN** detect returns flutter-pi

#### Scenario: Legacy stamp fallback

- **WHEN** `/etc/display-stack` and `/run/display-stack` are absent but `/etc/hmi/display-stack` contains `weston`
- **THEN** detect MAY return Weston via legacy fallback
