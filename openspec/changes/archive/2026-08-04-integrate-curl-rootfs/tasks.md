## 1. Buildroot enablement

- [x] 1.1 Set `BR2_PACKAGE_LIBCURL=y` + `BR2_PACKAGE_LIBCURL_CURL=y` in `overlay/buildroot/chips/lws_hmi_network.config` with a short comment (CLI HTTPS / proxy smoke; uses system CA; not legacy `BR2_PACKAGE_CURL`)
- [x] 1.2 Add `verify-rootfs-overlay.sh` check that `curl` is executable under `usr/bin` or `bin` in Buildroot `target/`

## 2. Build and verify

- [x] 2.1 `make apply-overlay`
- [x] 2.2 `bash scripts/br-make-packages.sh curl libcurl` (clear stale stamps / build libcurl+curl binary)
- [x] 2.3 `make check-prebuilt` then `make build-rootfs`; confirm verify passes for curl
- [x] 2.4 `make upgrade` (or board-appropriate deploy); on device: `curl --version` and a simple HTTPS HEAD/GET against a known URL
- [x] 2.5 Optional: with HAL proxy applied, confirm `curl` honors `http_proxy` / `https_proxy` from the applied env
