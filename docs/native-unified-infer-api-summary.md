# Lens Guard 单次推理 API（摘要）

> 原文：[`../NATIVE_UNIFIED_INFER_API.md`](../NATIVE_UNIFIED_INFER_API.md)  
> 更新：2026-05-27

## 一句话

对外提供 **单次污点推理** JNI：推荐用 **`StainInferOutcome` / `StainBox` 强类型返回**，避免 JSON 字符串往返；实时推帧仍走 `nativePushFrame` + `onCheckResult`。

## 推荐 API

| JNI | 输入 | 成功 `source` |
|-----|------|----------------|
| `nativeInferImage` | 文件路径 | `offline_infer` |
| `nativeInferRgb` | direct RGBA `ByteBuffer` | `offline_infer` |
| `nativeInferI420` | direct I420 `ByteBuffer` | `live_infer` |
| `nativePushFrame` | direct I420 | 实时队列（回调） |

## 设计原则

- JNI 层直接填充 Java 字段，**少 marshalling**
- `rgb` / `i420` 必须为 **direct** `ByteBuffer`，禁止 `buffer.get(byte[])`
- 在 **RKNN 守护线程** 调用
- 成功时 `level` / `status` / `boxes` 已由 native 算好，App **禁止重算**

## 返回结构（成功 `code == 0`）

- `StainInferOutcome`：`level`(0/1/2)、`status`(CLEAN/MILD/HEAVY)、`imageWidth/Height`、`boxes[]`（全图 xyxy）
- `boxesTruncated` / `boxesTotal`：超过 `stain_max_det`（默认 100）时截断

## 错误码

| code | 含义 |
|------|------|
| 0 | 成功 |
| -1 | 参数 / buffer 错误 |
| -2 | 读图失败（仅 `nativeInferImage`） |
| -3 | RKNN / 后处理异常 |

## Legacy

`*ToJson` 系列仅用于旧 `libai.so` 过渡；新 App 不要 parse JSON。

## 发布验收

```bash
bash scripts/verify_libai_jni.sh /path/to/libai.so
```

须导出 `nativeInferImage`、`nativeInferRgb`、`nativeInferI420`。

## lws-ui 映射建议

| App | Native |
|-----|--------|
| `inferFromJpg` | `guardedInferImage` → `nativeInferImage` |
| `inferFrame` | `guardedInferRgb` → `nativeInferRgb` |
| `inferFromI420` | `guardedInferI420` → `nativeInferI420` |

## 延伸阅读

- [`LENS_GUARD_APP_INTEGRATION.md`](LENS_GUARD_APP_INTEGRATION.md)
- 根目录与 `docs/` 各有一份完整 API 文档，以引擎仓库 Java 声明为准
