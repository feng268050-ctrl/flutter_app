## Context

- **zero_point** 现 code：0, -1(handle), -2(frame), -3(detect/config mix), -4(read jpg), -5(spot size)。
- **lens_det** 现 code：0, -1(杂项), -2(mkdir), -3(no target), -4(read/write), -5(saturation)。
- App 已有 `ZeroPointDetectJson.CODE_SPOT_SIZE_REJECTED = -5`，与 lens_det `-5` 语义冲突。
- 参考：`native-infer-image-contract` 对 RKNN infer 使用分层负整数，但 OpenCV detect 走 **JSON 字符串**返回，更适合统一 code + reason。

## Goals / Non-Goals

**Goals:**

- 两模块共用 7 个 code 值（0 与 -1…-6），含义一致。
- `reason` 为稳定 snake_case token（非长句），便于 logcat 与单测断言。
- App 单一解析入口映射到 `OpencvDetectCodes` 枚举。

**Non-Goals:**

- 不改变 RKNN / `nativeInferImageAndSave` 整数返回码。
- 不改变检测算法、ROI 尺寸阈值、`-5` 过曝/光斑的业务门限数值。
- 不在本变更做 Java legacy 映射层（一次性 `make sync`；若需兼容可另开 change）。

## Decisions

### 1. 共享 code 表

| code | 枚举名 | 含义 |
|------|--------|------|
| `0` | `OK` | 成功 |
| `-1` | `INVALID_HANDLE` | detector/session handle 无效 |
| `-2` | `INVALID_INPUT` | 空帧、尺寸错、空 path、BGR 类型错、stride 不足等 |
| `-3` | `DETECT_FAILED` | 管线执行完毕但无合格目标/光斑 |
| `-4` | `IO_ERROR` | 读图、写 output、创建 outputDir 失败 |
| `-5` | `FRAME_REJECTED` | 帧级前置拒绝；见 `reason` |
| `-6` | `CONFIG_ERROR` | ROI/reference/yaml 等配置不可用 |

### 2. `reason` 命名（`-5` / `-3` / `-6` 子类）

**zero_point**

| reason | code |
|--------|------|
| `spot_size_below_min` | -5 |
| `spot_size_above_max` | -5 |
| `black_blob_not_found` | -3 |
| `missing_reference_zero` | -6 |
| `empty_roi` | -6 |

**lens_det**

| reason | code |
|--------|------|
| `saturated_white_area_exceeds_limit` | -5 |
| `insufficient_regions_after_erode` | -3 |
| `no_target_after_filter` | -3 |

**共用 INVALID_INPUT / IO_ERROR / INVALID_HANDLE**：`reason` 可为短 token（如 `invalid_i420_dimensions`、`empty_image_path`），JNI 层统一生成。

### 3. Native 布局

```
native/lensinspector/src/opencv_detect/opencv_detect_codes.h   # 枚举 + reason 常量
native/lensinspector/src/opencv_detect/opencv_detect_json.h    # 可选：共享 errorJson(ok,code,reason)
```

`zero_point` 与 `opencv_stain_detect` 均 `#include` 该头；`errorJson` / `errorResult` 只接受表内 code。

### 4. lens_det 迁移映射

| 现 code | 现 reason/场景 | 新 code | 新 reason |
|---------|----------------|---------|-----------|
| -1 | invalid handle | -1 | `invalid_session_handle` |
| -1 | empty path/dimensions/type | -2 | 对应 token |
| -2 | mkdir fail | -4 | `failed_to_create_output_dir` |
| -3 | erosion / no target | -3 | 上表 token |
| -4 | read/write | -4 | `failed_to_read_image` / `failed_to_write_target_json` |
| -5 | saturation | -5 | `saturated_white_area_exceeds_limit` |

### 5. zero_point 迁移映射

| 现 code | 场景 | 新 code | 新 reason |
|---------|------|---------|-----------|
| -1 | handle | -1 | `invalid_detector_handle` |
| -2 | frame | -2 | `invalid_frame` |
| -3 | no blob | -3 | `black_blob_not_found` |
| -3 | missing ref | -6 | `missing_reference_zero` |
| -4 | read jpg | -4 | `failed_to_read_image` |
| -5 | size | -5 | `spot_size_*` |

### 6. App 解析

- `OpencvDetectCodes.fromJson(int code, String reason)` → 枚举 + `isFrameRejected()` 等便捷方法。
- `ZeroPointDetectJson.CODE_SPOT_SIZE_REJECTED` **deprecated** → 使用 `OpencvDetectCodes.FRAME_REJECTED` + reason 前缀 `spot_size_`。
- 统一日志：`detect_result module=zero_point|lens_det code=-5 reason=spot_size_above_max`。

## Risks / Trade-offs

- **[Risk] 旧 APK / 旧日志对照困难** → 变更说明 + 文档迁移表；版本号 bump 备注。
- **[Risk] 第三方脚本解析旧 reason 长句** → CLI 与 batch 脚本同步改断言；OpenSpec tasks 含 parity 脚本更新。
- **[Trade-off] `-6` 新增** → zero_point 配置错误与检测失败分离，App 可区分「配错了」vs「没看到光」。

## Migration Plan

1. 落地 `opencv_detect_codes.h` + 单元测试（C++ smoke 或 JSON golden）。
2. 改 lens_det（`-1` 拆分收益最大）→ zero_point → App Java。
3. 合并文档；跑 `verify-opencv-detect-integration.sh` + 现有 zero_point/lens_det 单测。
4. `make sync` 设备验收：各触发一条 `-3`、`-5` logcat。

## Open Questions

- `failed_to_create_output_dir` 是否坚持 `-4`（本设计）还是 `-2`？**当前决策：-4 IO_ERROR**，与「输入参数合法但磁盘失败」区分。
