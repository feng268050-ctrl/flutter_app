## REMOVED Requirements

### Requirement: Home status bar shows USB icon for gadget OTG modes

**Reason:** Cable attach/detach detection on ynh960 is unreliable; product abandons status-bar USB connection icon and attach-driven push.
**Migration:** Operators select mode in Settings → USB OTG only; no Home USB glyph.

## ADDED Requirements

### Requirement: Home status bar has no USB OTG attach icon

Product Home’s CyberUI status-bar strip MUST NOT show a USB OTG attach/connection icon driven by cable presence or `UsbOtg` attach APIs. Wi‑Fi, Bluetooth, and camera status icons remain unchanged.

#### Scenario: No USB glyph in strip

- **WHEN** Home status-bar items are composed
- **THEN** the strip does not include a USB OTG connection icon
