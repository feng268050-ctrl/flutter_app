## ADDED Requirements

### Requirement: System-wide multi-scheme proxy
`hal/network/proxy` SHALL manage appliance outbound proxy policy for more than HTTP. Supported schemes SHALL include at least `http`, `https`, `ftp`, `socks4`, `socks4a`, `socks5`, and `socks5h`. Settings SHALL map to the conventional environment variables `http_proxy`, `https_proxy`, `ftp_proxy`, `all_proxy`, `no_proxy` and their uppercase counterparts. Persist SHALL use `/var/lib/network/proxy.conf` (or an equivalent documented path under `/var/lib/network/`), not an App-only in-memory setting.

#### Scenario: SOCKS catch-all
- **WHEN** the operator enables a SOCKS5H proxy as the catch-all (`all_proxy`)
- **THEN** apply SHALL export `all_proxy` / `ALL_PROXY` with a `socks5h://` URI and SHALL NOT be limited to an HTTP-only preference file schema

#### Scenario: Clear proxy
- **WHEN** proxy is disabled or cleared
- **THEN** apply SHALL remove or empty the managed env exports so subsequent shells and tools do not retain a stale proxy

### Requirement: CLI tools honor proxy after apply
After a successful proxy apply (mid-session or boot restore), command-line tools that honor the standard proxy environment variables—at least **curl**—SHALL use the configured proxy without requiring the Flutter App to wrap each request. Apply SHALL update at least: a sourced profile snippet under `/etc/profile.d/`, an environment file suitable for systemd `EnvironmentFile=`, and whatever additional path the design documents for `/etc/environment` and/or systemd `DefaultEnvironment`. Acceptance MAY use a new login shell or an explicitly sourced env file.

#### Scenario: curl uses proxy
- **WHEN** proxy is enabled and apply has completed
- **THEN** a new shell (or environment loaded from the generated proxy env file) running `curl` SHALL observe the proxy variables and attempt the transfer via that proxy

#### Scenario: Demo probe is not Dart-only
- **WHEN** the Demo verifies outbound access through the proxy
- **THEN** the preferred proof path SHALL be invoking curl (or equivalent CLI) under the applied environment, not solely a Dart HttpClient that bypasses system env

### Requirement: Restore reapplies proxy
Boot restore SHALL re-run the same proxy apply helper used by HAL so reboot restores curl-visible policy.

#### Scenario: Reboot keeps proxy for curl
- **WHEN** proxy was enabled and the device reboots with restore enabled
- **THEN** after boot, a shell `curl` SHALL still see the proxy environment variables
