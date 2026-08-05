## MODIFIED Requirements

### Requirement: Device Information shows available identity and version rows

Device Information SHALL display device identity and version rows in **untitled CyberUI card groups** (no section header text; same Settings chrome vocabulary as Common Settings):

1. **Identity:** Device Model (with device QR affordance), Device SN, Welding Gun SN  
2. **Versions:** System Version, Process Library Version when available, Firmware Version (control-card / firmware Modbus display), Laser Version, Wire Feeder Version; HMI MAY also show Kernel Version and Display Stack  
3. **Focus:** Focus Scale Reference  

Device Model SHALL be `brand + " " + model` from HAL product identity (Vendor Storage via `ProductInfo`), with each missing part shown as `-`; if both parts are missing (computed value `- -`), the row SHALL display a single `-`. Device SN SHALL use product identity SN resolution (non-empty Vendor Storage SN, else chip/board serial). Focus Scale Reference SHALL come from App-resolved `focus_scale_ref` (`ProductInfo.get` + product default `0`) (empty after defaults still → `-` only if intentionally blanked). Camera Type and Camera Version MUST NOT appear on this tab. The tab MUST NOT show a Modbus Link row. Missing or empty values SHALL show `-`. OTA check-update controls SHALL appear per the Device Information row-set requirement.

#### Scenario: Device Information lists grouped core rows

- **WHEN** the user opens the Device Information tab
- **THEN** Device Model, Device SN, System Version, and Focus Scale Reference rows are visible with a value string (possibly `-`)
- **AND** Device Model appears in the first card before Device SN
- **AND** Focus Scale Reference appears in a card below the versions card
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
- **THEN** a dismissible dialog SHALL show a QR encoding `SN|2|Model|SystemVersion` (v2), with `|` characters in fields replaced by `_`

#### Scenario: Focus scale from properties.ini

- **WHEN** `properties.ini` contains `focus_scale_ref=12`
- **THEN** Focus Scale Reference SHALL display `12`

#### Scenario: Missing focus scale uses App default

- **WHEN** `focus_scale_ref` is absent from `properties.ini`
- **THEN** Focus Scale Reference SHALL display `0`
