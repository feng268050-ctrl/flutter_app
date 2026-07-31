# 板端推理耗时日志（`LENS_INFER_TIMING`）

## 编译

```bash
cmake ... -DLENS_INFER_TIMING=ON
# Android NDK 编 libai.so；离线 CLI 同时加 -DBUILD_RKNN_INFER=ON
```

**Makefile / 打包（推荐台架包）：**

```bash
make pack INFER_TIMING=1          # 或 make ship INFER_TIMING=1
./release_local.sh -v v1.2.9 --infer-timing
# Windows: release_local.ps1 -Version v1.2.9 -InferTiming
```

也可直接：`LENS_INFER_TIMING=1 bash build_android.sh`

默认 **OFF**，正式产线 zip 勿开。

## 日志 tag

| Tag | 来源 |
|-----|------|
| `LensGuardModel` | `[infer_stain][timing]` |
| `DetPostprocess` | `[det_postprocess][timing]` / `[summary]` |
| `RKNNRunner` | `[RKNN][timing]`、`[RKNN_API] rknn_run BEGIN/END` |

## `[infer_stain][timing]` 字段

```text
pre=... input_copy=... rknn_run=... outputs_get=... parse=... concat=... post_det=... post=... total=... boxes=...
```

| 字段 | 含义 |
|------|------|
| `pre` | ROI 裁剪 + resize 640 |
| `input_copy` | `copy_input_with_stride`（进 NPU 前） |
| `rknn_run` | 仅 `rknn_run()` |
| `outputs_get` | `rknn_outputs_get` 或 IO mem 反量化拷贝（见 `[RKNN][timing]`） |
| `parse` | 输出路数/维度解析（进 concat 前） |
| `concat` | P2/P3/P4 → `[65,N]`（单路输出时≈0） |
| `post_det` | `postprocess_det` 整段（细分见 `DetPostprocess`） |
| `post` | `outputs_get` + `parse` + `concat` + `post_det` |
| `total` | 整条 `infer_stain` |

## `[RKNN][timing]` 字段

```text
input_copy=... inputs_set=... rknn_run=... outputs_get=... path=io_mem|legacy_outputs_get
```

与手工分段对照：

- **native → `rknn_run BEGIN`** ≈ `pre` + `input_copy`（+ legacy 时 `inputs_set`）
- **`rknn_run END` → `[det_postprocess][summary]`** ≈ `outputs_get` + `parse` + `concat` + `post_det` 至 summary 前
- **summary → native END** ≈ ROI 还原 + `stain_logic` + JSON（不在 `infer_stain` 内）

你测到的 **236ms** 典型分解：`outputs_get`（INT8→float 三路）+ `decode`（33600 anchor DFL）为主；`thresh`/`nms` 通常较小。

## `[det_postprocess][timing]` 字段

`pre_summary` 行（紧挨 `[det_postprocess][summary]` 之前）：

```text
layout=... decode=... score=... thresh=... pre_summary=... n=... cand_in=...
```

完整路径末尾一行：

```text
layout=... decode=... score=... thresh=... nms=... pack=... total=... n=... cand_in=... keep=...
```

| 字段 | 含义 |
|------|------|
| `layout` | `MapLayoutToNxC`（输出解析/重排） |
| `decode` | raw DFL → xywh（33600 anchor 时通常最大） |
| `score` | sigmoid/ logits → 类分数 + argmax |
| `thresh` | `conf` 阈值过滤、收集候选 |
| `nms` | xyxy + class-aware NMS |
| `pack` | 组装 `DetBox` 输出 |
| `total` | 后处理函数总耗时 |

## adb 过滤

```bash
adb logcat -s LensGuardModel DetPostprocess RKNNRunner | grep -E 'timing|summary|rknn_run'
```
