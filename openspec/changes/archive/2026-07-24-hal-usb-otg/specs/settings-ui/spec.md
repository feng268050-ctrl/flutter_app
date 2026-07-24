## REMOVED Requirements

### Requirement: Settings does not host USB or LAN SSH debug toggles

**Reason:** LAN SSH moves into Settings Network (after Proxy). USB OTG mode is chosen in Settings → Input → USB OTG (not Demo).
**Migration:** Add LAN SSH Settings entry; remove Demo Debug group; Settings USB OTG page for mode.

### Requirement: Global OTG attach uses shared CyberUI mode picker

**Reason:** Insert attach detection and attach-driven mode dialog are abandoned.
**Migration:** Settings → USB OTG segmented mode control; CyberUI dialog MAY remain as optional chrome unused by attach.

## MODIFIED Requirements

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

## ADDED Requirements

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
