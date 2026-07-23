# Native toolchains (vendored, gitignored binaries)

Downloaded SDKs and runtimes for `make ai` / `make opencv` / lens-inspector CMake. Not committed except version pins and small source vendoring.

| Path | Fetch | Role |
|------|-------|------|
| `ndk-r18b/` | `make ndk-r18b` | Android NDK r18b for libai cross-compile |
| `rknn-rt/` | `make fetch-rknn-rt` (via `make ai`) | RKNN runtime `.so` + headers |
| `opencv/` | `make opencv` | OpenCV Android SDK (`sdk/native/jni`) |
| `opencv-ximgproc-ed/` | `scripts/make/fetch-opencv-ximgproc-edgedrawing.sh` | EdgeDrawing sources (opencv_contrib pin) |
