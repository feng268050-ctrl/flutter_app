## ADDED Requirements

### Requirement: APP selects cloud publish R2 artifact prefix

In addition to selecting the Flutter project for `build-app` / `push-app` / `build-rootfs`, Make/env **`APP`** SHALL select the cloud OTA publish identity for **`make publish`** / **`make publish-only`**: the R2 static-upload artifact prefix SHALL be the `APP` directory name with underscores replaced by hyphens (default `lws_hmi` → `lws-hmi`). Invalid or missing `app/<APP>/` MUST fail before upload. Non-HMI apps MUST NOT be published via the whole-device OTA publish targets unless an explicitly documented escape hatch is used.

#### Scenario: Default APP publishes under lws-hmi

- **WHEN** the operator runs `make publish` without setting `APP`
- **THEN** the publish client targets artifact prefix `lws-hmi`

#### Scenario: Explicit HMI APP changes publish prefix

- **WHEN** the operator runs `APP=cnc_hmi make publish` and `app/cnc_hmi/pubspec.yaml` exists
- **THEN** the publish client targets artifact prefix `cnc-hmi` and uses **that HMI app’s** `pubspec.yaml` version as the cloud OTA version (not `lws_hmi`’s)
