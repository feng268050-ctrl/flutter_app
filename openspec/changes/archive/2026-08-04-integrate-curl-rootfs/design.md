## Context

Product rootfs already enables HTTPS trust (`BR2_PACKAGE_CA_CERTIFICATES`) and system-wide proxy env (`hal/network/proxy`), but has no HTTP(S) CLI. Buildroot’s stock `curl` package (`BR2_PACKAGE_CURL`) installs `/usr/bin/curl` and pulls `libcurl` against the image’s OpenSSL. Network options live in `overlay/buildroot/chips/lws_hmi_network.config`, included by `rockchip_rk3566_rk3568_lws_hmi_defconfig`.

Constraints:

- Prefer fragment Kconfig over overlaying a custom `curl` recipe.
- Package option flips need an explicit rebuild (`br-make-packages.sh`) when Buildroot stamps look clean — `build-rootfs` alone may keep the previous (absent) state.
- Do not enlarge the gst curl plugin surface; that is unrelated.

## Goals / Non-Goals

**Goals:**

- Ship `/usr/bin/curl` on the product rootfs for all SKUs using the lws_hmi network fragment.
- HTTPS works with the existing CA bundle (and system OpenSSL).
- Document rebuild / verify steps so operators can confirm on device.

**Non-Goals:**

- wget or other HTTP CLIs.
- Pinning a custom curl version / overlay package tree.
- Enabling `BR2_PACKAGE_GST1_PLUGINS_BAD_PLUGIN_CURL`.
- Changing Dart `HttpClient` or App cloud clients.
- Making curl a hard dependency of HMI boot / services.

## Decisions

### D1: Enable stock Buildroot libcurl + curl binary in the network fragment

- **Choice:** Set `BR2_PACKAGE_LIBCURL=y` and `BR2_PACKAGE_LIBCURL_CURL=y` in `overlay/buildroot/chips/lws_hmi_network.config` next to CA certificates, with a short comment (CLI HTTPS probe / proxy smoke). Do **not** set legacy `BR2_PACKAGE_CURL` (stops defconfig with Makefile.legacy).
- **Why:** Same trust store as Dart; smallest change; OpenSSL backend is available via `BR2_PACKAGE_OPENSSL` (selected by product `libopenssl`).
- **Alternatives:** BusyBox `wget` (weaker feature set / TLS story); static prebuilt curl under `prebuilt/` (unnecessary when BR builds fine); debug-only image (operators need it on product boards too).

### D2: No recipe overlay; default TLS = OpenSSL

- **Choice:** Do not add `overlay/buildroot/package/curl/`; accept Buildroot defaults (OpenSSL backend when `libopenssl` is present).
- **Why:** OpenSSL is already product crypto; openssl-cve-upgrade covers the shared library curl will link.
- **Alternatives:** Force GnuTLS/mbedTLS — conflicts with product OpenSSL pin.

### D3: Verify presence in rootfs gate (light)

- **Choice:** Add a `verify-rootfs-overlay.sh` check that `/usr/bin/curl` (or `/bin/curl`) is executable in Buildroot `target/` after packages land.
- **Why:** Catches forgotten rebuild / stamp reuse; cheap assertion.
- **Alternatives:** Device-only manual check — easy to miss on CI/local rootfs builds.

### D4: Rebuild contract

- **Choice:** After enabling the Kconfig bits: `make apply-overlay`, then `bash scripts/br-make-packages.sh curl libcurl` (dirclean + build `libcurl`, which installs the curl binary when `LIBCURL_CURL` is set), then `make build-rootfs` / `make upgrade`.
- **Why:** Matches AGENTS.md package-incremental reuse guidance. Package target name is `libcurl`, not legacy `curl`.

## Risks / Trade-offs

- **[Risk] Rootfs size / attack surface** → Mitigation: curl is a small CLI; leave unused protocols at Buildroot defaults; no new listeners.
- **[Risk] Stale Buildroot stamps omit curl after fragment flip** → Mitigation: D4 explicit `br-make-packages.sh` + D3 verify.
- **[Risk] HTTPS fails if CA bundle missing** → Already required by network fragment; curl inherits same store.
- **[Trade-off] Proxy acceptance now expects on-device curl** → Aligns `hal-network-proxy` with shipping the binary; env-file checks remain valid without invoking curl.

## Migration Plan

1. Flip `BR2_PACKAGE_LIBCURL=y` + `BR2_PACKAGE_LIBCURL_CURL=y` + optional verify check.
2. `make apply-overlay`
3. `bash scripts/br-make-packages.sh curl libcurl`
4. `make check-prebuilt` (if required by pipeline)
5. `make build-rootfs` then `make upgrade`
6. On device: `curl --version`; `curl -I https://example.com` (or health URL); with proxy applied, confirm requests honor `http_proxy` / `https_proxy`.

Rollback: unset `BR2_PACKAGE_LIBCURL` / `BR2_PACKAGE_LIBCURL_CURL`, rebuild package + rootfs, upgrade.

## Open Questions

- None — stock Buildroot curl is sufficient for the stated use.
