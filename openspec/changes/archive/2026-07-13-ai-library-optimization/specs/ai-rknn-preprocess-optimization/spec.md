## ADDED Requirements

### Requirement: RKNN stain preprocess SHALL use blobFromImage

`stain_preprocess::BgrToNchwFloat` (or equivalent RKNN stain preprocess entry) MUST use `cv::dnn::blobFromImage` with scale `1/255.0`, size `640×640`, `swapRB=true`, and `CV_32F` output instead of a scalar double-loop BGR→NCHW conversion. A CMake option MUST allow falling back to the scalar implementation for validation.

#### Scenario: Preprocess timing improvement

- **WHEN** `LENS_INFER_TIMING=1` build runs RKNN stain inference
- **THEN** `preprocess_ms` MUST decrease versus scalar baseline
- **AND** detection output MUST match scalar path within documented FP tolerance (offline diff script)

#### Scenario: Scalar fallback available

- **WHEN** build selects scalar preprocess via CMake option
- **THEN** RKNN stain inference MUST still function
- **AND** MUST produce bit-identical or tolerance-equivalent results to pre-change baseline

### Requirement: RKNN runner SHALL reuse output buffers

`rknn_runner` MUST reuse member `output_buffers_` (or equivalent) across inference rounds, resizing only when output tensor shape changes. Per-round `vector<float>` allocation on the hot path MUST be eliminated.

#### Scenario: Long-running stability without alloc churn

- **WHEN** RKNN stain streaming runs continuously for at least 30 minutes
- **THEN** inference MUST remain stable without memory growth attributable to per-round output allocation
- **AND** `rknn_run_ms` timing MUST not regress versus buffer-reuse baseline

### Requirement: det_raw_concat SHALL reuse merge buffer

`det_raw_concat` MUST reuse a `thread_local` or member buffer for `merged_raw` concatenation instead of allocating on every inference round.

#### Scenario: No per-round heap alloc on concat path

- **WHEN** `LENS_INFER_TIMING=1` reports postprocess breakdown
- **THEN** `det_raw_concat` MUST NOT allocate a new buffer each inference round on the hot path
