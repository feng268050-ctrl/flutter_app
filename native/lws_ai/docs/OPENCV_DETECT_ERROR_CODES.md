# OpenCV detect unified error codes

Shared by **zero_point**, **edgedrawing**, and **lens_det** (OpenCV stain detect). RKNN / `nativeInferImageAndSave` integers are **not** covered here.

## Code table

| code | Name | Meaning |
|------|------|---------|
| `0` | `OK` | Success |
| `-1` | `INVALID_HANDLE` | Detector/session handle invalid |
| `-2` | `INVALID_INPUT` | Empty frame, bad dimensions, empty path, wrong BGR type, stride/buffer issues |
| `-3` | `DETECT_FAILED` | Pipeline ran but no qualifying blob/target |
| `-4` | `IO_ERROR` | Read image, write output, create outputDir failed |
| `-5` | `FRAME_REJECTED` | Frame-level rejection; see `reason` |
| `-6` | `CONFIG_ERROR` | ROI/reference/yaml configuration unusable |

Native header: `native/lensinspector/src/opencv_detect/opencv_detect_codes.h`  
App enum: `com.lasercyber.lws.ai.OpencvDetectCodes`

## Reason tokens

### Red-frame gate (all three OpenCV detect modules)

Applied before module-specific detection via `validateRedFrame` (`red_frame_validator.cpp`).

| reason | code |
|--------|------|
| `overexposed` | -5 |
| `invalid_non_red` | -5 |
| `strict_invert_dirty_contamination` | -5 |
| `no_valid_region` | -5 |
| `empty_roi` | -5 |

### zero_point (`code` + `reason` in frame JSON)

| reason | code |
|--------|------|
| `spot_size_below_min` | -5 |
| `spot_size_above_max` | -5 |
| `black_blob_not_found` | -3 |
| `line_not_found` | -3 |
| `missing_reference_zero` | -6 |

JNI / input: `invalid_detector_handle`, `empty_image_path`, `invalid_i420_dimensions`, `invalid_rgb_frame_dimensions`, `invalid_direct_buffer`, `empty_image`, `failed_to_read_image`

### lens_det (`code` + `reason` in summary JSON)

| reason | code |
|--------|------|
| `saturated_white_area_exceeds_limit` | -5 (deprecated; superseded by `overexposed`) |
| `insufficient_regions_after_erode` | -3 |
| `no_target_after_filter` | -3 |

JNI / input: `invalid_session_handle`, `empty_image_path`, `empty_output_dir`, `invalid_i420_dimensions`, `invalid_rgb_frame_dimensions`, `invalid_rgb_stride`, `invalid_direct_buffer`, `empty_image`, `invalid_image_type`, `failed_to_read_image`, `failed_to_create_output_dir`, `failed_to_write_target_json`

## JSON shapes

**zero_point failure:**

```json
{"ok":false,"code":-5,"reason":"spot_size_above_max","offset_x":0,"offset_y":0}
```

**lens_det failure:**

```json
{"ok":false,"code":-5,"reason":"saturated_white_area_exceeds_limit","files":[]}
```

## Migration (pre-unification → unified)

### zero_point

| Old code | Old scenario | New code | New reason |
|----------|--------------|----------|------------|
| -1 | invalid handle | -1 | `invalid_detector_handle` |
| -2 | bad frame | -2 | `invalid_i420_dimensions` / `empty_image` / … |
| -3 | no blob | -3 | `black_blob_not_found` |
| -3 | missing reference | **-6** | `missing_reference_zero` |
| -4 | read jpg | -4 | `failed_to_read_image` |
| -5 | spot size | -5 | `spot_size_below_min` / `spot_size_above_max` |

### lens_det

| Old code | Old scenario | New code | New reason |
|----------|--------------|----------|------------|
| -1 | invalid handle | -1 | `invalid_session_handle` |
| -1 | empty path/dims/type | **-2** | matching input token |
| -2 | mkdir fail | **-4** | `failed_to_create_output_dir` |
| -3 | erosion / no target | -3 | `insufficient_regions_after_erode` / `no_target_after_filter` |
| -4 | read/write | -4 | `failed_to_read_image` / `failed_to_write_target_json` |
| -5 | saturation | -5 | `saturated_white_area_exceeds_limit` |

## App logcat

Coordinators emit:

```text
detect_result module=zero_point code=-5 reason=spot_size_above_max
detect_result module=lens_det code=-5 reason=saturated_white_area_exceeds_limit
```

Same `code=-5` is disambiguated by `reason` (and `module`).
