# OpenCV stain detect Native API

Fixed-square-ROI stain detection via OpenCV enhance → invert → binary → denoise → dynamic erode (same product goal as RKNN stain infer, different method). **No blue-line valid band**, **no red ROI / cross center** in native.

## Boundary

- Fixed square ROI (default `650,100` size `640×640` on 1080p-class frames), then runs: brightness enhance (CLAHE + scale) → grayscale → bitwise invert → binary threshold → morph open → **global 9×9 erode**.
- **Target detection at step 10**: after global erode, **exactly one** connected component (area ≥ `min_blob_area`) is the detection target. `max_split_regions: 1`.
- Legacy **HSV red/magenta** path (steps 11–16) is removed from the live pipeline; `red_bright_region` config keys are retained but unused unless re-enabled later.
- Picks **one** smallest blob that meets area and size thresholds; coordinates are mapped back to full-image pixels.
- Each successful call writes **one** JSON file under `outputDir` (default name `target.json`).
- JNI return value is only a **summary** listing the written file path(s), not target coordinates.

## Session (independent of RKNN engine)

Lens det uses a dedicated OpenCV session handle (`opencvStainDetectHandle`), aligned with `zero_point` (`zpHandle`). This allows lens_det on Android emulators without `nativeCreate` / Rockchip NPU.

```java
long opencvStainDetectHandle = NativeBridge.nativeCreateOpencvStainDetectSession(configYamlPath, projectRoot);
// ... detect calls ...
NativeBridge.nativeDestroyOpencvStainDetectSession(opencvStainDetectHandle);
```

`configYamlPath` and `projectRoot` come from `AssetDeployer.deploy` (same `config.yaml` as RKNN engine). `AiManager` owns create/destroy when `ENABLE_LENS_DET_APP=true`.

## Detect JNI

**BREAKING:** the first `long` parameter is **`opencvStainDetectHandle`** (not the RKNN engine handle).

```java
String summary = NativeBridge.nativeOpencvStainDetectFromJpg(opencvStainDetectHandle, imagePath, outputDir);
String summary = NativeBridge.nativeOpencvStainDetectFromRgb(opencvStainDetectHandle, rgba, w, h, stride, outputDir);
String summary = NativeBridge.nativeOpencvStainDetectFromNv12(opencvStainDetectHandle, nv12, w, h, outputDir);
```

## Per-target file (`outputDir/target.json`)

```json
{"name":"target","x":923.40,"y":563.20,"bbox_x":900,"bbox_y":540,"w":79,"h":67}
```

| Field | Meaning |
|-------|---------|
| `name` | Target label (`target`) |
| `x`, `y` | Connected-component centroid (full-image pixels) |
| `bbox_x`, `bbox_y` | Axis-aligned bbox top-left (full-image pixels) |
| `w`, `h` | Bbox width and height (pixels) |

## JNI summary return

Success:

```json
{"ok":true,"code":0,"files":["/data/.../target.json"]}
```

Failure:

```json
{"ok":false,"code":-3,"reason":"no_target_after_filter","files":[]}
```

Skip (red-frame gate; pipeline not run):

```json
{"ok":false,"code":-5,"reason":"overexposed","files":[]}
```

```json
{"ok":false,"code":-5,"reason":"invalid_non_red","files":[]}
```

Unified code/reason table and migration from legacy codes: [OPENCV_DETECT_ERROR_CODES.md](OPENCV_DETECT_ERROR_CODES.md).

Before fixed ROI analysis, `validateRedFrame` checks circular weld-pool ROI exposure and red color (`overexposed`, `invalid_non_red`, etc.). Legacy `max_saturated_white_area_px` is deprecated.

Selection rules (all must pass):

- After global erode, connected components with `area` ≥ `min_target_area_px` (default 1000) must be **exactly 1** (`max_split_regions: 1`).
- At least one blob with `w` ≥ `min_target_width_px` and `h` ≥ `min_target_height_px` (default 15×15, filters noise)
- Among qualifying blobs, pick the **smallest area** (stain-like spot, not the whole glare)

`min_target_area_px` filters small fragments when counting step-10 global-erode regions (default 1000).

Read coordinates from the file path in `files[0]`, not from the summary string.

## Config (`config.yaml` → `lens_det`)

| Section | Keys |
|---------|------|
| `fixed_roi` | `x`, `y`, `width`, `height` (default 650, 100, 500, 500) |
| `preprocess` | `enhance_clahe_clip`, `enhance_alpha`, `enhance_beta`, `invert_thresh`, morphology/global erode (legacy stages), `red_bright_region` (HSV split mask), target thresholds |
| `osd_mask` | top-left OSD blackout before ROI crop |

Legacy `valid_region.bright_*` and `ref_*` keys are **ignored** (blue-line pipeline removed).

See `native/lensinspector/config.yaml`. Offline batch/CLI: `opencv_stain_detect_infer` / `scripts/opencv_stain_detect_batch_images.sh`.

## Offline CLI

```bash
opencv_stain_detect_infer <image.jpg> <out-dir> [--dump-stages [dir]]
opencv_stain_detect_infer --image-dir <dir> --out-dir <dir> [--dump-stages]
```

## App integration status

| Layer | Status |
|-------|--------|
| Native + JNI | Done (`opencv_stain_detect_jni.cpp`) |
| `NativeBridge` declarations | Done |
| Parser / `AiManager.inferLensDetFrom*` | Done |
| `LensDetDetectCoordinator` (production PR1) | Done (feature flag `ENABLE_LENS_DET_APP`) |
| AI Vision live / process video overlay | Done (hold-forward, flag-gated) |

To wire App business logic, follow the six-layer checklist in [`docs/OPENCV_DETECT_APP_INTEGRATION.md`](../../../docs/OPENCV_DETECT_APP_INTEGRATION.md). Deploy with **`make sync`** (or **`make ai && make sync-ai`** for daemon-only C++ changes).

When adding or renaming JNI here, sync `native/lensinspector/scripts/verify_libai_jni.sh` `REQUIRED` and `NativeBridge.java`.
