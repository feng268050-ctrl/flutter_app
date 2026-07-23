## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: ZeroPointDetectNativeSession SHALL prefer NV12 for Java-owned detect

`ZeroPointDetectNativeSession` SHALL expose detect entry that accepts NV12 direct buffers and invokes `nativeOpencvZeroPointDetectFromNv12`. I420 overloads SHALL remain deprecated compatibility shims.

#### Scenario: Offline detect uses NV12 session API

- **WHEN** `ZeroPointDetectNativeSession` performs detect for a Java-prepared offline frame
- **THEN** it MUST call `nativeOpencvZeroPointDetectFromNv12`
- **AND** MUST NOT call `nativeOpencvZeroPointDetectFromI420` on the primary offline path
