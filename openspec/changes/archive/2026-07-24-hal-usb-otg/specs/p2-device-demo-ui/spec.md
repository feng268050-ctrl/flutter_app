## REMOVED Requirements

### Requirement: Demo exposes LAN SSH debug toggle after HTTP / Proxy

**Reason:** USB OTG mode selection moves to Settings → USB OTG; LAN SSH moves to Settings Network (after Proxy). Demo Debug group is removed.
**Migration:** Use Settings LAN SSH toggle; use Settings → USB OTG for `debug` / `mtp` / `host`.

## MODIFIED Requirements

### Requirement: Demo omits capabilities owned by product Home or Settings

The Demo screen MUST NOT include operator sections for Ethernet, Wi‑Fi, HTTP proxy, Bluetooth, Date & Time, mouse settings, keyboard settings, media volume/play-test, backlight brightness, RGB LED mode controls, host/gun temperature lists, **Debug over USB**, or **Debug over LAN** that product Home or Settings own. Those capabilities SHALL be exercised from product Settings (`settings-ui`) or product Home (`product-home-ui`) as applicable. Demo MAY retain device-information rows and Alarm Information **comm status** rows, and MUST continue to omit display-orientation controls.

#### Scenario: Migrated controls absent on Demo

- **WHEN** the user opens the Demo route after this change
- **THEN** Ethernet, Wi‑Fi, HTTP proxy, Bluetooth, Date & Time, mouse, keyboard, volume, brightness, RGB LED, temperature lists, and Debug USB/LAN toggles are not present as Demo operator sections

#### Scenario: Retained Demo content remains

- **WHEN** the user opens the Demo route after this change
- **THEN** device-information rows and Alarm Information comm-status rows remain available
