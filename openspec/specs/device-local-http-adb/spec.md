# device-local-http-adb Specification

## Purpose
TBD - created by archiving change device-http-adb-endpoint. Update Purpose after archive.
## Requirements
### Requirement: ADB remote debug HTTP endpoint

The system SHALL expose **`POST /v1/adb`** on the embedded local HTTP server (`0.0.0.0:5580`; port **8080** deprecated). The request SHALL NOT require a body. The handler SHALL invoke **`AdbRemoteDebugHelper.enableRemoteDebugging`** with application context — the **same** enablement path used after five consecutive **System Version** taps in **Settings → Device Information** (`SecretTapTracker` + background executor in `DeviceInformationFragment`). That path SHALL:

- Set **`Settings.Global.ADB_ENABLED`** to enabled.
- Configure network ADB TCP port **`5555`** via `setprop service.adb.tcp.port` and `setprop persist.adb.tcp.port`.
- Restart **`adbd`** via root shell (`stop adbd` / `start adbd`).

The response SHALL use the standard **`ApiResult`** JSON envelope. On logical success, HTTP status MUST be **200**, **`success`** MUST be **`true`**, **`code`** MUST be **200**, and **`data`** MUST be **`null`**. On logical failure, the response MUST be **`ApiResult`** failure with a diagnosable **`message`** (for example **`adb_enable_failed`**) and **`data`** MUST be **`null`**.

#### Scenario: Enable ADB via HTTP

- **WHEN** a client sends `POST /v1/adb` while `AdbRemoteDebugHelper.enableRemoteDebugging` succeeds
- **THEN** the response status MUST be 200
- **AND** `success` MUST be true
- **AND** `data` MUST be null
- **AND** network ADB MUST listen on TCP port 5555 per the shared helper behavior

#### Scenario: Enable ADB failure

- **WHEN** a client sends `POST /v1/adb` and `AdbRemoteDebugHelper.enableRemoteDebugging` returns false
- **THEN** the response MUST be `ApiResult` failure with `success` false and `message` identifying enablement failure (for example `adb_enable_failed`)
- **AND** `data` MUST be null

#### Scenario: Wrong HTTP method

- **WHEN** a client sends `GET`, `PUT`, or `DELETE` to `/v1/adb`
- **THEN** the server MUST NOT return a successful ADB-enable `ApiResult` for that request

#### Scenario: Same behavior as System Version secret tap

- **WHEN** ADB is enabled via `POST /v1/adb` and when enabled via five **System Version** taps within the secret tap window
- **THEN** both paths MUST call the same `AdbRemoteDebugHelper.enableRemoteDebugging` implementation
- **AND** both MUST apply the same `Settings.Global`, `setprop`, and `adbd` restart steps

