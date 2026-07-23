# zero-point-line-detect Specification

## Purpose
TBD - created by archiving change zero-point-continuous-spot-weld. Update Purpose after archive.
## Requirements
### Requirement: Native SHALL detect continuous-weld zero as brightest horizontal line band

When `DetectTargetMode` is **Line**, `zero_point` SHALL run `detectBrightestLineInBox` on the shared ROI preprocess output (CLAHE grayscale inside `box_xywh`). The algorithm SHALL:

1. For each row in the enhanced gray ROI, count pixels with `gray ≥ 250`
2. Treat rows with **15–400** bright pixels as candidate rows
3. Select the highest-scoring **contiguous horizontal band** of candidate rows (score = sum of per-row bright pixel counts in the band)
4. Build a bright-pixel mask in the band, keep the **largest connected component**, and compute `minAreaRect`
5. Use the rotated rectangle **long edge** for length gate (**20–450 px**), **short edge** for thickness gate (**3–45 px**), and **`minAreaRect` center** as detected zero in full-frame coordinates
6. Reject when no qualifying band exists or band height exceeds **60 rows**

On success, the module SHALL compute `offset_x` and `offset_y` relative to `reference_zero_xy` using the same comparison path as point mode.

#### Scenario: Continuous weld line yields offsets

- **WHEN** a BGR frame contains a horizontal bright weld line inside the configured ROI box
- **AND** `DetectTargetMode` is Line
- **AND** red-frame gate passes or is disabled
- **THEN** native SHALL return `ok=true`, `code=0`, with `offset_x` and `offset_y` relative to reference

#### Scenario: No qualifying line band

- **WHEN** no row band satisfies bright-pixel count and span constraints
- **THEN** native SHALL return `ok=false`, `code=-3`, `reason=line_not_found`
- **AND** SHALL NOT return a synthetic offset

### Requirement: Point mode SHALL remain brightest spot with 30×30 cap

When `DetectTargetMode` is **Point**, `zero_point` SHALL continue to use `detectBrightestPointInBox` with `kMaxSpotDimensionPx = 30`. Among thresholded blob candidates, native SHALL select the blob whose **raw grayscale peak** is brightest (not largest mask area) and use that peak pixel as the detected zero. Spot-size rejection SHALL use `code=-5`, `reason=spot_size_above_max`.

#### Scenario: Point weld spot within size limit

- **WHEN** the winning blob bbox (highest raw grayscale peak among candidates) is ≤ 30×30 px inside the ROI
- **THEN** native SHALL return `ok=true` with offsets from the peak pixel

#### Scenario: Oversized blob rejected in point mode

- **WHEN** the winning blob bbox exceeds 30×30 px
- **THEN** native SHALL return `ok=false`, `code=-5`, `reason=spot_size_above_max`

### Requirement: Java SHALL set detect target mode from active weld model type

Before each laser-on zero-point sample (or once per round before first sample), Java SHALL map `WeldModeHost.getActiveWeldModelType()`:

| Active weld model | Native `DetectTargetMode` |
|-------------------|---------------------------|
| `CONTINUOUS_WELDING` | Line |
| `POINT_WELDING` | Point |

Java SHALL configure the active zero-point native session to the mapped mode. Other weld model types outside production zero-point scope SHALL NOT change the mode used by an in-flight round.

Live RTSP zero-point detect SHALL run inside `StreamDetectPipeline`; Java SHALL NOT submit I420 or NV12 frames for live laser-on samples.

For **offline** manual auto retriever stages, Java SHALL set the mapped mode on the zero-point session and submit **NV12** buffers to `nativeOpencvZeroPointDetectFromNv12`.

#### Scenario: Continuous welding selects line mode

- **WHEN** active weld model is `CONTINUOUS_WELDING` and an offline manual-auto retriever sample is accepted
- **THEN** Java SHALL set Line mode on the zero-point session before calling `nativeOpencvZeroPointDetectFromNv12`

#### Scenario: Point welding selects point mode

- **WHEN** active weld model is `POINT_WELDING` and an offline manual-auto retriever sample is accepted
- **THEN** Java SHALL set Point mode on the zero-point session before calling `nativeOpencvZeroPointDetectFromNv12`

### Requirement: Offline infer SHALL support line and point modes

`zero_point_infer` SHALL accept `--mode line` or `--mode point` (default `point`) to exercise `DetectTargetMode` without the App. It SHALL support `--no-red-gate` to disable red-frame validation for offline fixtures.

#### Scenario: Offline line infer on fixture

- **WHEN** `zero_point_infer --mode line --no-red-gate` is run on a continuous-weld test image
- **THEN** the tool SHALL write JSON and optional stage dumps using the line detection path

### Requirement: ZeroPointDetectNativeSession SHALL prefer NV12 for Java-owned detect

`ZeroPointDetectNativeSession` SHALL expose detect entry that accepts NV12 direct buffers and invokes `nativeOpencvZeroPointDetectFromNv12`. I420 overloads SHALL remain deprecated compatibility shims.

#### Scenario: Offline detect uses NV12 session API

- **WHEN** `ZeroPointDetectNativeSession` performs detect for a Java-prepared offline frame
- **THEN** it MUST call `nativeOpencvZeroPointDetectFromNv12`
- **AND** MUST NOT call `nativeOpencvZeroPointDetectFromI420` on the primary offline path

