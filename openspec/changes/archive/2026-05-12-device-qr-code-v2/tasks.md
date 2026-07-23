## 1. Encoding helpers

- [x] 1.1 Add a small helper (e.g. on `DeviceQRCodeUtils` or a dedicated util) to sanitize QR field strings by replacing ASCII `|` with `_` per design (consistent across SN, Model, SystemVersion).
- [x] 1.2 Add `deviceQrCodeContentV2()` (or equivalent) that resolves SN via `DeviceIdentity.getDeviceSnSafely()`, Model via `DeviceModelConfig.getModel()`, SystemVersion via `PackageManager`/`BuildConfig` pattern aligned with `DeviceInfoViewModel`, applies sanitization, and returns `SN|2|Model|SystemVersion`.

## 2. QR generation API

- [x] 2.1 Implement `createDeviceIdentityQrCodeV2(int widthDp, int heightDp)` delegating to `QRCodeGenerator.generateQRCode` with V2 content (keep existing V1 method unchanged).

## 3. UI wiring

- [x] 3.1 Update `DeviceInformationFragment.openQrCode()` to render the V2 bitmap (call `createDeviceIdentityQrCodeV2`) instead of V1-only.

## 4. Verification

- [x] 4.1 Manually verify on device or emulator: scanned plaintext is four segments, second segment is `2`, model/version match Settings rows for typical builds.
- [x] 4.2 Add or extend a lightweight unit test for payload formatting/sanitization if the project has Android JVM tests for utils (optional if no test harness).
