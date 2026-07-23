# nativeInferImageAndSave Diagnostic API

`NativeBridge.nativeInferImageAndSave(long handle, String imagePath, String outputPath)` runs a single-image diagnostic inference through the native engine and saves an annotated image.

## Return values (pipeline status)

The return value is **not** a stain / CLEAN / HEAVY code. It reports whether the call, read, inference, and write succeeded.

| Return | Meaning |
|--------|---------|
| `0` | Success: input read, inference ran, output image written. Detection labels (CLEAN, HEAVY, etc.) and level are delivered via `NativeListener.onCheckResult` if a listener is set. |
| `-1` | Parameter error: invalid handle, null or empty path, or JNI failure to read strings. |
| `-2` | Input image could not be read or decoded. |
| `-3` | Model inference failed. |
| `-4` | Output image could not be written. |

## Signature

```java
public static native int nativeInferImageAndSave(
    long handle,
    String imagePath,
    String outputPath
);
```

## Smoke test

1. Create a native handle with `nativeCreate(configPath, projectRoot)`.
2. Optionally `nativeSetListener(handle, listener)` so you receive `onCheckResult(level, status, message)` on success.
3. Pass a readable image path and a writable output path:

```java
int result = NativeBridge.nativeInferImageAndSave(
    handle,
    "/sdcard/Download/lens_input.jpg",
    "/sdcard/Download/lens_output.jpg"
);
```

4. Expect `result == 0` and the output image to exist at `outputPath`. If you need the stain level or labels (e.g. `HEAVY`, `CLEAN`), read them from the last `onCheckResult` callback, not from `result`.

## Negative test

Call the API with an invalid handle or a missing input image:

```java
int result = NativeBridge.nativeInferImageAndSave(
    0L,
    "/sdcard/Download/missing.jpg",
    "/sdcard/Download/lens_output.jpg"
);
```

Expect a negative return (`-1` for invalid handle; `-2` if the file is missing and read fails). Native code logs the reason and does not crash.

## App migration (from `0/1` semantics)

Older builds used `1` for success and `0` for failure. **Update to:** treat **`0` as success**; use **`onCheckResult`** for level / status. Replace assertions like `result == 1` with `result == 0`, and set `nativeSetListener` in tests that must assert `HEAVY` / `CLEAN`.
