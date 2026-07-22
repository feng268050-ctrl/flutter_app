## ADDED Requirements

### Requirement: Monitor shell uses the CyberUI page status bar

The Monitor screen shell SHALL use the CyberUI **page status bar** (leading back, centered title, trailing extensible `CyberHomeStatusBar` + compact clock) rather than a bare back-and-title AppBar or an App-local status-bar fork. For this product’s current icon set the trailing bar SHALL include Wi‑Fi · Bluetooth · camera. Monitor tab content and `AppBar.bottom` tab strip behavior remain as specified elsewhere in this capability; the page status bar applies to the top chrome row only.

#### Scenario: Monitor top chrome includes status and clock

- **WHEN** the operator opens Monitor
- **THEN** the Monitor top chrome is the CyberUI page status bar showing back, the Monitor title, this product’s current status icons, and a compact clock
- **AND** Monitor tabs remain available beneath that chrome as today
