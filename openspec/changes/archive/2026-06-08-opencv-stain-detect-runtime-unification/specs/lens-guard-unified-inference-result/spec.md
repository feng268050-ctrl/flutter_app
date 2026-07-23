## RENAMED Requirements

- FROM: `### Requirement: inferFromI420 returns unified result`
- TO: `### Requirement: RKNN I420 stain detect returns AiStainDetectResult`
- FROM: `### Requirement: inferFromJpg returns unified result`
- TO: `### Requirement: RKNN JPG stain detect returns AiStainDetectResult`
- FROM: `### Requirement: Single in-flight unified infer`
- TO: `### Requirement: Single in-flight stain detect per path`

## MODIFIED Requirements

### Requirement: Unified detection result type

The system SHALL provide an immutable **`AiStainDetectResult`** representing one stain/detect outcome for SSE, overlay, timeline, and alert consumers. OpenCV native calls return **`OpencvStainDetectResult`**, which mappers convert to `AiStainDetectResult`. RKNN paths return `AiStainDetectResult` directly from `rknnStainDetectFromI420` / `rknnStainDetectFromJpg`.

Required fields on every `AiStainDetectResult` instance:

| Field | Type | Role |
|-------|------|------|
| `success` | boolean | `code == 0` for a completed detect |
| `code` | int | Native or App error / busy code |
| **`level`** | **int** | **Stain severity: `0` clean, `1` mild, `2` heavy** |
| **`status`** | **String** | **Short stain tag: `CLEAN`, `MILD`, `HEAVY` (and legacy aliases when native emits them)** |
| `message` | String | Human-readable description |
| `imageWidth`, `imageHeight` | int | Frame dimensions; `0` if unknown |
| `boxes` | list | Detection boxes in pixel space |
| `source` | String | **`live_stain_detect` or `offline_stain_detect`** (`StainDetectSource`) |
| `timestampMs` | long | Completion time |

#### Scenario: Successful detection includes level and status

- **WHEN** a mapper produces `AiStainDetectResult` with `code: 0`, `level: 2`, `status: "HEAVY"`, and boxes
- **THEN** `success` MUST be true
- **AND** SSE `runningData` MUST include the same fields

### Requirement: RKNN I420 stain detect returns AiStainDetectResult

`AiManager.rknnStainDetectFromI420` SHALL push I420 via the RKNN guarded path, wait for the correlated callback, parse native JSON when present, and return **`AiStainDetectResult`**. Primary weld and process-video runtime use **`opencvStainDetectFromI420`** instead (see `lens-det-app-inference`).

#### Scenario: RKNN I420 path returns AiStainDetectResult

- **WHEN** `rknnStainDetectFromI420` completes successfully
- **THEN** the caller MUST receive `AiStainDetectResult` with populated `level`, `status`, and `boxes`

### Requirement: RKNN JPG stain detect returns AiStainDetectResult

`AiManager.rknnStainDetectFromJpg` SHALL invoke guarded RKNN JPG infer and map the response into **`AiStainDetectResult`**. Offline OpenCV file detect uses **`opencvStainDetectFromJpg`**.

#### Scenario: RKNN JPG path returns AiStainDetectResult

- **WHEN** `rknnStainDetectFromJpg` completes successfully
- **THEN** the caller MUST receive `AiStainDetectResult`

### Requirement: Single in-flight stain detect per path

The system SHALL allow at most one in-flight **RKNN** stain detect (`rknnStainDetectFromI420` or `rknnStainDetectFromJpg`) and at most one in-flight **OpenCV** stain detect (`opencvStainDetectFromI420` or `opencvStainDetectFromJpg`) per `AiManager` instance at a time, enforced by separate coordinators.

#### Scenario: OpenCV busy rejects concurrent call

- **WHEN** `opencvStainDetectFromI420` is in flight
- **THEN** a second OpenCV call MUST fail fast or be dropped per gate policy without blocking video

### Requirement: Deprecated legacy entry points

Legacy names `LensGuardManager`, `LensGuardInferenceResult`, `inferFromI420`, and `inferFromJpg` SHALL NOT appear in new App code. Existing documentation MAY reference them only in migration notes.

#### Scenario: New Java code uses AiManager APIs

- **WHEN** a contributor adds stain-detect call sites
- **THEN** they MUST use `AiManager.opencvStainDetectFrom*` or `AiManager.rknnStainDetectFrom*`
- **AND** MUST NOT introduce `LensGuardManager` or `inferFromI420`

## REMOVED Requirements

### Requirement: level and status merge rules are identical for I420 and JPG

**Reason**: Merge logic lives in `AiStainDetectResultMapper` / `OpencvStainDetectResultMapper`; RKNN callback merge is internal to `AiManager`.

**Migration**: Consult mapper unit tests.
