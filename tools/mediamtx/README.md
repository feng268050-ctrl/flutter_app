# MediaMTX (bundled RTSP relay)

Pinned upstream: see `VERSION` (MIT license, [bluenviron/mediamtx](https://github.com/bluenviron/mediamtx)).

## Build

```bash
make mediamtx
# or
scripts/ci/build-mediamtx.sh
```

Output: `app/src/main/assets/mediamtx/arm64-v8a/mediamtx` and `version.txt`.

**Requirements**

- Go 1.22+, git
- Network on first build: `go mod download` and `go generate ./...` (downloads `hls.min.js`, `VERSION`, optional rpicamera blobs — same as upstream `scripts/binaries.mk`)

**Target:** `GOOS=android` `GOARCH=arm64` (`CGO_ENABLED=0`, linker `-checklinkname=0` for Go 1.23+).  
Do **not** use `GOOS=linux` — that ELF cannot execute on Android (`Permission denied` / exit 126).

CI should cache `tools/mediamtx/_src/mediamtx` and `tools/mediamtx/_src/go-mod-cache`.

## OTA zip layout (optional)

Place a binary in the OTA zip with a semver in the filename, for example:

- `mediamtx_v1.11.4-arm64` (no extension), or
- `mediamtx_v1.11.4.zip` containing `mediamtx` + `version.txt`

`UpgradeActivity` stages newer payloads via `MediaMtxOtaInstaller` when the relay is not running.
