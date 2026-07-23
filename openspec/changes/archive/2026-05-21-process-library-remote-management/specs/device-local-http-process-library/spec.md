## ADDED Requirements

### Requirement: Process library list HTTP endpoint

The system SHALL expose **`GET /v1/process-library`**. The system SHALL require query parameter **`processType`** (integer). The system SHALL return **`ApiResult`** with **`success: true`** and **`data`** as a **JSON array** of summary objects with camelCase fields **`id`**, **`name`**, **`dataType`**, **`processType`**, **`materialType`**, **`materialName`**, using the same query semantics as **`command.process_library_request`** (engineer-mode data types only, `dataType DESC` ordering).

#### Scenario: List by process type

- **WHEN** a client calls `GET /v1/process-library?processType=1`
- **THEN** the response MUST be `ApiResult` success and `data` MUST be an array containing only rows with `processType` 1 and engineer-mode `dataType`

#### Scenario: Missing processType

- **WHEN** `processType` query parameter is omitted
- **THEN** the response MUST be `ApiResult` with `success` false and an appropriate `message`

### Requirement: Process parameters get HTTP endpoint

The system SHALL expose **`GET /v1/process-parameters/:id`** where `:id` is the Room primary key. On success the system SHALL return **`ApiResult`** with **`data`** set to the full parameter object (camelCase, same shape as `command.process_parameters_response` `payload.data`). When no row exists, the system SHALL return logical failure.

#### Scenario: Known id

- **WHEN** a row exists with primary key `42`
- **THEN** `GET /v1/process-parameters/42` MUST return success `ApiResult` whose `data.id` is `42`

### Requirement: Process parameters create HTTP endpoint

The system SHALL expose **`POST /v1/process-parameters`** with JSON body using **camelCase** fields (same logical fields as WS create, without `id`). The system SHALL apply the same insert rules as **`command.process_parameters_create`**. On success the system SHALL return **`ApiResult`** with **`data`** containing at least **`id`** (new primary key).

#### Scenario: Successful create

- **WHEN** a valid JSON body with `processType` is posted
- **THEN** the response MUST be `ApiResult` success with `data.id` set to the inserted row id

### Requirement: Process parameters update HTTP endpoint

The system SHALL expose **`PUT /v1/process-parameters/:id`** with JSON body (camelCase). The system SHALL apply the same update rules as **`command.process_parameters_update`**.

#### Scenario: Successful update

- **WHEN** `PUT /v1/process-parameters/42` targets an existing engineer-mode row with valid fields
- **THEN** the response MUST be `ApiResult` success

### Requirement: Process parameters delete HTTP endpoint

The system SHALL expose **`DELETE /v1/process-parameters/:id`**. The system SHALL apply the same delete rules as **`command.process_parameters_delete`** (custom rows only).

#### Scenario: Reject delete default preset

- **WHEN** `:id` refers to `ENGINEER_MODE_DEFAULT_DATA`
- **THEN** the response MUST be `ApiResult` with `success` false

### Requirement: Process parameters set default HTTP endpoint

The system SHALL expose **`POST /v1/process-parameters/:id/set-default`** where `:id` is the Room primary key. The request SHALL have **no body**. The system SHALL apply the same semantics as **`command.process_parameters_set_default`** (derive **`processType`** from the loaded row).

#### Scenario: Set active preset via HTTP

- **WHEN** `POST /v1/process-parameters/42/set-default` is called and row `42` exists with engineer-mode `dataType`
- **THEN** the response MUST be `ApiResult` success

#### Scenario: Unknown id via HTTP

- **WHEN** `:id` does not exist
- **THEN** the response MUST be `ApiResult` with `success` false

### Requirement: ApiResult envelope for process library HTTP routes

All endpoints in this capability except the global **`GET /lasercyber`** probe (defined in `device-local-http-api`) SHALL return JSON **`ApiResult`** with fields **`success`**, **`code`**, **`message`**, **`data`**. Logical success SHALL require **`success === true`**.

#### Scenario: HTTP mirrors WS list content

- **WHEN** the same device state is queried via `GET /v1/process-library?processType=1` and via `command.process_library_request` with `process_type` 1
- **THEN** the array elements MUST represent the same set of rows (same logical ids and summary fields; WS uses string `id`, HTTP MAY use numeric `id`)

### Requirement: Off-main-thread process library HTTP handlers

Database and cache operations for `/v1/process-library` and `/v1/process-parameters*` routes SHALL run off the Android main thread.

#### Scenario: GET list does not block UI

- **WHEN** `GET /v1/process-library` is invoked
- **THEN** Room access MUST complete on a background executor
