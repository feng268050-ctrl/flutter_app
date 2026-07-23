# device-identity-qr Specification

## Purpose

Define the **device identity QR code** payloads emitted by the HMI for pairing and identification, including legacy **V1** and extended **V2** formats.

## Requirements
### Requirement: V1 device identity QR payload remains supported

The HMI SHALL continue to support generation of **V1** QR content as exactly two pipe-separated segments: `{SN}|1`, where `SN` is the string returned by `DeviceIdentity.getDeviceSnSafely()`, the delimiter is ASCII `|`, and the second segment is the literal format version `1`.

#### Scenario: V1 content shape

- **WHEN** the client builds V1 device identity QR text
- **THEN** the payload SHALL match the pattern `{SN}|1` with exactly one delimiter between SN and version
- **AND** V1 SHALL remain available via the existing V1 QR generation API without requiring V2 fields

### Requirement: V2 device identity QR payload includes SN, format version, model, and system version

The HMI SHALL support generation of **V2** QR content as exactly four pipe-separated segments: `{SN}|2|{Model}|{SystemVersion}`.

- **SN** SHALL be sourced from `DeviceIdentity.getDeviceSnSafely()` after producer-side sanitization per the delimiter safety requirement.
- **Model** SHALL be the same machine model string shown in Settings **Device Information** / used for device info defaults (`DeviceModelConfig`), after the same sanitization.
- **SystemVersion** SHALL be the installed HMI application `versionName` from Android package metadata (`PackageManager.getPackageInfo` with `BuildConfig.VERSION_NAME` fallback), after the same sanitization — consistent with the single-source installed app version behavior.

#### Scenario: V2 content shape

- **WHEN** the client builds V2 device identity QR text
- **THEN** the payload SHALL contain exactly three ASCII `|` characters separating four segments in order: SN, literal `2`, Model, SystemVersion

#### Scenario: Settings QR shows V2 payload semantics

- **WHEN** the user opens the device QR preview from Settings device information
- **THEN** the encoded V2 text SHALL use Model and SystemVersion consistent with the visible **Machine Model** and **System Version** rows on that screen (subject to sanitization)

### Requirement: Pipe delimiter safety for QR payloads

For V1 and V2 QR **production**, the HMI MUST NOT emit raw field values that contain the delimiter `|` in a way that changes segment boundaries. Before concatenation, the producer SHALL apply the same sanitization to **SN**, **Model**, and **SystemVersion**: replace each ASCII `|` with ASCII `_` (or remove `|` — implementation MUST choose one strategy and apply it consistently).

#### Scenario: Model containing pipes is sanitized

- **WHEN** the resolved Model string contains at least one `|` character
- **THEN** the V2 QR payload SHALL still contain exactly four logical segments after sanitization
- **AND** the emitted QR SHALL not include unescaped `|` inside SN, Model, or SystemVersion segments

### Requirement: QR bitmap generation uses UTF-8 QR encoding

The client SHALL encode the final plaintext payload into a QR bitmap using the project’s standard QR generator with UTF-8 character set hints (existing behavior), such that Unicode in model/version remains representable after sanitization rules.

#### Scenario: Encoding matches existing generator contract

- **WHEN** V2 plaintext is passed to the QR bitmap generator
- **THEN** encoding SHALL use the same QR code format and charset configuration as other device QR generation paths unless a documented size limit forces an upgrade

### Requirement: Device identity QR display uses FrostedGlassDialog

When the user opens the device identity QR code dialog from Settings Device Information, the dialog SHALL use `FrostedGlassDialog` with the QR image and related content in the custom body slot. V1/V2 QR payload generation semantics MUST NOT change.

#### Scenario: QR dialog on FrostedGlass

- **WHEN** the user requests the device identity QR code from Device Information
- **THEN** the QR dialog MUST render inside `FrostedGlassDialog`
- **AND** MUST NOT use framework `AlertDialog` window chrome as the primary visual container

