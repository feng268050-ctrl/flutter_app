## ADDED Requirements

### Requirement: Product physical layouts include US DE FR JP

`hal/input/keyboard` `listLayouts` used by the product Keyboard settings SHALL include XKB layouts covering at least English US (`us`), German (`de`), French (`fr`), and Japanese (`jp`, with model suitable for JIS such as `jp106`). Display names SHOULD align with the product profile labels. Soft-keyboard rendering remains CyberIME; physical text MUST continue to go through XKB, not Dart scancode remapping.

#### Scenario: listLayouts contains four product ids

- **WHEN** the App calls `listLayouts` for product Keyboard settings
- **THEN** the result includes entries whose ids are `us`, `de`, `fr`, and `jp` (or documented aliases mapped 1:1 to those profiles)

## MODIFIED Requirements

### Requirement: Physical keyboard layout via XKB pref

Physical USB/BT HID keyboard layout SHALL be applied through flutter-pi / libxkbcommon (XKB). `hal/input/keyboard` SHALL expose get/set/list layout APIs that persist layout (via `/etc/default/keyboard` and/or `/var/lib/hmi/keyboard.conf`). For v1, applying a new layout SHALL take effect by restarting flutter-pi / `hmi.service` so XKB is rebuilt at keyboard init. After that restart, the product App SHALL restore navigation to the previous route/page (brief flash is acceptable; most devices rarely change layout). Soft-keyboard layouts remain CyberIME and MUST NOT be implemented as Dart remapping of HID scancodes. A flutter-pi mtime hot-reload path MAY be added later as a non-blocking enhancement. **Product Settings SHALL offer at least the US / DE / FR / JP layouts** corresponding to ANSI / QWERTZ / AZERTY / JIS profiles; Demo-only layouts (e.g. `ru`) MAY remain available to Demo surfaces without appearing in the product Segment.

#### Scenario: US to Russian

- **WHEN** the App calls setLayout for `ru` (or equivalent) with xkeyboard-config present and flutter-pi has been restarted after persist
- **THEN** subsequent physical key events SHALL produce Russian layout characters

#### Scenario: Apply restarts then returns to prior page

- **WHEN** layout preference is changed via HAL in v1
- **THEN** flutter-pi / HMI SHALL restart to apply XKB, and after relaunch the App SHALL open the previous route/page rather than only the default home

#### Scenario: Apply German layout from product profile

- **WHEN** the product Keyboard settings applies the ISO DE profile via HAL setLayout
- **THEN** after HMI restart, physical key events follow the German XKB layout
