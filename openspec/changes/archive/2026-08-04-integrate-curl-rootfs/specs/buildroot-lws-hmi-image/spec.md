## ADDED Requirements

### Requirement: curl CLI on product rootfs

The lws_hmi rootfs SHALL include the Buildroot `libcurl` package with the curl CLI option enabled (`BR2_PACKAGE_LIBCURL` and `BR2_PACKAGE_LIBCURL_CURL`) so `/usr/bin/curl` (or an equivalent PATH location such as `/bin/curl`) is present and executable. The binary SHALL use the system CA certificate bundle already required for HTTPS (`BR2_PACKAGE_CA_CERTIFICATES`) for TLS verification. Enabling the gst-plugins-bad curl plugin is not required by this requirement.

#### Scenario: curl present after rootfs build

- **WHEN** rootfs is built with the lws_hmi network fragment after this change
- **THEN** an executable `curl` binary exists on the target filesystem under a standard PATH location

#### Scenario: HTTPS probe can use system trust

- **WHEN** an operator runs `curl` against a public HTTPS URL on a networked device with a valid CA bundle
- **THEN** TLS verification uses the system CA store (not an empty/missing trust path that forces `--insecure` for normal probes)
