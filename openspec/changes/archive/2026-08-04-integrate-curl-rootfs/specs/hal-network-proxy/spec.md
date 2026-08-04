## MODIFIED Requirements

### Requirement: CLI tools honor proxy after apply

After a successful proxy apply (mid-session or boot restore), command-line tools that honor the standard proxy environment variables SHALL use the configured proxy without requiring the Flutter App to wrap each request. The appliance image SHALL ship `curl` (see `buildroot-lws-hmi-image`) so on-device proxy smoke can invoke it; `wget` remains optional. Apply SHALL update at least: a sourced profile snippet under `/etc/profile.d/`, an environment file suitable for systemd `EnvironmentFile=` (e.g. `/var/lib/network/proxy.env`), and whatever additional path the design documents for `/etc/environment` and/or systemd `DefaultEnvironment`. Acceptance SHALL verify the env surface (new login shell, explicitly sourced env file, or `cat` of the generated env/profile artifacts). Acceptance MAY additionally run `curl` under that environment to confirm proxy routing.

#### Scenario: Env visible to shells and CLI

- **WHEN** proxy is enabled and apply has completed
- **THEN** a new shell (or environment loaded from the generated proxy env file) SHALL expose the expected `http_proxy` / `https_proxy` / `all_proxy` / `no_proxy` (and uppercase) values so any CLI that honors those variables will use the proxy

#### Scenario: Demo probe is not Dart-only

- **WHEN** the Demo verifies outbound access through the proxy
- **THEN** the preferred proof path SHALL be a process that inherits the applied environment (CLI under that env when available), not solely a Dart HttpClient that bypasses system env

#### Scenario: On-device curl available for proxy smoke

- **WHEN** proxy apply has completed and an operator wants a CLI smoke check
- **THEN** `/usr/bin/curl` (or equivalent PATH `curl`) is present so the check can run on the appliance without requiring a host-side client
