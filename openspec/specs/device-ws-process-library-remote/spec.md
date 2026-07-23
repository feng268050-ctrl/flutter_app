## Purpose

Define device-side WebSocket commands for remote management of engineer-mode process library entries in `t_process_parameters_data`: list, get, create, update, delete (custom only), and set active preset. Row primary keys use string JSON on the wire for JavaScript-safe integers.

## Requirements

### Requirement: WebSocket row id as string for JavaScript clients

Room primary keys and **`originId`** values exceed JavaScript safe integer range when serialized as JSON numbers. For **all process-library WebSocket messages** in this capability:

- **Inbound** `payload` fields **`id`** and **`originId`** (when present) SHALL be accepted as either a JSON **number** or a JSON **string** containing a base-10 integer. The device SHALL parse them to `long` for Room access. Non-numeric strings, empty strings, or values that overflow `long` SHALL be treated as invalid id and MUST yield failure (ack `success` false or empty/null response data as applicable).
- **Outbound** JSON for list summaries, full parameter objects, and create ack **`payload.data.id`** SHALL serialize **`id`** and **`originId`** as **strings** (decimal digits), not JSON numbers, even when the value fits in JS safe integer range.

**HTTP** routes under `/v1/process-parameters*` are unchanged: path `:id` and `ApiResult` bodies MAY use numeric `id` (camelCase) per local HTTP conventions.

#### Scenario: Inbound id as string

- **WHEN** `command.process_parameters_request` has `payload.id` equal to string `"9007199254740991"`
- **THEN** the device MUST load the row with primary key `9007199254740991` if it exists

#### Scenario: Inbound id as number

- **WHEN** `command.process_parameters_set_default` has `payload.id` equal to number `42`
- **THEN** the device MUST accept the id the same as string `"42"`

#### Scenario: Outbound list id is string

- **WHEN** the device sends `command.process_library_response` for a row with primary key `12345`
- **THEN** each summary object in `payload.data` MUST have `"id": "12345"` (string), not a JSON number

#### Scenario: Invalid string id

- **WHEN** `command.process_parameters_delete` has `payload.id` equal to `"abc"`
- **THEN** the device MUST send `command.process_parameters_delete_ack` with `success` false

### Requirement: Inbound process library list request

Inbound frames with `type` **`command.process_library_request`** SHALL use the unified WebSocket envelope. The `payload` object SHALL be present and SHALL include integer field **`process_type`** (工艺类型, `ModelConstant` 0–5). The device SHALL query engineer-mode rows only: **`dataType`** **`1`**（工程师模式常用参数 / `ENGINEER_MODE_DATA`）, matching **`processType`**, ordered by stable row order (e.g. primary key or name). Legacy rows with **`dataType`** **`2`** (`ENGINEER_MODE_CUSTOM_DATA`, deprecated) MAY be included in results until migrated, treated as engineer common presets. **`0`** 快速模式参数与 **`3`** 视频工艺参数（废弃）MUST NOT appear.

#### Scenario: Valid list request

- **WHEN** the server sends `command.process_library_request` with top-level `id` `req-lib-1` and `payload.process_type` equal to `1`
- **THEN** the device MUST accept the frame when WebSocket state is **ONLINE** and MUST respond with `command.process_library_response`

#### Scenario: Missing process_type

- **WHEN** `command.process_library_request` omits `process_type` or it is not a number
- **THEN** the device MUST NOT query with an undefined filter and MUST send `command.process_library_response` with `data` as an empty array or MUST document failure via empty list plus log (SHALL NOT crash)

### Requirement: Outbound process library list response

After handling `command.process_library_request`, the device SHALL send **`command.process_library_response`** with a **new** top-level `id`, millisecond `ts`, and `payload` containing:

- string **`request_id`** equal to the inbound frame’s top-level `id`
- array **`data`** of summary objects, each with camelCase fields: **`id`** (string), **`name`**, **`dataType`**, **`processType`**, **`materialType`**, **`materialName`** (nullable strings/numbers as stored)

#### Scenario: Response correlates to inbound id

- **WHEN** the device receives `command.process_library_request` with top-level `id` `req-lib-1`
- **THEN** `command.process_library_response` MUST have `payload.request_id` equal to `req-lib-1` and a newly generated outbound top-level `id`

#### Scenario: List excludes non-engineer rows

- **WHEN** the database contains `dataType` **`0`**（快速模式参数）or **`3`**（视频工艺参数，废弃）rows for the same `processType`
- **THEN** those rows MUST NOT appear in `payload.data`

### Requirement: Inbound process parameters get request

Inbound frames with `type` **`command.process_parameters_request`** SHALL include **`id`** in `payload` (local Room primary key, string or number per WebSocket row id rule). The device SHALL load the row by id.

#### Scenario: Valid get request

- **WHEN** the server sends `command.process_parameters_request` with `payload.id` matching an engineer-mode row
- **THEN** the device MUST send `command.process_parameters_response` whose `payload.data` is the full parameter object with camelCase Gson field names

#### Scenario: Unknown id

- **WHEN** no row exists for `payload.id`
- **THEN** the device MUST send `command.process_parameters_response` with `payload.data` null or omit data per implementation, and SHOULD log; clients treat missing row as not found

### Requirement: Outbound process parameters get response

The device SHALL send **`command.process_parameters_response`** with `payload.request_id` (inbound top-level `id`) and object **`data`** (full `ProcessParametersData` serialization with **`id`** and **`originId`** as strings, or null when not found).

#### Scenario: Response uses new outbound id

- **WHEN** inbound top-level `id` is `req-get-1`
- **THEN** outbound top-level `id` MUST be newly generated and `payload.request_id` MUST be `req-get-1`

### Requirement: Inbound process parameters create

Inbound frames with `type` **`command.process_parameters_create`** SHALL carry create fields in `payload` using snake_case for **`process_type`** and camelCase or snake_case for other fields consistent with existing WS conventions: at minimum **`process_type`** (required), optional **`name`**, **`material_type`**, **`material_name`**, and remaining process fields mirroring `ProcessParametersData`. The device SHALL set **`dataType`** to **`ENGINEER_MODE_DATA`** (`1`), SHALL assign **`id`** via insert, and SHALL set **`processType`** from **`process_type`**.

#### Scenario: Successful create

- **WHEN** `command.process_parameters_create` includes valid `process_type` and insert succeeds
- **THEN** the device MUST send `command.process_parameters_create_ack` with `payload.data.success` true and SHOULD include string **`id`** of the new row in `payload.data`

### Requirement: Inbound process parameters update

Inbound frames with `type` **`command.process_parameters_update`** SHALL include **`id`** in `payload` (string or number) plus updatable fields. The device SHALL update only rows that exist and belong to engineer-mode data types; **`processType`** on the row MUST NOT be changed to a different type than stored unless payload explicitly includes matching `process_type`.

#### Scenario: Successful update

- **WHEN** `payload.id` references an existing engineer-mode row and update succeeds
- **THEN** the device MUST send `command.process_parameters_update_ack` with `payload.data.success` true

#### Scenario: Update unknown id

- **WHEN** `payload.id` does not exist
- **THEN** `command.process_parameters_update_ack` MUST have `payload.data.success` false and non-empty `message`

### Requirement: Inbound process parameters delete

Inbound frames with `type` **`command.process_parameters_delete`** SHALL include **`id`** in `payload` (string or number). The device SHALL delete the row when it exists and has engineer-mode **`dataType`** **`1`** (`ENGINEER_MODE_DATA`) or legacy deprecated **`2`**.

#### Scenario: Delete engineer common preset

- **WHEN** `payload.id` references an engineer-mode common preset row (`dataType` **`1`** or legacy **`2`**)
- **THEN** the device MUST delete the row and MUST send `command.process_parameters_delete_ack` with `success` true

#### Scenario: Reject delete quick-mode row

- **WHEN** `payload.id` references `dataType` **`0`**（快速模式参数）
- **THEN** the device MUST NOT delete the row and MUST send ack with `success` false

### Requirement: Inbound process parameters set default

Inbound frames with `type` **`command.process_parameters_set_default`** SHALL include **`id`** in `payload` only (string or number; no other business fields required). The device SHALL load the row by **`id`**, reject when missing or not engineer-mode (`dataType` **`1`** or legacy **`2`**), then SHALL set the active engineer preset for that row’s **`processType`** (memory cache key `ENGINEER_DATA_CACHE_KEY + processType`, same behavior as UI `switchProcessParametersData`).

#### Scenario: Set active preset

- **WHEN** `payload.id` references an existing engineer-mode row
- **THEN** the device MUST send `command.process_parameters_set_default_ack` with `success` true and subsequent `device.online` / `command.stat_response` snapshots for that `processType` SHOULD reflect the selected row when it is the active preset

#### Scenario: Unknown id

- **WHEN** no row exists for `payload.id`
- **THEN** ack MUST have `success` false and a non-empty `message`

### Requirement: Outbound mutation acknowledgments

For **`command.process_parameters_create_ack`**, **`command.process_parameters_update_ack`**, **`command.process_parameters_delete_ack`**, and **`command.process_parameters_set_default_ack`**, the device SHALL use the same acknowledgment shape as **`command.upload_video_ack`**:

- new top-level `id`
- `payload.request_id` equal to inbound top-level `id`
- `payload.data` object with boolean **`success`** and string **`message`**
- on successful **create**, `payload.data` MAY additionally include string **`id`** (new row primary key, decimal string)

#### Scenario: Ack correlation

- **WHEN** inbound `command.process_parameters_delete` has top-level `id` `req-del-2`
- **THEN** `command.process_parameters_delete_ack` MUST set `payload.request_id` to `req-del-2`

### Requirement: Off-main-thread process library WebSocket handling

All database and cache work for the process-library WebSocket commands SHALL run on a background executor, not on the Android main thread.

#### Scenario: List handler does not block UI

- **WHEN** `command.process_library_request` is processed
- **THEN** Room queries MUST complete off the main thread
