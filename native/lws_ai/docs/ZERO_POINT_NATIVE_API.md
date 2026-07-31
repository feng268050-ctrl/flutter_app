# Zero-point Native API

Single-frame zero detect (OpenCV point or line mode; App owns temporal logic).

## JNI

```java
long zp = NativeBridge.nativeCreateOpencvZeroPointDetector(roiJsonPath, 10.0f);
NativeBridge.nativeSetOpencvZeroPointDetectTargetMode(zp, ZeroPointDetectTargetMode.LINE);
String json = NativeBridge.nativeOpencvZeroPointDetectFromNv12(zp, nv12, width, height);
NativeBridge.nativeDestroyOpencvZeroPointDetector(zp);
```

`nativeSetOpencvZeroPointDetectTargetMode` values:

| mode | Native `DetectTargetMode` | Use |
|------|---------------------------|-----|
| `0` | `Point` | Spot weld (`POINT_WELDING`) — brightest blob, 30×30 cap |
| `1` | `Line` | Continuous weld (`CONTINUOUS_WELDING`) — largest component + `minAreaRect` center |

Also available: `nativeOpencvZeroPointDetectFromJpg`, `nativeOpencvZeroPointDetectFromRgb`.

## ROI JSON

Deploy to `{filesDir}/lens_guard/zero_point_roi.json` (bundled as `assets/zero_point_roi.json`).

Required fields: `box_xywh` (or `yellow_box_xywh`), optional `source_size`, `reference_zero_xy`.

## Frame result JSON

Success or failure returns the same shape:

```json
{"ok": true, "code": 0, "offset_x": -9.0, "offset_y": 0.0}
```

Failure examples:

```json
{"ok": false, "code": -5, "reason": "spot_size_above_max", "offset_x": 0, "offset_y": 0}
```

```json
{"ok": false, "code": -3, "reason": "line_not_found", "offset_x": 0, "offset_y": 0}
```

Red-frame gate (mask-only for zero_point; pipeline not run on reject):

```json
{"ok": false, "code": -5, "reason": "no_valid_region", "offset_x": 0, "offset_y": 0}
```

| Field | Meaning |
|-------|---------|
| `ok` | `true` when detect succeeded and comparison is available |
| `code` | Unified OpenCV detect code (`0` on success); see [OPENCV_DETECT_ERROR_CODES.md](OPENCV_DETECT_ERROR_CODES.md) |
| `reason` | On failure: stable snake_case token (e.g. `line_not_found`, `spot_size_above_max`, `empty_roi`) |
| `offset_x` | Pixels: detected x − reference x |
| `offset_y` | Pixels: detected y − reference y |

On failure, `ok` is `false`, offsets are `0`.

| `code` | Meaning (zero_point) |
|--------|----------------------|
| `0` | Success |
| `-1` | Invalid detector handle (JNI) |
| `-2` | Invalid or empty frame / buffer (JNI / context) |
| `-3` | Point: black blob not found; Line: `line_not_found` |
| `-4` | Failed to read image file (JNI) |
| `-5` | Frame rejected: mask gate (`no_valid_region`, `empty_roi`) or spot size (`spot_size_below_min` / `spot_size_above_max`) |
| `-6` | Missing `reference_zero_xy` in ROI config |

Before detection, `validateRedFrameMaskOnly` checks bright-region mask existence (no OSD crop, no color/overexposure reject). See [OPENCV_DETECT_ERROR_CODES.md](OPENCV_DETECT_ERROR_CODES.md).

**Point mode**: ROI crop → CLAHE → invert → largest blob; zero = bbox center; valid blob each side in **[10, 30]** px.

**Line mode**: same preprocess → horizontal bright row band → largest component → `minAreaRect` center; see `docs/ZERO_POINT_CONTINUOUS_SPOT_WELD_DESIGN.md`.

## App zero correction mapping

UI **零点校正** uses **1 unit = 3px**; **+** moves zero **right**, **−** moves zero **left**.

**Position tolerance** (App): if mean `|offset_x|` is **≤ 16 px** after the round, **no** Modbus/Room write (`skip_write=within_tolerance`). `offset_y` is still returned for logging/overlay but **does not** affect tolerance or alerts. UI register mapping remains **1 unit = 3 px**.

Because `offset_x` is detection minus reference, the UI delta is **inverted**:

```text
uiDelta = round(-offset_x / 3.0)
newZeroPointCorrection = clamp(current + uiDelta, -30, 30)
```

## Offline CLI

```bash
zero_point_infer --roi path/to/zero_point_roi.json --mode line|point [--no-red-gate] image.jpg
```
