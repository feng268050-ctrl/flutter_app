## ADDED Requirements

### Requirement: nativeInferImageToJson SHALL use JSON code field for success and errors

The native method `nativeInferImageToJson(handle, imagePath)` SHALL return a JSON string where integer field `code` indicates outcome: `0` for successful inference and post-processing, and negative values for failures (`-1` argument/path, `-2` read failure, `-3` inference/post-process exception) per engine alignment documentation.

The App SHALL NOT treat non-JSON return values or empty strings as success.

#### Scenario: Successful offline frame

- **WHEN** native returns JSON with `"code":0` and `source` such as `offline_infer`
- **THEN** `LensGuardManager.inferJpgToJson` SHALL return that JSON to callers
- **AND** `AiVisionFrameInference.fromNativeJson` SHALL accept it without throwing

#### Scenario: Read failure

- **WHEN** native returns JSON with `"code":-2`
- **THEN** `fromNativeJson` SHALL throw or callers SHALL treat the frame as failed
- **AND** SHALL NOT write annotated result images (this API does not save images)

### Requirement: nativeInferImageToJson qualitative fields SHALL match stain vocabulary

On `code == 0`, JSON SHALL include `level`, `status`, and `message` using production stain vocabulary where `status` is one of `CLEAN`, `MILD`, `HEAVY`. Optional `boxes[]` entries SHALL use coordinates in the sampled JPEG pixel space (up to engine max count).

#### Scenario: Boxes parsed for overlay

- **WHEN** JSON includes `boxes` with `x1,y1,x2,y2,classId,label,score`
- **THEN** offline overlay rendering SHALL map coordinates directly to the frame bitmap dimensions without letterbox remapping

### Requirement: nativeInferImageToJson SHALL remain distinct from nativeInferImageAndSave

The App SHALL NOT invoke `nativeInferImageAndSave` for offline timeline sampling. App-side guarded wrappers SHALL route offline timeline calls only through `guardedInferImageToJson` on the RKNN single-thread executor.

#### Scenario: Manager routing

- **WHEN** AI Vision requests one-shot JSON for a JPG path
- **THEN** `LensGuardManager.inferJpgToJson` SHALL call `NativeBridge.guardedInferImageToJson`
- **AND** SHALL NOT call `guardedInferImageAndSave` for that use case
