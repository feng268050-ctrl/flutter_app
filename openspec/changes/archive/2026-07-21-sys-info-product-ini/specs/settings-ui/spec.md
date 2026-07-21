## MODIFIED Requirements

### Requirement: Device Information shows available identity and version rows

Device Information SHALL display device identity and version rows in **three Material groups** (same chrome as Common Settings: section headers + inset `Card` lists with dividers):

1. **Identity:** Device Model (with device QR affordance), Device SN, Gunhead SN  
2. **Versions:** System Version, Kernel Version, Control Card Version, Laser Version, Wire Feeder Version  
3. **Platform:** Display Stack, Camera Type, and Focus Scale Reference

Device Model SHALL be `brand + " " + model` from HAL product identity (`product.ini`), with each missing part shown as `-`; if both parts are missing (computed value `- -`), the row SHALL display a single `-`. Device SN SHALL use product identity SN resolution (non-empty `product.ini` `sn`, else chip/board serial). Camera Type SHALL come from `product.ini` `camera_type` via HAL (`1` → `Blue Light`, `2` → `Red Light`; empty/invalid → `-`) and SHALL appear immediately before Focus Scale Reference. Focus Scale Reference SHALL come from `product.ini` `focus_scale_ref` via HAL `ProductInfo` (empty → `-`). The tab MUST NOT show a Modbus Link row. Missing or empty values SHALL show `-`. OTA check-update controls MAY be deferred.

#### Scenario: Device Information lists grouped core rows

- **WHEN** the user opens the Device Information tab
- **THEN** Device Model, Device SN, System Version, Display Stack, Camera Type, and Focus Scale Reference rows are visible with a value string (possibly `-`)
- **AND** Device Model appears in the first card before Device SN
- **AND** Display Stack, Camera Type, and Focus Scale Reference appear together in a card below the versions card (Camera Type before Focus Scale Reference)
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

#### Scenario: Camera type from product.ini

- **WHEN** `product.ini` contains `camera_type=1`
- **THEN** Camera Type SHALL display `Blue Light`

#### Scenario: Camera type red light

- **WHEN** `product.ini` contains `camera_type=2`
- **THEN** Camera Type SHALL display `Red Light`

#### Scenario: Focus scale from product.ini

- **WHEN** `product.ini` contains `focus_scale_ref=12`
- **THEN** Focus Scale Reference SHALL display `12`
