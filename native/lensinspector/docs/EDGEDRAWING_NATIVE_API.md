# EdgeDrawing Native API

Single-frame zero detect via OpenCV contrib `cv::ximgproc::EdgeDrawing` (App owns temporal logic).

## JNI

```java
long ed = NativeBridge.nativeCreateOpencvEdgeDrawingDetector(roiJsonPath, 10.0f);
String json = NativeBridge.nativeOpencvEdgeDrawingDetectFromNv12(ed, nv12, width, height);
NativeBridge.nativeDestroyOpencvEdgeDrawingDetector(ed);
```

Also available: `nativeOpencvEdgeDrawingDetectFromJpg`, `nativeOpencvEdgeDrawingDetectFromRgb`.

## ROI JSON

Same schema as zero_point: deploy `edgedrawing_roi.json` (or reuse `zero_point_roi.json` values) under `{filesDir}/lens_guard/`.

Required fields: `box_xywh`, optional `source_size`, `reference_zero_xy`.

## Frame result JSON

Same shape as zero_point:

```json
{"ok": true, "code": 0, "offset_x": -9.0, "offset_y": 0.0}
```

Failure examples:

```json
{"ok": false, "code": -3, "reason": "edge_not_found", "offset_x": 0, "offset_y": 0}
```

Red-frame gate (before radial scan; pipeline not run):

```json
{"ok": false, "code": -5, "reason": "overexposed", "offset_x": 0, "offset_y": 0}
```

```json
{"ok": false, "code": -5, "reason": "invalid_non_red", "offset_x": 0, "offset_y": 0}
```

Shared `code` / `reason` table: [OPENCV_DETECT_ERROR_CODES.md](OPENCV_DETECT_ERROR_CODES.md).

## Algorithm (C++)

Full-frame pipeline:

1. Clone full BGR; **OSD blackout** top-left `850×140` px
2. **Brightness enhance** (HSV-V CLAHE + scale, same as `zero_point`)
3. **Grayscale invert** on full frame
4. **Primary:** largest black blob bbox in `center_box` (enhance → invert → threshold → max CC)
5. **Fallback:** `cv::ximgproc::EdgeDrawing` on inverted gray (`PREWITT`, `GradientThresholdValue=20`, `MinPathLength=50`, `MinLineLength=10`, `NFAValidation=false`) → ellipses / lines / segments
6. Candidate priority: **blob → ellipse/circle → line → segment**; nearest `reference_zero_xy` within tier
7. Spot-size gate **[10, 30] px** on anchor bbox

## Offline CLI

```bash
# After host CMake build with BUILD_EDGEDRAWING_INFER=ON
edgedrawing_infer --image frame.jpg --roi-json zero_point_roi.json
edgedrawing_infer --image-dir ./frames --roi-json zero_point_roi.json --out-dir ./out
```

## Build notes

Stock OpenCV Android SDK lacks ximgproc. This repo vendors `edge_drawing.cpp` from opencv_contrib (matching `native/toolchains/opencv/VERSION`):

```bash
bash scripts/make/fetch-opencv-ximgproc-edgedrawing.sh
make ai
```
