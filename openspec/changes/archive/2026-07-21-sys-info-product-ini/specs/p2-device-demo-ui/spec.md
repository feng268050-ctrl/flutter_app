## MODIFIED Requirements

### Requirement: Home screen lists device-info rows

The P2 home (or primary demo) screen SHALL display device-information rows as simple `label: value` text (English labels matching lws-ui Device Information naming where applicable), including at least:

1. Device SN
2. Gunhead SN
3. System Version (Flutter app `versionName`)
4. Kernel Version
5. Control Card Version (Modbus attribute `device.control_card_version`; not “firmware” — that word is reserved for the packaged appliance image)
6. Laser Version
7. Wire Feeder Version

A missing or failed value SHALL display exactly `-`.

Device SN SHALL resolve via product identity (non-empty `/var/lib/hmi/product.ini` `sn`, else chip/board serial / `read-serial` helper) and MUST NOT be read from Modbus. Brand/Model rows MAY be shown when the Demo surface mirrors Settings Device Information; if shown, empty values SHALL display `-`.

#### Scenario: All rows visible

- **WHEN** the user views the P2 demo home after first frame
- **THEN** the listed labels are visible with a value string (possibly `-`)

#### Scenario: Device SN from product identity

- **WHEN** `product.ini` has a non-empty `sn` or board `read-serial` identity is available
- **THEN** Device SN shows that serial string and is NOT read from Modbus

#### Scenario: Device SN unavailable

- **WHEN** product.ini `sn` is empty/absent and chip/`read-serial` identity cannot be obtained
- **THEN** Device SN displays `-`
