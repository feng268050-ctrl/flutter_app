## 1. Stop staging RKNN into AI prebuilt

- [x] 1.1 Remove `copy_so "$RKNN_SO"` from `scripts/build-ai.sh`; keep link-time RKNN paths
- [x] 1.2 Delete existing `prebuilt/ai/linux-arm64/lib/librknnrt.so` and overlay `/opt/hmi/lib/librknnrt.so` if present

## 2. Purge leftovers on device image paths

- [x] 2.1 Post-build: `rm -f` `/opt/hmi/lib/librknnrt.so*`
- [x] 2.2 `push-app-apply-and-restart.sh`: after companion lib copy, remove `/opt/hmi/lib/librknnrt.so*`
- [x] 2.3 `verify-rootfs-overlay.sh`: FAIL if App-bundled `librknnrt.so` present; keep `/usr/lib` required

## 3. Docs touch (minimal)

- [x] 3.1 Adjust `native/lws_ai/README.md` line that implies RKNN ships under `/opt/hmi/lib`
