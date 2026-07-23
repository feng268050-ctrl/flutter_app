## Why

LAN tools and support workflows already use the device embedded HTTP API on port **5580**, but enabling network ADB still requires a physical operator to open **Settings → Device Information** and tap **System Version** five times within a short window. Remote enablement over the same LAN trust model removes that hidden UI step while keeping the identical low-level ADB setup (USB debugging on, TCP port **5555**, `adbd` restart).

## What Changes

- Add **`POST /v1/adb`** on `DeviceLocalHttpServer` (`0.0.0.0:5580`).
- The handler SHALL invoke the **same** `AdbRemoteDebugHelper.enableRemoteDebugging` path used after five consecutive **System Version** taps in `DeviceInformationFragment` (no request body required).
- On logical success, respond with standard **`ApiResult`** where **`success: true`**, HTTP **200**, and **`data`** is **`null`**.
- On failure (for example `Settings.Global` write or root shell steps fail), respond with **`ApiResult`** failure and a diagnosable **`message`** (for example `adb_enable_failed`).
- Document the endpoint in `docs/network-api-reference.md`.
- Non-goals: TLS or auth on local HTTP (same LAN trust model as other `/v1/*` routes), changing the hidden five-tap UI gesture, exposing ADB port or credentials in the response body, cloud Worker exposure.

## Capabilities

### New Capabilities

- `device-local-http-adb`: Embedded route `POST /v1/adb`, `ApiResult` contract (`data: null` on success), shared `AdbRemoteDebugHelper` orchestration with the System Version secret tap, error handling, and documentation.

### Modified Capabilities

- `device-local-http-api`: Extend LAN HTTP surface requirements to include `POST /v1/adb` alongside existing `/v1/*` routes.

## Impact

- **Code**: `DeviceLocalHttpServer` (new route + handler), reuse `AdbRemoteDebugHelper`; optional small JVM test mirroring other local HTTP route probes.
- **Dependencies**: Existing root shell utilities (`ShellCmdUtil`), Android `Settings.Global.ADB_ENABLED`; no new cloud APIs.
- **Security**: Same implicit LAN trust as other local HTTP controls; enables `adb connect <device-ip>:5555` when successful.
- **Network**: `http://<device-lan-ip>:5580/v1/adb`; response does not echo TCP port (clients use default **5555** per existing helper).
- **Docs**: `docs/network-api-reference.md`, OpenSpec delta under `device-local-http-api`.
