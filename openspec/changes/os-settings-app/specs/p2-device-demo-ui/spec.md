## MODIFIED Requirements

### Requirement: Demo omits capabilities owned by product Home or Settings

The Demo screen MUST NOT include operator sections for Ethernet, Wi‑Fi, HTTP proxy, Bluetooth, Date & Time, mouse settings, keyboard settings, media volume/play-test, backlight brightness, RGB LED mode controls, host/gun temperature lists, **Debug over USB**, **Debug over LAN**, or USB OTG that product Home, product Settings (`settings-ui`), or the platform Settings app (`settings-app`) own. Those capabilities SHALL be exercised from product Settings, platform Settings, or product Home as applicable. Demo MAY retain device-information rows and Alarm Information **comm status** rows, and MUST continue to omit display-orientation controls. When Demo retains no operator value beyond those rows, the product MAY remove the Demo route entirely.

#### Scenario: Migrated controls absent on Demo

- **WHEN** the user opens the Demo route after this change
- **THEN** Ethernet, Wi‑Fi, HTTP proxy, Bluetooth, Date & Time, mouse, keyboard, volume, brightness, RGB LED, temperature lists, Debug USB/LAN, and USB OTG toggles are not present as Demo operator sections

#### Scenario: Retained Demo content remains

- **WHEN** the user opens the Demo route after this change and Demo has not been deleted
- **THEN** device-information rows and Alarm Information comm-status rows remain available
