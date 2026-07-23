## ADDED Requirements

### Requirement: Native SHALL detect continuous-weld zero as brightest horizontal line band

When `DetectTargetMode` is **Line**, `zero_point` SHALL run `detectBrightestLineInBox` on the shared ROI preprocess output (CLAHE grayscale inside `box_xywh`). The algorithm SHALL:

1. For each row in the enhanced gray ROI, count pixels with `gray ≥ 250`
2. Treat rows with **15–400** bright pixels as candidate rows
3. Select the highest-scoring **contiguous horizontal band** of candidate rows (score = sum of per-row bright pixel counts in the band)
4. Within the band, collect all pixels with `gray ≥ 250` and set detected zero to **median(x), median(y)** in full-frame coordinates
5. Reject when horizontal span is outside **20–450 px**, band height exceeds **60 rows**, or no qualifying band exists

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

When `DetectTargetMode` is **Point**, `zero_point` SHALL continue to use `detectBrightestPointInBox` with `kMaxSpotDimensionPx = 30`. Spot-size rejection SHALL use `code=-5`, `reason=spot_size_above_max`.

#### Scenario: Point weld spot within size limit

- **WHEN** the largest inverted bright blob bbox is ≤ 30×30 px inside the ROI
- **THEN** native SHALL return `ok=true` with offsets from blob center

#### Scenario: Oversized blob rejected in point mode

- **WHEN** the largest blob bbox exceeds 30×30 px
- **THEN** native SHALL return `ok=false`, `code=-5`, `reason=spot_size_above_max`

### Requirement: Java SHALL set detect target mode from active weld model type

Before each laser-on zero-point sample (or once per round before first sample), Java SHALL map `WeldModeHost.getActiveWeldModelType()`:

| Active weld model | Native `DetectTargetMode` |
|-------------------|---------------------------|
| `CONTINUOUS_WELDING` | Line |
| `POINT_WELDING` | Point |

Java SHALL configure the active zero-point native session to the mapped mode. Other weld model types outside production zero-point scope SHALL NOT change the mode used by an in-flight round.

#### Scenario: Continuous welding selects line mode

- **WHEN** active weld model is `CONTINUOUS_WELDING` and a laser-on sample is accepted
- **THEN** Java SHALL set Line mode on the zero-point session before calling `nativeOpencvZeroPointDetectFromI420`

#### Scenario: Point welding selects point mode

- **WHEN** active weld model is `POINT_WELDING` and a laser-on sample is accepted
- **THEN** Java SHALL set Point mode on the zero-point session before calling `nativeOpencvZeroPointDetectFromI420`

### Requirement: Offline infer SHALL support line and point modes

`zero_point_infer` SHALL accept `--mode line` or `--mode point` (default `point`) to exercise `DetectTargetMode` without the App. It SHALL support `--no-red-gate` to disable red-frame validation for offline fixtures.

#### Scenario: Offline line infer on fixture

- **WHEN** `zero_point_infer --mode line --no-red-gate` is run on a continuous-weld test image
- **THEN** the tool SHALL write JSON and optional stage dumps using the line detection path
