## MODIFIED Requirements

### Requirement: Inbound process library list request

Inbound frames with `type` **`command.process_library_request`** SHALL use the unified WebSocket envelope. The `payload` object SHALL be present and SHALL include integer field **`process_type`** (工艺类型, `ModelConstant` 0–5). The device SHALL query engineer-mode rows only: **`dataType`** **`1`**（工程师模式常用参数 / `ENGINEER_MODE_DATA`）, matching **`processType`**, ordered by stable row order (e.g. primary key or name). Legacy rows with **`dataType`** **`2`** (`ENGINEER_MODE_CUSTOM_DATA`, deprecated) MAY be included in results until migrated, treated as engineer common presets. **`0`** 快速模式参数与 **`3`** 视频工艺参数（废弃）MUST NOT appear.

#### Scenario: Valid list request

- **WHEN** the server sends `command.process_library_request` with top-level `id` `req-lib-1` and `payload.process_type` equal to `1`
- **THEN** the device MUST accept the frame when WebSocket state is **ONLINE** and MUST respond with `command.process_library_response`

#### Scenario: Missing process_type

- **WHEN** `command.process_library_request` omits `process_type` or it is not a number
- **THEN** the device MUST NOT query with an undefined filter and MUST send `command.process_library_response` with `data` as an empty array or MUST document failure via empty list plus log (SHALL NOT crash)

#### Scenario: List excludes non-engineer rows

- **WHEN** the database contains `dataType` **`0`**（快速模式参数）or **`3`**（视频工艺参数，废弃）rows for the same `processType`
- **THEN** those rows MUST NOT appear in `payload.data`

### Requirement: Inbound process parameters create

Inbound frames with `type` **`command.process_parameters_create`** SHALL carry create fields in `payload` using snake_case for **`process_type`** and camelCase or snake_case for other fields consistent with existing WS conventions: at minimum **`process_type`** (required), optional **`name`**, **`material_type`**, **`material_name`**, and remaining process fields mirroring `ProcessParametersData`. The device SHALL set **`dataType`** to **`ENGINEER_MODE_DATA`** (`1`), SHALL assign **`id`** via insert, and SHALL set **`processType`** from **`process_type`**.

#### Scenario: Successful create

- **WHEN** `command.process_parameters_create` includes valid `process_type` and insert succeeds
- **THEN** the device MUST send `command.process_parameters_create_ack` with `payload.data.success` true and SHOULD include string **`id`** of the new row in `payload.data`

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

- **WHEN** `payload.id` references an existing engineer-mode common preset row
- **THEN** the device MUST send `command.process_parameters_set_default_ack` with `success` true and subsequent `device.online` / `command.stat_response` snapshots for that `processType` SHOULD reflect the selected row when it is the active preset

#### Scenario: Unknown id

- **WHEN** no row exists for `payload.id`
- **THEN** ack MUST have `success` false and a non-empty `message`
