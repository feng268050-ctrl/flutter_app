## Why

Operators and scripts on the appliance need a standard HTTPS client for health checks, proxy verification, and ad-hoc debugging. The rootfs already ships CA certificates and system-wide proxy env, but **does not** include `curl`, so CLI probes must be skipped or run from a host.

## What Changes

- Enable Buildroot **`BR2_PACKAGE_LIBCURL`** + **`BR2_PACKAGE_LIBCURL_CURL`** in the product network fragment so `/usr/bin/curl` (and `libcurl`) land in the lws_hmi rootfs. (`BR2_PACKAGE_CURL` is a legacy symbol that stops the defconfig merge.)
- Rely on existing OpenSSL + `BR2_PACKAGE_CA_CERTIFICATES` for HTTPS trust (no alternate TLS backend).
- Optionally gate presence via `scripts/verify-rootfs-overlay.sh` so incremental builds cannot silently drop the binary.
- **Out of scope:** wget; gst-plugins-bad curl plugin; Flutter/Dart HttpClient changes; custom curl recipes or version pins beyond stock Buildroot; shipping curl-only debug images.

## Capabilities

### New Capabilities

- *(none)*

### Modified Capabilities

- `buildroot-lws-hmi-image`: Product rootfs SHALL ship the `curl` CLI built with system CA / OpenSSL trust.
- `hal-network-proxy`: Drop the “image is not required to ship curl” carve-out; acceptance MAY use on-device `curl` once the binary is present.

## Impact

- Overlay: `overlay/buildroot/chips/lws_hmi_network.config` (`BR2_PACKAGE_LIBCURL=y` + `BR2_PACKAGE_LIBCURL_CURL=y`); optional `scripts/verify-rootfs-overlay.sh` check.
- Build: `make apply-overlay`, then ensure `libcurl` is built (`bash scripts/br-make-packages.sh curl libcurl` if stamps are stale), `make check-prebuilt`, `make build-rootfs`, `make upgrade`.
- Runtime: `/usr/bin/curl` available over SSH; respects proxy env from HAL network proxy apply.
- Cross-change: links against overlay-pinned OpenSSL (`openssl-cve-upgrade`); no App rebuild.
