## Context

Today `DeviceQRCodeUtils` builds V1 QR content as `DeviceIdentity.getDeviceSnSafely() + "|" + "1"` and renders it via ZXing (`QRCodeGenerator`). Settings shows **Machine Model** from `DeviceModelConfig` and **System Version** from installed APK `versionName`—the same sources documented for LAN discovery TXT `model` and `system_version`. Pairing flows that only scan QR currently lack model/version unless they use mDNS or manual entry.

## Goals / Non-Goals

**Goals:**

- Encode **V2** payload **`SN|2|Model|SystemVersion`** with stable field order and explicit format version `2`.
- Source **SN** from `DeviceIdentity` (same as V1). Source **Model** from the same configuration path as Settings device model (`DeviceModelConfig`). Source **SystemVersion** from installed HMI app `versionName` (`PackageManager` / `BuildConfig` fallback), consistent with **device-app-version-single-source**.
- Keep **V1** generation available for legacy scanners and docs.
- Define delimiter and sanitization so payloads remain parseable as plain text.

**Non-Goals:**

- Changing backend or mobile apps (this change is HMI-side encoding only; consumers updated separately).
- Replacing mDNS or WebSocket discovery; QR remains an alternate binding channel.
- QR styling (logo, colors) beyond existing bitmap generation unless required for size limits.

## Decisions

1. **Payload shape** — Fixed four segments separated by ASCII `|` (reuse `DeviceQRCodeUtils.DELIMITER`): segment 1 = SN, 2 = format version literal `2`, 3 = Model, 4 = SystemVersion. **Rationale:** Matches user contract and aligns with V1 (`SN|1`). **Alternative considered:** JSON — rejected for size, escaping complexity, and consistency with existing pipe format.

2. **API surface** — Add `createDeviceIdentityQrCodeV2(int widthDp, int heightDp)` (and optionally `deviceQrCodeContentV2()` for testing) alongside existing `createDeviceIdentityQrCodeV1`. Call sites that should show the richer QR switch to V2. **Rationale:** Explicit versioning avoids silently changing scanned strings. **Alternative:** Single method with parameter — acceptable follow-up; two methods mirror existing `V1` naming.

3. **Model and version strings** — Resolve Model via `DeviceModelConfig.getModel()` (same as `DeviceInfoViewModel` defaults path). Resolve SystemVersion via `PackageManager.getPackageInfo(...).versionName` with `BuildConfig.VERSION_NAME` fallback. **Rationale:** Matches UI labels and discovery docs.

4. **Delimiter collision** — If any field contains `|`, splitting becomes ambiguous. **Decision:** Producer SHALL substitute `\|` → not standard in plain QR; simpler approach: **replace** each `|` in SN, Model, and SystemVersion with `_` (or empty) before concatenation, OR strip characters — pick **replace `|` with `_`** for visibility in support tickets. Document in spec. **Alternative:** Reject QR generation if unsafe — worse UX on exotic SNs.

5. **QR dialog** — `DeviceInformationFragment.openQrCode()` switches from V1-only to **V2** as the default shown QR (per user request for V2 implementation). If product needs both, add UI later — out of scope unless tasks specify.

## Risks / Trade-offs

- **[Risk]** Scanners expecting exactly two segments (`SN|1`) break if pointed at V2 without logic updates. **Mitigation:** Keep V1 API; document transition; parsers should branch on segment count or index 2 == `2`.
- **[Risk]** Sanitizing `|` changes canonical SN string in QR vs hardware SN. **Mitigation:** Rare SNs with `|`; log once in debug; spec calls out substitution rule for QR-only transport.
- **[Trade-off]** Long model strings increase QR density — ZXing handles typical lengths; very long strings may need higher error correction later.

## Migration Plan

1. Ship HMI with V2 QR generation and updated docs (`docs/` or pairing doc pointer).
2. Mobile/backend: parse V2 when segment count ≥ 4 and second segment is `2`; fall back to V1 parsing otherwise.
3. Rollback: revert call site to `createDeviceIdentityQrCodeV1` without removing V2 helpers.

## Open Questions

- Whether **Settings UI** should expose “copy QR text” or show V1/V2 toggle — defer to product; default implementation uses V2 bitmap only.
