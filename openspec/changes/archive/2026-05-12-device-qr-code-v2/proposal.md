## Why

Scan-side workflows (mobile pairing, support, inventory) need more than the serial number to validate the correct machine build and software line. V1 encodes only `SN|1`, so scanners cannot distinguish model or installed HMI release without another channel. Adding a versioned payload that includes model and system version keeps backward compatibility for V1 readers while enabling richer binding UX for V2.

## What Changes

- Introduce **device identity QR code format V2**: plaintext payload **`SN|2|Model|SystemVersion`** using the same field delimiter as V1 (`|`).
- Generate V2 QR bitmaps from HMI **Settings → Device Information** (same surface as today), sourcing **SN** from `DeviceIdentity`, **Model** from the same source as device information UI (`DeviceModelConfig` / ROM model), and **SystemVersion** from installed APK `versionName` (aligned with **Device Information → System Version** and `device-app-version-single-source`).
- Retain **V1** generator/API for compatibility (**not BREAKING**); add a V2 entry point or explicit method name so callers choose format.
- Document parsing rules for consumers: fixed segment positions, version segment `2`, escaping rules if delimiter appears in fields (see design).

## Capabilities

### New Capabilities

- `device-identity-qr`: Defines encoding of HMI-shown device identity QR codes (V1 legacy and V2 extended), field sources, delimiter, and scanner-facing parsing expectations.

### Modified Capabilities

- _(none — existing version/model specs are consumed as sources of truth but their requirements do not change.)_

## Impact

- **Android UI**: `DeviceInformationFragment` / QR dialog flow; `DeviceQRCodeUtils` (new V2 content builder; optional parallel `createDeviceIdentityQrCodeV2`).
- **Shared helpers**: `DeviceIdentity`, `DeviceModelConfig`, installed app version resolution (same paths as Settings).
- **External**: Mobile or backend parsers that today split only two segments must detect segment count or version field `2` and extend parsing; V1 QR generation remains available for legacy flows.
