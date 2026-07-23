## ADDED Requirements

### Requirement: Lens det JNI summary uses unified OpenCV detect codes

When the App invokes `nativeOpencvStainDetectFromI420`, `FromJpg`, or `FromRgb`, it SHALL parse the returned summary JSON using the shared `code` table from `opencv-detect-error-codes`. Invalid session handle MUST surface as `code=-1`; invalid frame dimensions or empty paths MUST surface as `code=-2`; detection failures as `code=-3`; I/O failures as `code=-4`; saturation skip as `code=-5` with `reason=saturated_white_area_exceeds_limit`.

#### Scenario: Busy or deferred App codes remain separate

- **WHEN** the App returns `AiManager.CODE_OPENCV_STAIN_DETECT_DEFERRED` or `CODE_INFER_BUSY` without calling native
- **THEN** those App-level codes MUST NOT be conflated with native OpenCV detect `code` values

#### Scenario: Native saturation skip is FRAME_REJECTED

- **WHEN** native summary is `{"ok":false,"code":-5,"reason":"saturated_white_area_exceeds_limit","files":[]}`
- **THEN** the App MUST map the result through `OpencvDetectCodes.FRAME_REJECTED`
- **AND** MUST NOT interpret `code=-5` as a zero-point spot-size error

#### Scenario: Invalid dimensions are INVALID_INPUT not INVALID_HANDLE

- **WHEN** native summary is `{"ok":false,"code":-2,"reason":"invalid_i420_dimensions","files":[]}`
- **THEN** the App MUST classify the failure as invalid input
- **AND** MUST NOT log it as an invalid session handle
