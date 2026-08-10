## 1. OpenCV static prebuilt

- [ ] 1.1 Change `scripts/build-opencv.sh` to `-DBUILD_SHARED_LIBS=OFF`
- [ ] 1.2 Update OpenCV prebuilt stamp label so old shared installs are not treated as ready (e.g. include `static` in stamp id)
- [ ] 1.3 Document in script comment / `native/lws_ai/README.md` that `prebuilt/opencv` is static-only for `lws_ai`

## 2. build-ai static link + staging

- [ ] 2.1 Remove OpenCV `libopencv_*.so*` copy loop from `scripts/build-ai.sh` (keep RKNN exclusion; keep optional yaml-cpp stage only if needed)
- [ ] 2.2 Ensure CMake/`OpenCV_LIBS` link succeeds against static archives; fix PIC/link order if the cross-build fails
- [ ] 2.3 After stage: assert no `libopencv_*.so*` under `prebuilt/ai/linux-arm64/`; omit empty `lib/` if nothing else is staged
- [ ] 2.4 Refresh AI prebuilt stamp after layout change

## 3. Bundle / board cleanup

- [ ] 3.1 Confirm `hmi_bundle_install_ai` installs daemon without requiring OpenCV `.so`
- [ ] 3.2 When installing AI, remove stale `libopencv_*` under destination `/opt/hmi/lib` (narrow cleanup) so push/bundle does not leave orphans
- [ ] 3.3 Update `native/lws_ai/README.md` runtime layout (no OpenCV under `/opt/hmi/lib`; RKNN still `/usr/lib`)

## 4. Verify

- [ ] 4.1 `FORCE=1 make build-opencv` then `FORCE=1 make build-ai`
- [ ] 4.2 Inspect `lws_ai_daemon`: no `DT_NEEDED` `libopencv_*`; still `NEEDED` `librknnrt.so`
- [ ] 4.3 `make build-app` (and `make push-app` on a board when available); confirm staged `/opt/hmi` has daemon and no `libopencv_*.so*`
- [ ] 4.4 Optional smoke: `make smoke-ai` if board + daemon path available
